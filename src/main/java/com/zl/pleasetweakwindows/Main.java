package com.zl.pleasetweakwindows;

import javafx.application.Application;
import javafx.geometry.Pos;
import javafx.scene.Node;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollBar;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.TextArea;
import javafx.scene.input.MouseEvent;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

import java.io.File;
import java.util.Objects;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Main extends Application {

    private final String scriptDirectory = System.getProperty("user.dir") + File.separator + "scripts" + File.separator;
    private final TweakController tweakManager = new TweakController();
    private TextArea logArea;
    private final ExecutorService backgroundExecutor = Executors.newCachedThreadPool();

    @Override
    public void start(Stage stage) {
        tweakManager.loadTweaks();

        logArea = new TextArea();
        logArea.setEditable(false);
        logArea.setFocusTraversable(false);
        logArea.setPromptText("Verbose output will appear here...");
        logArea.setPrefHeight(700);

        logArea.addEventFilter(MouseEvent.MOUSE_PRESSED, event -> {
            if (!isEventOnScrollBar(event.getTarget())) {
                event.consume();
            }
        });

        VBox tweaksBox = new VBox(70);
        tweakManager.getTweaks().forEach(tweak ->
                tweaksBox.getChildren().add(UiLogic.createTweakItem(tweak, logArea, scriptDirectory))
        );

        ScrollPane tweaksScrollPane = new ScrollPane(tweaksBox);
        tweaksScrollPane.setFitToWidth(true);

        VBox rightBox = new VBox(10);
        rightBox.setAlignment(Pos.CENTER);
        rightBox.getChildren().add(new Label("Verbose Output:"));
        rightBox.getChildren().add(logArea);

        Button createRestorePointButton = new Button("Create Restore Point");
        createRestorePointButton.setOnAction(e -> {
            logArea.appendText("Creating restore point...\n");
            backgroundExecutor.submit(() -> Executor.createRestorePoint(logArea));
        });

        rightBox.getChildren().add(createRestorePointButton);

        BorderPane mainPane = new BorderPane();
        mainPane.setLeft(tweaksScrollPane);
        mainPane.setCenter(rightBox);

        Scene scene = new Scene(mainPane, 1200, 800);
        scene.getStylesheets().add(Objects.requireNonNull(getClass().getResource("/com/zl/pleasetweakwindows/application.css")).toExternalForm());
        stage.setScene(scene);
        stage.setTitle("PleaseTweakWindows");
        stage.show();
    }

    @Override
    public void stop() throws Exception {
        backgroundExecutor.shutdown();
        super.stop();
    }

    private boolean isEventOnScrollBar(Object target) {
        if (!(target instanceof Node node)) {
            return false;
        }
        while (node != null) {
            if (node instanceof ScrollBar) {
                return true;
            }
            node = node.getParent();
        }
        return false;
    }

    public static void main(String[] args) {
        launch();
    }
}