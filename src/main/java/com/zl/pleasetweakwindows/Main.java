package com.zl.pleasetweakwindows;

import javafx.application.Application;
import javafx.concurrent.Task;
import javafx.scene.Scene;
import javafx.scene.control.Alert;
import javafx.scene.control.Button;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.TitledPane;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;

public class Main extends Application {

    private final String scriptDirectory = System.getProperty("user.dir") + File.separator + "scripts" + File.separator;

    @Override
    public void start(Stage stage) {
        VBox root = new VBox(15);
        root.setStyle("-fx-padding: 20;");

        root.getChildren().add(createTitledPane("All Windows Settings Optimized",
                "Apply Windows Settings Tweaks",
                "Revert Windows Settings Tweaks",
                this::applyWindowsSettings,
                this::revertWindowsSettings));

        root.getChildren().add(createTitledPane("Bcdedit Tweaks",
                "Apply Bcdedit Tweaks",
                "Revert Bcdedit Tweaks",
                this::applyBcdeditTweaks,
                this::revertBcdeditTweaks));

        root.getChildren().add(createTitledPane("Gaming Optimizations",
                "Apply Gaming Tweaks",
                "Revert Gaming Tweaks",
                this::applyGamingTweaks,
                this::revertGamingTweaks));

        root.getChildren().add(createTitledPane("Network Optimizations",
                "Apply Network Tweaks",
                "Revert Network Tweaks",
                this::applyNetworkTweaks,
                this::revertNetworkTweaks));

        root.getChildren().add(createTitledPane("Services Tweaks",
                "Apply Services Tweaks",
                "Revert Services Tweaks",
                this::applyServiceTweaks,
                this::revertServiceTweaks));

        root.getChildren().add(createTitledPane("UI and General Responsiveness",
                "Apply UI Tweaks",
                "Revert UI Tweaks",
                this::applyUITweaks,
                this::revertUITweaks));

        ScrollPane scrollPane = new ScrollPane(root);
        scrollPane.setFitToWidth(true);

        Scene scene = new Scene(scrollPane, 640, 480);
        stage.setScene(scene);
        stage.setTitle("PleaseTweakWindows");
        stage.show();
    }

    private TitledPane createTitledPane(String title, String applyText, String revertText, Runnable applyAction, Runnable revertAction) {
        VBox box = new VBox(5);

        Button applyButton = new Button(applyText);
        applyButton.setOnAction(e -> applyAction.run());

        Button revertButton = new Button(revertText);
        revertButton.setOnAction(e -> revertAction.run());

        box.getChildren().addAll(applyButton, revertButton);

        TitledPane titledPane = new TitledPane(title, box);
        titledPane.setCollapsible(false);

        return titledPane;
    }

    private void applyWindowsSettings() {
        runScript("Windows settings optimization", "All windows settings optimized" + File.separator + "Windows-settings-tweaked.bat");
    }

    private void revertWindowsSettings() {
        runScript("Revert Windows settings", "All windows settings optimized" + File.separator + "Revert.bat");
    }

    private void applyBcdeditTweaks() {
        runScript("Bcdedit tweaks", "Bcdedit tweaks" + File.separator + "bcdedit-tweaks.bat");
    }

    private void revertBcdeditTweaks() {
        runScript("Revert Bcdedit tweaks", "Bcdedit tweaks" + File.separator + "Revert bcedits to default.bat");
    }

    private void applyGamingTweaks() {
        runScript("Gaming tweaks", "Gaming optimizations" + File.separator + "gaming-tweaks.bat");
    }

    private void revertGamingTweaks() {
        runScript("Revert Gaming tweaks", "Gaming optimizations" + File.separator + "revert gaming tweaks.bat");
    }

    private void applyNetworkTweaks() {
        runScript("Network tweaks", "Network optimizations" + File.separator + "network tweaks.bat");
    }

    private void revertNetworkTweaks() {
        runScript("Revert Network tweaks", "Network optimizations" + File.separator + "revert for network tweaks.bat");
    }

    private void applyServiceTweaks() {
        runScript("Service tweaks", "Services disable and revert" + File.separator + "Services-disabled.bat");
    }

    private void revertServiceTweaks() {
        runScript("Revert Service tweaks", "Services disable and revert" + File.separator + "Revert services to default.bat");
    }

    private void applyUITweaks() {
        runScript("UI tweaks", "UI and general responsiveness" + File.separator + "ui-tweaks.bat");
    }

    private void revertUITweaks() {
        runScript("Revert UI tweaks", "UI and general responsiveness" + File.separator + "Revert UI tweaks.bat");
    }

    private void runScript(String tweakName, String scriptFileName) {
        String scriptPath = scriptDirectory + scriptFileName;

        if (!new File(scriptPath).exists()) {
            showAlert(Alert.AlertType.ERROR, tweakName + " script not found: " + scriptPath);
            return;
        }

        Task<Void> task = new Task<>() {
            @Override
            protected Void call() throws Exception {
                executeScript(scriptPath, tweakName);
                return null;
            }
        };
        new Thread(task).start();
    }

    private void executeScript(String scriptPath, String tweakName) {
        try {
            ProcessBuilder builder = new ProcessBuilder("cmd.exe", "/c", scriptPath);
            Process process = builder.start();

            try (BufferedReader output = new BufferedReader(new InputStreamReader(process.getInputStream()));
                 BufferedReader error = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {

                output.lines().forEach(System.out::println);
                error.lines().forEach(System.err::println);
            }

            int exitCode = process.waitFor();
            if (exitCode == 0) {
                showAlert(Alert.AlertType.INFORMATION, tweakName + " script applied successfully.");
            } else {
                showAlert(Alert.AlertType.ERROR, tweakName + " script failed with exit code: " + exitCode);
            }
        } catch (Exception e) {
            showAlert(Alert.AlertType.ERROR, tweakName + " script error: " + e.getMessage());
        }
    }

    private void showAlert(Alert.AlertType alertType, String message) {
        Alert alert = new Alert(alertType);
        alert.setHeaderText(null);
        alert.setContentText(message);
        alert.showAndWait();
    }

    public static void main(String[] args) {
        launch();
    }
}