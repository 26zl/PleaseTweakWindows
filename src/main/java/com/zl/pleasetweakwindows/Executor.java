package com.zl.pleasetweakwindows;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import javafx.application.Platform;
import javafx.scene.control.TextArea;

public class Executor {
    private static final ExecutorService executorService = Executors.newCachedThreadPool();
    private static final String POWERSHELL_PATH = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";

    public static void runScript(String scriptPath, TextArea logArea) {
        File scriptFile = new File(scriptPath);
        if (!scriptFile.exists()) {
            logMessage(logArea, "Error: Script not found: " + scriptPath);
            return;
        }
        logMessage(logArea, "Running script: " + scriptPath);
        executorService.submit(() -> executeScript(scriptPath, logArea));
    }

    private static void executeScript(String scriptPath, TextArea logArea) {
        try {
            ProcessBuilder builder;
            if (scriptPath.endsWith(".ps1")) {
                builder = new ProcessBuilder(POWERSHELL_PATH, "-ExecutionPolicy", "Bypass", "-File", scriptPath);
            } else {
                builder = new ProcessBuilder("C:\\Windows\\System32\\cmd.exe", "/c", scriptPath);
            }

            builder.redirectErrorStream(true);
            Process process = builder.start();

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    logMessage(logArea, line);
                }
            }

            process.waitFor();
            logMessage(logArea, "Script finished: " + scriptPath);
        } catch (IOException | InterruptedException e) {
            logMessage(logArea, "Error: " + e.getMessage());
            logMessage(logArea, "Stack trace: " + e.toString());
        }
    }

    public static void createRestorePoint(TextArea logArea) {
        executorService.submit(() -> {
            try {
                logMessage(logArea, "Creating restore point...");

                File powershellExe = new File(POWERSHELL_PATH);
                if (!powershellExe.exists()) {
                    logMessage(logArea, "Error: PowerShell not found at " + POWERSHELL_PATH);
                    return;
                }

                String scriptPath = System.getProperty("user.dir") + File.separator + "scripts" + File.separator + "create_restore_point.ps1";
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
            } catch (IOException | InterruptedException e) {
                logMessage(logArea, "Failed to create restore point: " + e.getMessage());
                logMessage(logArea, "Stack trace: " + e.toString());
            } catch (RuntimeException e) {
                logMessage(logArea, "A runtime error occurred: " + e.getMessage());
                logMessage(logArea, "Stack trace: " + e.toString());
            }
        });
    }

    private static void logMessage(TextArea logArea, String message) {
        if (logArea != null) {
            Platform.runLater(() -> logArea.appendText(message + "\n"));
        }
    }
}