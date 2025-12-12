package com.zl.pleasetweakwindows;

import java.io.File;
import java.util.Objects;

import javafx.application.Application;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.TextArea;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

public class Main extends Application {

    private final TweakController tweakManager = new TweakController();
    private TextArea logArea;

    @Override
    public void start(Stage stage) {
        String scriptDirectory = ResourceExtractor.prepareScriptsPath().toString() + File.separator;
        tweakManager.loadTweaks();

        logArea = new TextArea();
        logArea.setEditable(false);
        logArea.setFocusTraversable(false);
        logArea.setPromptText("Verbose output will appear here...");
        logArea.setPrefHeight(700);
        logArea.setId("log-area");

        VBox tweaksBox = new VBox(15);
        tweaksBox.getStyleClass().add("tweaks-box");
        tweakManager.getTweaks().forEach(tweak ->
                tweaksBox.getChildren().add(UiLogic.createTweakItem(tweak, logArea, scriptDirectory))
        );

        ScrollPane tweaksScrollPane = new ScrollPane(tweaksBox);
        tweaksScrollPane.setFitToWidth(true);

        // Create header with daemon image
        HBox headerBox = new HBox(15);
        headerBox.setAlignment(Pos.CENTER);
        headerBox.getStyleClass().add("header-box");
        
        try {
            Image daemonImage = new Image(Objects.requireNonNull(Main.class.getResourceAsStream("/daemon.png")));
            ImageView daemonImageView = new ImageView(daemonImage);
            daemonImageView.setFitHeight(80);
            daemonImageView.setPreserveRatio(true);
            daemonImageView.getStyleClass().add("daemon-image");
            headerBox.getChildren().add(daemonImageView);
        } catch (Exception e) {
            // If image fails to load, continue without it
        }
        
        Label titleLabel = new Label("PleaseTweakWindows");
        titleLabel.setStyle("-fx-font-size: 28px; -fx-font-weight: bold; -fx-text-fill: #f5e6e6; -fx-effect: dropshadow(three-pass-box, rgba(204, 0, 0, 0.6), 10, 0, 0, 2);");
        headerBox.getChildren().add(titleLabel);

        VBox rightBox = new VBox(10);
        rightBox.setAlignment(Pos.CENTER);
        rightBox.getStyleClass().add("right-box");
        rightBox.getChildren().add(new Label("Verbose Output:"));
        rightBox.getChildren().add(logArea);

        Button createRestorePointButton = new Button("Create Restore Point");
        createRestorePointButton.setOnAction(e -> {
            Executor.createRestorePoint(logArea, scriptDirectory);
        });

        Button clearLogButton = new Button("Clear Log");
        clearLogButton.setOnAction(e -> {
            logArea.clear();
        });

        HBox buttonBox = new HBox(10);
        buttonBox.setAlignment(Pos.CENTER);
        buttonBox.getChildren().addAll(createRestorePointButton, clearLogButton);

        rightBox.getChildren().add(buttonBox);

        BorderPane mainPane = new BorderPane();
        mainPane.setTop(headerBox);
        mainPane.setLeft(tweaksScrollPane);
        mainPane.setCenter(rightBox);

        Scene scene = new Scene(mainPane, 1200, 850);
        scene.getStylesheets().add(Objects.requireNonNull(Main.class.getResource("/com/zl/pleasetweakwindows/application.css")).toExternalForm());
        stage.setScene(scene);
        addStageIcons(stage);
        stage.setTitle("PleaseTweakWindows");
        stage.show();
    }

    @Override
    public void stop() throws Exception {
        Executor.shutdown();
        super.stop();
    }

    private void addStageIcons(Stage stage) {
        String[] iconResources = {"/daemonWindows.ico", "/daemonIcon.png", "/daemon.png"};
        for (String resource : iconResources) {
            try {
                Image icon = new Image(Objects.requireNonNull(Main.class.getResourceAsStream(resource)));
                stage.getIcons().add(icon);
            } catch (Exception ignored) {
                // Skip missing variants and continue.
            }
        }
    }

    public static void main(String[] args) {
        launch();
    }
}
