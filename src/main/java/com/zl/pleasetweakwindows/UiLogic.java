package com.zl.pleasetweakwindows;

import java.io.File;

import javafx.beans.property.BooleanProperty;
import javafx.beans.property.SimpleBooleanProperty;
import javafx.application.Platform;
import javafx.geometry.Pos;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TextArea;
import javafx.scene.layout.HBox;

public class UiLogic {

    public static HBox createTweakItem(Tweak tweak, TextArea logArea, String scriptDirectory, BooleanProperty scriptsRunning) {
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
        BooleanProperty applyScriptExists = new SimpleBooleanProperty(applyScriptFile.exists());
        if (!applyScriptFile.exists()) {
            applyButton.setStyle("-fx-opacity: 0.5;");
        }

        applyButton.disableProperty().bind(scriptsRunning.or(applyScriptExists.not()));
        applyButton.setOnAction(e -> {
            scriptsRunning.set(true);
            Executor.runScript(applyScriptPath, logArea, () -> {
                Platform.runLater(() -> {
                    scriptsRunning.set(false);
                });
            });
        });

        // Validate revert script exists
        String revertScriptPath = scriptDirectory + tweak.getRevertScript();
        File revertScriptFile = new File(revertScriptPath);
        BooleanProperty revertScriptExists = new SimpleBooleanProperty(revertScriptFile.exists());
        if (!revertScriptFile.exists()) {
            revertButton.setStyle("-fx-opacity: 0.5;");
        }

        revertButton.disableProperty().bind(scriptsRunning.or(revertScriptExists.not()));
        revertButton.setOnAction(e -> {
            scriptsRunning.set(true);
            Executor.runScript(revertScriptPath, logArea, () -> {
                Platform.runLater(() -> {
                    scriptsRunning.set(false);
                });
            });
        });

        tweakBox.getChildren().addAll(tweakTitle, applyButton, revertButton);
        return tweakBox;
    }
}
