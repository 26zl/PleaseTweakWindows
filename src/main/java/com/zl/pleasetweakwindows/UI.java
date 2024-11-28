package com.zl.pleasetweakwindows;

import javafx.geometry.Pos;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TextArea;
import javafx.scene.layout.HBox;

public class UI {

    public static HBox createTweakItem(Tweak tweak, TextArea logArea, String scriptDirectory) {
        HBox tweakBox = new HBox(10);
        tweakBox.getStyleClass().add("tweak-box");
        tweakBox.setAlignment(Pos.CENTER);

        Label tweakTitle = new Label(tweak.getTitle());
        tweakTitle.getStyleClass().add("tweak-title");

        Button applyButton = new Button("Apply");
        applyButton.setOnAction(e -> {
            String scriptPath = scriptDirectory + tweak.getApplyScript();
            Executor.runScript(scriptPath, logArea);
        });

        Button revertButton = new Button("Revert");
        revertButton.setOnAction(e -> {
            String scriptPath = scriptDirectory + tweak.getRevertScript();
            Executor.runScript(scriptPath, logArea);
        });

        tweakBox.getChildren().addAll(tweakTitle, applyButton, revertButton);
        return tweakBox;
    }
}