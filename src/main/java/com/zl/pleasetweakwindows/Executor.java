package com.zl.pleasetweakwindows;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.IntConsumer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javafx.application.Platform;
import javafx.scene.control.TextArea;

public class Executor {
    private static final int MAX_THREADS = 4;
    private final ExecutorService executorService = Executors.newFixedThreadPool(MAX_THREADS);
    private static final Logger LOGGER = LoggerFactory.getLogger(Executor.class);
    private static final Logger TELEMETRY_LOGGER = LoggerFactory.getLogger("telemetry");
    // Replaceable factory for testing (allows mocking process creation)
    private volatile ProcessRunnerFactory processRunnerFactory = DefaultProcessRunner::new;

    // Track running processes so they can be cancelled
    private final ConcurrentHashMap<String, Process> activeProcesses = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Future<?>> activeFutures = new ConcurrentHashMap<>();
    private final AtomicBoolean cancellationRequested = new AtomicBoolean(false);
    private final AtomicLong keyCounter = new AtomicLong();
    // Separate scheduler for cancellation reset to avoid RejectedExecutionException and starvation
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "ptw-cancel-reset");
        t.setDaemon(true);
        return t;
    });
    private volatile Path scriptsBaseDir;

    public void setScriptsBaseDir(Path baseDir) {
        this.scriptsBaseDir = baseDir;
    }

    public void cancelAllOperations() {
        LOGGER.info("Cancellation requested for all operations");
        cancellationRequested.set(true);

        for (Map.Entry<String, Process> entry : activeProcesses.entrySet()) {
            Process p = entry.getValue();
            if (p.isAlive()) {
                LOGGER.info("Terminating process: {}", entry.getKey());
                p.destroyForcibly();
            }
        }

        for (Map.Entry<String, Future<?>> entry : activeFutures.entrySet()) {
            Future<?> f = entry.getValue();
            if (!f.isDone()) {
                f.cancel(true);
            }
        }

        activeProcesses.clear();
        activeFutures.clear();

        scheduler.schedule(() -> cancellationRequested.set(false), 500, TimeUnit.MILLISECONDS);
    }

    public boolean isCancellationRequested() {
        return cancellationRequested.get();
    }

    public boolean hasActiveOperations() {
        return !activeProcesses.isEmpty() || activeFutures.values().stream().anyMatch(f -> !f.isDone());
    }

    // Resolve %SystemRoot% safely, reject suspicious paths
    private static String getWindowsDirectory() {
        String systemRoot = System.getenv("SystemRoot");
        if (systemRoot == null || systemRoot.trim().isEmpty()) {
            return "C:\\Windows";
        }

        if (!systemRoot.matches("^[A-Za-z0-9\\\\:]+$")) {
            return "C:\\Windows";
        }
        try {
            String normalized = Paths.get(systemRoot).normalize().toString();

            if (normalized.length() >= 3 &&
                Character.isLetter(normalized.charAt(0)) &&
                normalized.charAt(1) == ':' &&
                normalized.charAt(2) == '\\') {
                return normalized;
            }
        } catch (Exception e) {
            LOGGER.debug("Failed to normalize SystemRoot path: {}", e.getMessage());
        }

        return "C:\\Windows";
    }

    private static final String WINDOWS_DIR = getWindowsDirectory();
    private static final String POWERSHELL_PATH = WINDOWS_DIR + "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";

    // Dispatch callback to the FX Application Thread; falls back to direct call in tests
    private static void runOnFxThread(Runnable callback) {
        if (callback == null) return;
        try {
            Platform.runLater(callback);
        } catch (IllegalStateException e) {
            // JavaFX toolkit not initialized (e.g., in unit tests)
            callback.run();
        }
    }

    private void rejectWithError(String message, String scriptPath, String action,
                                              TextArea logArea, IntConsumer onComplete) {
        logMessage(logArea, "Error: " + message);
        LOGGER.warn("{}: {}", message, scriptPath);
        logActionTelemetry(scriptPath, action, -1, 0);
        if (onComplete != null) {
            runOnFxThread(() -> onComplete.accept(-1));
        }
    }

    public void runScript(String scriptPath, TextArea logArea, IntConsumer onComplete, String action) {
        if (!isValidScriptPath(scriptPath)) {
            rejectWithError("Invalid script path: " + scriptPath, scriptPath, action, logArea, onComplete);
            return;
        }
        if (!new File(scriptPath).exists()) {
            rejectWithError("Script not found: " + scriptPath, scriptPath, action, logArea, onComplete);
            return;
        }
        if (action != null && !isValidAction(action)) {
            rejectWithError("Invalid action parameter: " + action, scriptPath, action, logArea, onComplete);
            return;
        }
        // Compute file hash before submitting to executor (TOCTOU protection)
        String expectedHash = computeFileHash(scriptPath);

        logMessage(logArea, "════════════════════════════════════════════════");
        logMessage(logArea, "  Starting: " + new File(scriptPath).getName());
        logMessage(logArea, "════════════════════════════════════════════════");
        LOGGER.info("Running script: {} (action={})", scriptPath, action);

        // Put tracking future in map BEFORE submitting to avoid race condition
        String futureKey = scriptPath + "_" + keyCounter.incrementAndGet();
        CompletableFuture<Void> trackingFuture = new CompletableFuture<>();
        activeFutures.put(futureKey, trackingFuture);

        executorService.submit(() -> {
            int exitCode = -1;
            try {
                exitCode = executeScript(scriptPath, logArea, action, expectedHash);
            } finally {
                trackingFuture.complete(null);
                activeFutures.remove(futureKey);
                if (onComplete != null) {
                    int finalCode = exitCode;
                    runOnFxThread(() -> onComplete.accept(finalCode));
                }
            }
        });
    }

    boolean isValidAction(String action) {
        if (action == null || action.isEmpty()) {
            return false;
        }
        return action.matches("^[A-Za-z0-9_-]{2,64}$");
    }

    boolean isValidScriptPath(String scriptPath) {
        if (scriptPath == null || scriptPath.trim().isEmpty()) {
            return false;
        }

        // Check for traversal on original path BEFORE normalization
        if (scriptPath.contains("..")) {
            return false;
        }

        try {
            Path path = Paths.get(scriptPath).normalize();
            String normalizedPath = path.toString();
            if (!normalizedPath.toLowerCase().endsWith(".ps1")) {
                return false;
            }
            // Block shell metacharacters
            boolean hasSuspiciousChars =
                normalizedPath.contains(";") ||
                normalizedPath.contains("|") ||
                normalizedPath.contains("&") ||
                normalizedPath.contains(">") ||
                normalizedPath.contains("<");
            if (hasSuspiciousChars) {
                return false;
            }

            // Verify script is within the trusted scripts directory
            if (scriptsBaseDir != null) {
                Path absolute = path.toAbsolutePath().normalize();
                Path baseAbsolute = scriptsBaseDir.toAbsolutePath().normalize();
                if (!absolute.startsWith(baseAbsolute)) {
                    LOGGER.warn("Script path {} is outside base directory {}", scriptPath, scriptsBaseDir);
                    return false;
                }
            }

            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private int executeScript(String scriptPath, TextArea logArea, String action, String expectedHash) {
        long startNanos = System.nanoTime();
        int exitCode = -1;
        try {
            // Verify script integrity before execution (TOCTOU protection)
            if (expectedHash != null) {
                String currentHash = computeFileHash(scriptPath);
                if (!expectedHash.equals(currentHash)) {
                    logMessage(logArea, "ERROR: Script integrity check failed - file was modified between validation and execution");
                    LOGGER.error("TOCTOU: Script hash mismatch for {}. Expected={}, Got={}", scriptPath, expectedHash, currentHash);
                    return -1;
                }
            }

            String scriptName = new File(scriptPath).getName().toLowerCase();
            // These scripts accept -Action parameter for sub-tweak dispatch
            boolean isConsolidatedScript = scriptName.equals("gaming-optimizations.ps1") ||
                                          scriptName.equals("network-optimizations.ps1") ||
                                          scriptName.equals("general-tweaks.ps1") ||
                                          scriptName.equals("services-management.ps1") ||
                                          scriptName.equals("revert-privacy.ps1") ||
                                          scriptName.equals("privacy.ps1") ||
                                          scriptName.equals("security.ps1") ||
                                          scriptName.equals("revert-security.ps1");

            List<String> command = new ArrayList<>();
            command.add(POWERSHELL_PATH);
            command.add("-NoProfile");
            command.add("-ExecutionPolicy");
            command.add("Bypass");
            command.add("-WindowStyle");
            command.add("Hidden");
            command.add("-File");
            command.add(scriptPath);
            if (isConsolidatedScript && action != null) {
                command.add("-Action");
                command.add(action);
                logMessage(logArea, "[>] Action: " + action);
            }
            ProcessRunner runner = processRunnerFactory.create(command);

            runner.redirectErrorStream(true);
            // Tell scripts they're running from the GUI (disables interactive prompts)
            runner.environment().put("PTW_EMBEDDED", "1");
            // Pass log directory for detailed PowerShell file-only logging
            String logDir = System.getProperty("ptw.log.dir");
            if (logDir == null) {
                logDir = Paths.get(System.getProperty("user.dir"), "logs").toString();
            }
            runner.environment().put("PTW_LOG_DIR", logDir);
            String processKey = scriptPath + "_" + keyCounter.incrementAndGet();
            try {
                Process process = runner.start();
                activeProcesses.put(processKey, process);

                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        if (cancellationRequested.get()) {
                            logMessage(logArea, "[!] Operation cancelled by user");
                            process.destroyForcibly();
                            break;
                        }
                        logMessage(logArea, line);
                    }
                }

                // Use timeout on waitFor to prevent indefinite hang after destroyForcibly
                boolean terminated = process.waitFor(30, TimeUnit.SECONDS);
                if (!terminated) {
                    LOGGER.warn("Process did not terminate within timeout, forcing: {}", scriptPath);
                    process.destroyForcibly();
                    process.waitFor(5, TimeUnit.SECONDS);
                }
                exitCode = process.isAlive() ? -1 : process.exitValue();
            } catch (IOException e) {
                exitCode = -1;
                logMessage(logArea, "ERROR: Failed to start script process: " + e.getMessage());
                logMessage(logArea, "This may be due to insufficient permissions or PowerShell not being available.");
                LOGGER.error("Failed to start script process: {}", scriptPath, e);
            } finally {
                activeProcesses.remove(processKey);
            }
            logMessage(logArea, "════════════════════════════════════════════════");
            if (exitCode == 0) {
                logMessage(logArea, "  [+] SUCCESS - Operation completed");
                LOGGER.info("Script finished successfully: {}", scriptPath);
            } else {
                logMessage(logArea, "  [!] Finished with warnings (code: " + exitCode + ")");
                LOGGER.warn("Script finished with exit code {}: {}", exitCode, scriptPath);
            }
            logMessage(logArea, "════════════════════════════════════════════════");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logMessage(logArea, "════════════════════════════════════════════════");
            logMessage(logArea, "  [!] Script execution was interrupted");
            logMessage(logArea, "════════════════════════════════════════════════");
            LOGGER.warn("Script execution interrupted: {}", scriptPath, e);
        } finally {
            long durationMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);
            logActionTelemetry(scriptPath, action, exitCode, durationMs);
        }
        return exitCode;
    }

    private static void logMessage(TextArea logArea, String message) {
        if (logArea != null) {
            Platform.runLater(() -> logArea.appendText(message + "\n"));
        }
    }

    private static void logActionTelemetry(String scriptPath, String action, int exitCode, long durationMs) {
        String actionLabel = (action == null || action.isBlank()) ? "Menu" : action;
        String scriptName = scriptPath == null ? "unknown" : new File(scriptPath).getName();
        String msg = String.format("ActionTelemetry script=%s action=%s exit=%d duration=%dms", scriptName, actionLabel, exitCode, durationMs);
        if (exitCode == 0) {
            TELEMETRY_LOGGER.info(msg);
        } else {
            TELEMETRY_LOGGER.warn(msg);
        }
    }

    public void setProcessRunnerFactory(ProcessRunnerFactory factory) {
        processRunnerFactory = factory;
    }

    public void resetProcessRunnerFactory() {
        processRunnerFactory = DefaultProcessRunner::new;
    }

    private static class DefaultProcessRunner implements ProcessRunner {
        private final ProcessBuilder builder;

        DefaultProcessRunner(List<String> command) {
            this.builder = new ProcessBuilder(command);
        }

        @Override
        public Process start() throws IOException {
            return builder.start();
        }

        @Override
        public ProcessRunner redirectErrorStream(boolean redirectErrorStream) {
            builder.redirectErrorStream(redirectErrorStream);
            return this;
        }

        @Override
        public Map<String, String> environment() {
            return builder.environment();
        }
    }

    /**
     * Check if PowerShell 5.1 is available at the expected path.
     */
    public static boolean isPowerShellAvailable() {
        return new File(POWERSHELL_PATH).exists();
    }

    /**
     * Compute SHA-256 hash of a file for integrity verification.
     */
    static String computeFileHash(String filePath) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] fileBytes = Files.readAllBytes(Path.of(filePath));
            byte[] hashBytes = digest.digest(fileBytes);
            StringBuilder sb = new StringBuilder(hashBytes.length * 2);
            for (byte b : hashBytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException | IOException e) {
            LOGGER.warn("Could not compute file hash for {}: {}", filePath, e.getMessage());
            return null;
        }
    }

    // Shutdown kills active OS processes before stopping the thread pool
    public void shutdown() {
        for (Process p : activeProcesses.values()) {
            if (p.isAlive()) {
                p.destroyForcibly();
            }
        }
        activeProcesses.clear();

        executorService.shutdown();
        try {
            if (!executorService.awaitTermination(5, TimeUnit.SECONDS)) {
                executorService.shutdownNow();
            }
        } catch (InterruptedException e) {
            executorService.shutdownNow();
            Thread.currentThread().interrupt();
        }
        scheduler.shutdownNow();
    }
}
