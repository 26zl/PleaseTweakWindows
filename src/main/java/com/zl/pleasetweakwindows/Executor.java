package com.zl.pleasetweakwindows;

import javafx.scene.control.TextArea;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;

public class Executor {

    public static void runScript(String scriptPath, TextArea logArea) {
        if (!new File(scriptPath).exists()) {
            logMessage(logArea, "Error: Script not found: " + scriptPath);
            return;
        }

        logMessage(logArea, "Running script: " + scriptPath);

        new Thread(() -> executeScript(scriptPath, logArea)).start();
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
        }
    }

    public static void RestorePoint(String description, TextArea logArea) {
        String command = "powershell.exe -Command \"Checkpoint-Computer -Description '" + description + "' -RestorePointType 'MODIFY_SETTINGS'\"";
        try {
            logMessage(logArea, "Creating restore point " + description);

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
        }
    }

    private static void logMessage(TextArea logArea, String message) {
        if (logArea != null) {
            logArea.appendText(message + "\n");
        }
    }
}