package com.zl.pleasetweakwindows;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import javafx.application.Platform;
import javafx.scene.control.TextArea;

public class Executor {
    private static final int MAX_THREADS = 4;
    private static final ExecutorService executorService = Executors.newFixedThreadPool(MAX_THREADS);
    
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

        }
        
        return "C:\\Windows";
    }
    
    private static final String WINDOWS_DIR = getWindowsDirectory();
    private static final String POWERSHELL_PATH = WINDOWS_DIR + "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
    private static final String CMD_PATH = WINDOWS_DIR + "\\System32\\cmd.exe";

    public static void runScript(String scriptPath, TextArea logArea) {
        runScript(scriptPath, logArea, null);
    }

    public static void runScript(String scriptPath, TextArea logArea, Runnable onComplete) {
        File scriptFile = new File(scriptPath);
        if (!scriptFile.exists()) {
            logMessage(logArea, "Error: Script not found: " + scriptPath);
            if (onComplete != null) {
                onComplete.run();
            }
            return;
        }
        logMessage(logArea, "Running script: " + scriptPath);
        executorService.submit(() -> {
            try {
                executeScript(scriptPath, logArea);
            } finally {
                if (onComplete != null) {
                    onComplete.run();
                }
            }
        });
    }

    private static void executeScript(String scriptPath, TextArea logArea) {
        try {
            ProcessBuilder builder;
            if (scriptPath.endsWith(".ps1")) {
                builder = new ProcessBuilder(POWERSHELL_PATH, "-ExecutionPolicy", "Bypass", "-File", scriptPath);
            } else {
                builder = new ProcessBuilder(CMD_PATH, "/c", scriptPath);
            }

            builder.redirectErrorStream(true);
            Process process = builder.start();

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    logMessage(logArea, line);
                }
            }

            int exitCode = process.waitFor();
            if (exitCode == 0) {
                logMessage(logArea, "Script finished successfully: " + scriptPath);
            } else {
                logMessage(logArea, "Script failed (exit code " + exitCode + "): " + scriptPath);
            }
        } catch (IOException e) {
            logMessage(logArea, "Error: " + e.getMessage());
            logMessage(logArea, "Stack trace: " + e.toString());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logMessage(logArea, "Error: Script execution was interrupted");
            logMessage(logArea, "Stack trace: " + e.toString());
        }
    }

    public static void createRestorePoint(TextArea logArea, String scriptDirectory) {
        createRestorePoint(logArea, scriptDirectory, null);
    }

    public static void createRestorePoint(TextArea logArea, String scriptDirectory, Runnable onComplete) {
        executorService.submit(() -> {
            try {
                logMessage(logArea, "Creating restore point...");

                File powershellExe = new File(POWERSHELL_PATH);
                if (!powershellExe.getCanonicalPath().startsWith(new File(WINDOWS_DIR).getCanonicalPath())) {
                    logMessage(logArea, "Error: PowerShell not found at " + POWERSHELL_PATH);
                    return;
                }

                String scriptPath = scriptDirectory + "create_restore_point.ps1";
                File scriptFile = new File(scriptPath);

                if (!scriptFile.exists()) {
                    logMessage(logArea, "Error: Restore point script not found: " + scriptPath);
                    return;
                }

                ProcessBuilder builder = new ProcessBuilder(
                        POWERSHELL_PATH, "-ExecutionPolicy", "Bypass", "-File", scriptPath
                );

                builder.redirectErrorStream(true);
                Process process = builder.start();

                try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        logMessage(logArea, line);
                    }
                }

                int exitCode = process.waitFor();
                if (exitCode == 0) {
                    logMessage(logArea, "Restore point created successfully!");
                } else {
                    logMessage(logArea, "Failed to create restore point. Exit code: " + exitCode);
                }
            } catch (IOException e) {
                logMessage(logArea, "Failed to create restore point: " + e.getMessage());
                logMessage(logArea, "Stack trace: " + e.toString());
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                logMessage(logArea, "Failed to create restore point: Operation was interrupted");
                logMessage(logArea, "Stack trace: " + e.toString());
            } catch (RuntimeException e) {
                logMessage(logArea, "A runtime error occurred: " + e.getMessage());
                logMessage(logArea, "Stack trace: " + e.toString());
            } finally {
                if (onComplete != null) {
                    onComplete.run();
                }
            }
        });
    }

    private static void logMessage(TextArea logArea, String message) {
        if (logArea != null) {
            Platform.runLater(() -> logArea.appendText(message + "\n"));
        }
    }

    /**
     * Shuts down the executor service. Should be called when the application is closing.
     */
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
