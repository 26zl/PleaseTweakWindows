package com.zl.pleasetweakwindows;

import javafx.application.Application;
import javafx.scene.Scene;
import javafx.scene.control.Alert;
import javafx.scene.control.Button;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.TitledPane;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

public class Main extends Application {

    private final String scriptDirectory = System.getProperty("user.dir") + File.separator + "scripts" + File.separator;

    private final List<Tweak> tweaks = new ArrayList<>();

    @Override
    public void start(Stage stage) {
        initTweaks();

        VBox root = new VBox(20);
        root.setStyle("-fx-padding: 30;");

        for (Tweak tweak : tweaks) {
            root.getChildren().add(createTitledPane(tweak));
        }

        ScrollPane scrollPane = new ScrollPane(root);
        scrollPane.setFitToWidth(true);

        Scene scene = new Scene(scrollPane, 800, 600);
        stage.setScene(scene);
        stage.setTitle("PleaseTweakWindows");
        stage.show();
    }

    private void initTweaks() {
        tweaks.add(new Tweak("All Windows Settings Optimized",
                "All windows settings optimized" + File.separator + "Windows-settings-tweaked.bat",
                "All windows settings optimized" + File.separator + "Revert.bat"));
        tweaks.add(new Tweak("Bcdedit Tweaks",
                "Bcdedit tweaks" + File.separator + "bcdedit-tweaks.bat",
                "Bcdedit tweaks" + File.separator + "Revert bcedits to default.bat"));
        tweaks.add(new Tweak("Gaming Optimizations",
                "Gaming optimizations" + File.separator + "gaming-tweaks.bat",
                "Gaming optimizations" + File.separator + "revert gaming tweaks.bat"));
        tweaks.add(new Tweak("Network Optimizations",
                "Network optimizations" + File.separator + "network tweaks.bat",
                "Network optimizations" + File.separator + "revert for network tweaks.bat"));
        tweaks.add(new Tweak("Services Tweaks",
                "Services disable and revert" + File.separator + "Services-disabled.bat",
                "Services disable and revert" + File.separator + "Revert services to default.bat"));
        tweaks.add(new Tweak("UI and General Responsiveness",
                "UI and general responsiveness" + File.separator + "ui-tweaks.bat",
                "UI and general responsiveness" + File.separator + "Revert UI tweaks.bat"));
        tweaks.add(new Tweak("Test Tweak",
                "test.ps1",
                "revertTest.ps1"));
    }

    private TitledPane createTitledPane(Tweak tweak) {
        VBox box = new VBox(10);

        Button applyButton = new Button("Apply " + tweak.getTitle());
        applyButton.setOnAction(e -> runScript(tweak.getTitle(), tweak.getApplyScript()));

        Button revertButton = new Button("Revert " + tweak.getTitle());
        revertButton.setOnAction(e -> runScript(tweak.getTitle(), tweak.getRevertScript()));

        box.getChildren().addAll(applyButton, revertButton);

        TitledPane titledPane = new TitledPane(tweak.getTitle(), box);
        titledPane.setCollapsible(false);

        return titledPane;
    }

    private void runScript(String tweakName, String scriptFileName) {
        String scriptPath = scriptDirectory + scriptFileName;

        if (!new File(scriptPath).exists()) {
            showAlert(Alert.AlertType.ERROR, tweakName + " script not found: " + scriptPath);
            return;
        }

        new Thread(() -> executeScript(scriptPath, tweakName)).start();
    }

    private void executeScript(String scriptPath, String tweakName) {
        try {
            ProcessBuilder builder;
            if (scriptPath.endsWith(".ps1")) {
                builder = new ProcessBuilder("cmd.exe", "/c", "start", "powershell.exe", "-NoExit", "-ExecutionPolicy", "Bypass", "-File", scriptPath, "-Verbose");
            } else {
                builder = new ProcessBuilder("cmd.exe", "/c", "start", "cmd.exe", "/k", scriptPath);
            }

            builder.start();
            showAlert(Alert.AlertType.INFORMATION, tweakName + " script is running in a new window.");

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