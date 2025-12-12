package com.zl.pleasetweakwindows;

import java.io.File;

import javafx.application.Platform;
import javafx.geometry.Pos;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TextArea;
import javafx.scene.layout.HBox;

public class UiLogic {

    public static HBox createTweakItem(Tweak tweak, TextArea logArea, String scriptDirectory) {
        HBox tweakBox = new HBox(10);
        tweakBox.getStyleClass().add("tweak-box");
        tweakBox.setAlignment(Pos.CENTER_LEFT);

        Label tweakTitle = new Label(tweak.getTitle());
        tweakTitle.getStyleClass().add("tweak-title");
        tweakTitle.setMinWidth(250);

        Button applyButton = new Button("Apply");
        applyButton.setMinWidth(100);
        applyButton.setMaxWidth(Double.MAX_VALUE);

        Button revertButton = new Button("Revert");
        revertButton.setMinWidth(100);
        revertButton.setMaxWidth(Double.MAX_VALUE);

        // Validate apply script exists
        String applyScriptPath = scriptDirectory + tweak.getApplyScript();
        File applyScriptFile = new File(applyScriptPath);
        if (!applyScriptFile.exists()) {
            applyButton.setDisable(true);
            applyButton.setStyle("-fx-opacity: 0.5;");
        }

        applyButton.setOnAction(e -> {
            applyButton.setDisable(true);
            revertButton.setDisable(true);
            Executor.runScript(applyScriptPath, logArea, () -> {
                Platform.runLater(() -> {
                    applyButton.setDisable(false);
                    revertButton.setDisable(false);
                });
            });
        });

        // Validate revert script exists
        String revertScriptPath = scriptDirectory + tweak.getRevertScript();
        File revertScriptFile = new File(revertScriptPath);
        if (!revertScriptFile.exists()) {
            revertButton.setDisable(true);
            revertButton.setStyle("-fx-opacity: 0.5;");
        }

        revertButton.setOnAction(e -> {
            applyButton.setDisable(true);
            revertButton.setDisable(true);
            Executor.runScript(revertScriptPath, logArea, () -> {
                Platform.runLater(() -> {
                    applyButton.setDisable(false);
                    revertButton.setDisable(false);
                });
            });
        });

        tweakBox.getChildren().addAll(tweakTitle, applyButton, revertButton);
        return tweakBox;
    }
}