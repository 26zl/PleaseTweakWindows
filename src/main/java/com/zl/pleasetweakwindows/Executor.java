package com.zl.pleasetweakwindows;

import javafx.application.Platform;
import javafx.scene.control.TextArea;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Executor {

    private static final ExecutorService executorService = Executors.newCachedThreadPool();

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
                builder = new ProcessBuilder("powershell.exe", "-NoExit", "-ExecutionPolicy", "Bypass", "-File", scriptPath);
            } else {
                builder = new ProcessBuilder("cmd.exe", "/c", scriptPath);
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
        } catch (Exception e) {
            logMessage(logArea, "Error: " + e.getMessage());
            e.printStackTrace();
        }
    }

    public static void createRestorePoint(String description, TextArea logArea) {
        String command = "powershell.exe -Command \"Checkpoint-Computer -Description '" + description + "' -RestorePointType 'MODIFY_SETTINGS'\"";
        try {
            logMessage(logArea, "Creating restore point: " + description);

            ProcessBuilder builder = new ProcessBuilder("cmd.exe", "/c", command);
            builder.redirectErrorStream(true);
            Process process = builder.start();

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    logMessage(logArea, line);
                }
            }

            process.waitFor();
            logMessage(logArea, "Restore point created successfully!");
        } catch (Exception e) {
            logMessage(logArea, "Failed to create restore point: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static void logMessage(TextArea logArea, String message) {
        if (logArea != null) {
            Platform.runLater(() -> logArea.appendText(message + "\n"));
        }
    }
}