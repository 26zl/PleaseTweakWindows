package com.zl.pleasetweakwindows;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javafx.application.Platform;
import javafx.scene.control.TextArea;

public class Executor {
    private static final int MAX_THREADS = 4;
    private static final ExecutorService executorService = Executors.newFixedThreadPool(MAX_THREADS);
    private static final Logger LOGGER = LoggerFactory.getLogger(Executor.class);
    private static final Logger TELEMETRY_LOGGER = LoggerFactory.getLogger("telemetry");
    // Replaceable factory for testing (allows mocking process creation)
    private static volatile ProcessRunnerFactory processRunnerFactory = DefaultProcessRunner::new;

    // Track running processes so they can be cancelled
    private static final ConcurrentHashMap<String, Process> activeProcesses = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Future<?>> activeFutures = new ConcurrentHashMap<>();
    private static final AtomicBoolean cancellationRequested = new AtomicBoolean(false);
    
    public static boolean cancelAllOperations() {
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
        
        // Reset flag after a short delay so new operations can start
        executorService.submit(() -> {
            try {
                Thread.sleep(500);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            cancellationRequested.set(false);
        });
        
        return true;
    }

    public static boolean isCancellationRequested() {
        return cancellationRequested.get();
    }
    
    public static boolean hasActiveOperations() {
        return !activeProcesses.isEmpty() || activeFutures.values().stream().anyMatch(f -> !f.isDone());
    }
    
    // Resolve %SystemRoot% safely, reject suspicious paths
    private static String getWindowsDirectory() {
        String systemRoot = System.getenv("SystemRoot");
        if (systemRoot == null || systemRoot.trim().isEmpty()) {
            return "C:\\Windows";
        }
        
        if (!systemRoot.matches("^[A-Za-z0-9\\\\: ]+$")) {
            return "C:\\Windows";
        }
        try {
            Path normalizedPath = Paths.get(systemRoot).normalize();
            String normalized = normalizedPath.toString();
            
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
    private static final String CMD_PATH = WINDOWS_DIR + "\\System32\\cmd.exe";

    // Returns true so it can be chained: if (!valid && rejectWithError(...)) return;
    private static boolean rejectWithError(String message, String scriptPath, String action,
                                              TextArea logArea, Runnable onComplete) {
        logMessage(logArea, "Error: " + message);
        LOGGER.warn("{}: {}", message, scriptPath);
        logActionTelemetry(logArea, scriptPath, action, -1, 0);
        if (onComplete != null) {
            onComplete.run();
        }
        return true;
    }

    public static void runScript(String scriptPath, TextArea logArea, Runnable onComplete, String action) {
        if (!isValidScriptPath(scriptPath)
                && rejectWithError("Invalid script path: " + scriptPath, scriptPath, action, logArea, onComplete)) {
            return;
        }
        if (!new File(scriptPath).exists()
                && rejectWithError("Script not found: " + scriptPath, scriptPath, action, logArea, onComplete)) {
            return;
        }
        if (action != null && !isValidAction(action)
                && rejectWithError("Invalid action parameter: " + action, scriptPath, action, logArea, onComplete)) {
            return;
        }
        logMessage(logArea, "════════════════════════════════════════════════");
        logMessage(logArea, "  Starting: " + new File(scriptPath).getName());
        logMessage(logArea, "════════════════════════════════════════════════");
        LOGGER.info("Running script: {} (action={})", scriptPath, action);
        String futureKey = scriptPath + "_" + System.currentTimeMillis();
        Future<?> future = executorService.submit(() -> {
            try {
                executeScript(scriptPath, logArea, action);
            } finally {
                activeFutures.remove(futureKey);
                if (onComplete != null) {
                    onComplete.run();
                }
            }
        });
        activeFutures.put(futureKey, future);
    }
    private static boolean isValidAction(String action) {
        if (action == null || action.isEmpty()) {
            return false;
        }
        return action.matches("^[A-Za-z0-9_-]{2,64}$");
    }
    private static boolean isValidScriptPath(String scriptPath) {
        if (scriptPath == null || scriptPath.trim().isEmpty()) {
            return false;
        }

        try {
            Path path = Paths.get(scriptPath).normalize();
            String normalizedPath = path.toString();
            if (!normalizedPath.toLowerCase().endsWith(".ps1") &&
                !normalizedPath.toLowerCase().endsWith(".bat")) {
                return false;
            }
            // Block path traversal and shell metacharacters
            boolean hasSuspiciousChars = normalizedPath.contains("..") ||
                normalizedPath.contains(";") ||
                normalizedPath.contains("|") ||
                normalizedPath.contains("&") ||
                normalizedPath.contains(">") ||
                normalizedPath.contains("<");
            return !hasSuspiciousChars;
        } catch (Exception e) {
            return false;
        }
    }

    private static void executeScript(String scriptPath, TextArea logArea, String action) {
        long startNanos = System.nanoTime();
        int exitCode = -1;
        try {
            ProcessRunner runner;
            if (scriptPath.endsWith(".ps1")) {
                String scriptName = new File(scriptPath).getName().toLowerCase();
                // These scripts accept -Action parameter for sub-tweak dispatch
                boolean isConsolidatedScript = scriptName.contains("gaming-optimizations") ||
                                              scriptName.contains("network-optimizations") ||
                                              scriptName.contains("general-tweaks") ||
                                              scriptName.contains("services-management") ||
                                              scriptName.equals("revert-privacy.ps1") ||
                                              scriptName.equals("privacy.ps1") ||
                                              scriptName.equals("security.ps1") ||
                                              scriptName.equals("revert-security.ps1");
                boolean isRevertScript = scriptName.startsWith("revert-");

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
                } else if (isRevertScript) {
                    logMessage(logArea, "[>] Restoring defaults...");
                }
                runner = processRunnerFactory.create(command);
            } else {
                runner = processRunnerFactory.create(List.of(CMD_PATH, "/c", scriptPath));
            }

            runner.redirectErrorStream(true);
            // Tell scripts they're running from the GUI (disables interactive prompts)
            runner.environment().put("PTW_EMBEDDED", "1");
            String processKey = scriptPath + "_" + System.currentTimeMillis();
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

                exitCode = process.waitFor();
            } catch (IOException e) {
                exitCode = -1;
                logMessage(logArea, "ERROR: Failed to start script process: " + e.getMessage());
                logMessage(logArea, "This may be due to insufficient permissions or PowerShell not being available.");
                LOGGER.error("Failed to start script process: {}", scriptPath, e);
                throw e;
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
        } catch (IOException e) {
            logMessage(logArea, "════════════════════════════════════════════════");
            logMessage(logArea, "  [-] ERROR: " + e.getMessage());
            logMessage(logArea, "════════════════════════════════════════════════");
            LOGGER.error("Script execution failed: {}", scriptPath, e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logMessage(logArea, "════════════════════════════════════════════════");
            logMessage(logArea, "  [!] Script execution was interrupted");
            logMessage(logArea, "════════════════════════════════════════════════");
            LOGGER.warn("Script execution interrupted: {}", scriptPath, e);
        } finally {
            long durationMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNanos);
            logActionTelemetry(logArea, scriptPath, action, exitCode, durationMs);
        }
    }
    private static void logMessage(TextArea logArea, String message) {
        if (logArea != null) {
            Platform.runLater(() -> logArea.appendText(message + "\n"));
        }
    }

    private static void logActionTelemetry(TextArea logArea, String scriptPath, String action, int exitCode, long durationMs) {
        String actionLabel = (action == null || action.isBlank()) ? "Menu" : action;
        String scriptName = scriptPath == null ? "unknown" : new File(scriptPath).getName();
        String msg = String.format("ActionTelemetry script=%s action=%s exit=%d duration=%dms", scriptName, actionLabel, exitCode, durationMs);
        logMessage(logArea, msg);
        if (exitCode == 0) {
            TELEMETRY_LOGGER.info(msg);
        } else {
            TELEMETRY_LOGGER.warn(msg);
        }
    }
    public static void setProcessRunnerFactory(ProcessRunnerFactory factory) {
        processRunnerFactory = factory;
    }
    public static void resetProcessRunnerFactory() {
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
    public static void shutdown() {
        executorService.shutdown();
        try {
            if (!executorService.awaitTermination(5, TimeUnit.SECONDS)) {
                executorService.shutdownNow();
            }
        } catch (InterruptedException e) {
            executorService.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
}
