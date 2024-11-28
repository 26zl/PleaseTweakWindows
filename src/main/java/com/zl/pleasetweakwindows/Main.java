package com.zl.pleasetweakwindows;

import javafx.application.Application;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.TextArea;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

import java.io.File;

public class Main extends Application {

    private final String scriptDirectory = System.getProperty("user.dir") + File.separator + "scripts" + File.separator;
    private final TweakController tweakManager = new TweakController();
    private TextArea logArea;

    @Override
    public void start(Stage stage) {
        tweakManager.loadDefaultTweaks();

        logArea = new TextArea();
        logArea.setEditable(false);
        logArea.setPromptText("Verbose output will appear here...");
        logArea.setPrefHeight(600);

        VBox tweaksBox = new VBox(20);
        tweakManager.getTweaks().forEach(tweak ->
                tweaksBox.getChildren().add(UI.createTweakItem(tweak, logArea, scriptDirectory))
        );

        ScrollPane tweaksScrollPane = new ScrollPane(tweaksBox);
        tweaksScrollPane.setFitToWidth(true);

        VBox rightBox = new VBox(10);
        rightBox.getChildren().add(new Label("Verbose Output:"));
        rightBox.getChildren().add(logArea);

        Button createRestorePointButton = new Button("Create Restore Point");
        createRestorePointButton.setOnAction(e -> {
            logArea.appendText("Creating restore point...\n");
            Executor.RestorePoint("Restore Point", logArea);
            logArea.appendText("Restore point created.\n");
        });

        rightBox.getChildren().add(createRestorePointButton);

        BorderPane mainPane = new BorderPane();
        mainPane.setLeft(tweaksScrollPane);
        mainPane.setCenter(rightBox);

        Scene scene = new Scene(mainPane, 1000, 800);
        scene.getStylesheets().add(getClass().getResource("/com/zl/pleasetweakwindows/application.css").toExternalForm());
        stage.setScene(scene);
        stage.setTitle("PleaseTweakWindows");
        stage.show();
    }

    public static void main(String[] args) {
        launch();
    }
}