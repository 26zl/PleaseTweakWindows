package com.zl.pleasetweakwindows;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Objects;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.beans.property.BooleanProperty;
import javafx.beans.property.SimpleBooleanProperty;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.TextArea;
import javafx.scene.control.TextField;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.Region;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;
import javafx.stage.StageStyle;

public class Main extends Application {
    private TextArea logArea;
    private final BooleanProperty scriptsRunning = new SimpleBooleanProperty(false);
    private static final Logger LOGGER = LoggerFactory.getLogger(Main.class);
    private double dragOffsetX;
    private double dragOffsetY;

    @Override
    public void start(Stage stage) {
        Thread.currentThread().setUncaughtExceptionHandler((thread, throwable) -> {
            LOGGER.error("Uncaught exception in JavaFX Application Thread", throwable);
        });

        // Custom title bar - window chrome is drawn manually
        stage.initStyle(StageStyle.UNDECORATED);
        ensureLogsDirectory();
        LOGGER.info("Starting PleaseTweakWindows UI.");

        if (!isRunningAsAdministrator()) {
            LOGGER.error("Application must be run as Administrator. Exiting immediately.");
            Platform.exit();
            System.exit(1);
        }

        // Extract bundled PS scripts to a temp directory for execution
        String scriptDirectory = ResourceExtractor.prepareScriptsPath().toString() + File.separator;

        logArea = new TextArea();
        logArea.setEditable(false);
        logArea.setFocusTraversable(false);
        logArea.setPromptText("Verbose output will appear here...");
        logArea.setPrefHeight(500);
        logArea.setId("log-area");
        VBox.setVgrow(logArea, Priority.ALWAYS);

        HBox headerBox = new HBox(15);
        headerBox.setAlignment(Pos.CENTER);
        headerBox.getStyleClass().add("header-box");

        try {
            Image daemonImage = new Image(Objects.requireNonNull(Main.class.getResourceAsStream("/images/daemon.png")));
            ImageView daemonImageView = new ImageView(daemonImage);
            daemonImageView.setFitHeight(80);
            daemonImageView.setPreserveRatio(true);
            daemonImageView.getStyleClass().add("daemon-image");
            headerBox.getChildren().add(daemonImageView);
        } catch (Exception e) {
            LOGGER.warn("Failed to load header image.", e);
        }

        Label titleLabel = new Label("PleaseTweakWindows");
        titleLabel.setStyle("-fx-font-size: 28px; -fx-font-weight: bold; -fx-text-fill: #f5e6e6; -fx-effect: dropshadow(three-pass-box, rgba(204, 0, 0, 0.6), 10, 0, 0, 2);");
        
        TextField searchField = new TextField();
        searchField.setPromptText("Search tweaks...");
        searchField.getStyleClass().add("search-field");
        searchField.setPrefWidth(200);
        
        HBox titleBox = new HBox(20, titleLabel, searchField);
        titleBox.setAlignment(Pos.CENTER_LEFT);

        Region spacer = new Region();
        HBox.setHgrow(spacer, Priority.ALWAYS);

        HBox windowControls = createWindowControls(stage);

        headerBox.getChildren().addAll(titleBox, spacer, windowControls);
        enableWindowDrag(stage, headerBox);

        TweakController tweakController = new TweakController();
        tweakController.loadTweaks();

        VBox tweaksBox = new VBox(15);
        tweaksBox.getStyleClass().add("tweaks-box");
        tweaksBox.setPadding(new Insets(20));

        Button restorePointBtn = new Button("Create Restore Point");
        restorePointBtn.getStyleClass().add("button");
        restorePointBtn.setMaxWidth(Double.MAX_VALUE);
        restorePointBtn.disableProperty().bind(scriptsRunning);
        restorePointBtn.setOnAction(e -> {
            String scriptPath = scriptDirectory + "create_restore_point.ps1";
            scriptsRunning.set(true);
            Executor.runScript(scriptPath, logArea, () -> Platform.runLater(() -> {
                scriptsRunning.set(false);
                RestorePointGuard.markCreated();
            }), null);
        });
        tweaksBox.getChildren().add(restorePointBtn);

        for (Tweak tweak : tweakController.getTweaks()) {
            VBox tweakItem = UiLogic.createExpandableTweakItem(tweak, logArea, scriptDirectory, scriptsRunning);
            tweaksBox.getChildren().add(tweakItem);
        }

        ScrollPane tweaksScrollPane = new ScrollPane(tweaksBox);
        tweaksScrollPane.setFitToWidth(true);
        tweaksScrollPane.getStyleClass().add("scroll-pane");
        tweaksScrollPane.setPrefWidth(500);

        searchField.textProperty().addListener((obs, oldVal, newVal) -> {
            String filter = newVal.toLowerCase().trim();
            int tweakIndex = 0;
            for (var node : tweaksBox.getChildren()) {
                switch (node) {
                    case VBox tweakItem -> {
                        if (filter.isEmpty()) {
                            tweakItem.setVisible(true);
                            tweakItem.setManaged(true);
                            continue;
                        }
                        boolean matches = false;
                        Tweak tweak = tweakIndex < tweakController.getTweaks().size()
                            ? tweakController.getTweaks().get(tweakIndex) : null;
                        tweakIndex++;

                        if (tweak != null) {
                            if (tweak.getTitle().toLowerCase().contains(filter)) {
                                matches = true;
                            }
                            for (SubTweak sub : tweak.getSubTweaks()) {
                                if (sub.getName().toLowerCase().contains(filter)) {
                                    matches = true;
                                    break;
                                }
                                if (sub.getDescription() != null &&
                                    sub.getDescription().toLowerCase().contains(filter)) {
                                    matches = true;
                                    break;
                                }
                            }
                        }
                        tweakItem.setVisible(matches);
                        tweakItem.setManaged(matches);
                    }
                    case Button btn -> {
                        boolean matches = filter.isEmpty() || btn.getText().toLowerCase().contains(filter);
                        btn.setVisible(matches);
                        btn.setManaged(matches);
                    }
                    default -> {}
                }
            }
        });

        VBox rightBox = new VBox(10);
        rightBox.setAlignment(Pos.TOP_CENTER);
        rightBox.getStyleClass().add("right-box");
        rightBox.setPadding(new Insets(20));
        
        Button clearButton = new Button("Clear");
        clearButton.setOnAction(e -> logArea.clear());
        
        Button closeButton = new Button("Close");
        closeButton.setOnAction(e -> {
            if (Executor.hasActiveOperations()) {
                if (DialogUtils.showCancelConfirmation(stage)) {
                    Executor.cancelAllOperations();
                    stage.close();
                }
            } else {
                stage.close();
            }
        });
        
        HBox buttonBar = new HBox(10, clearButton, closeButton);
        buttonBar.setAlignment(Pos.CENTER);
        
        rightBox.getChildren().addAll(new Label("Verbose Output:"), logArea, buttonBar);
        VBox.setVgrow(logArea, Priority.ALWAYS);

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
        LOGGER.info("UI started.");
    }

    @Override
    public void stop() throws Exception {
        LOGGER.info("Shutting down PleaseTweakWindows.");
        Executor.shutdown();
        super.stop();
    }

    private void addStageIcons(Stage stage) {
        String[] iconResources = {"/images/daemonWindows.ico", "/images/daemonIcon.png", "/images/daemon.png"};
        for (String resource : iconResources) {
            try {
                Image icon = new Image(Objects.requireNonNull(Main.class.getResourceAsStream(resource)));
                stage.getIcons().add(icon);
            } catch (Exception ignored) {
                LOGGER.debug("Optional icon missing: {}", resource);
            }
        }
    }

    private void ensureLogsDirectory() {
        Path logDir = Paths.get(System.getProperty("user.dir"), "logs");
        try {
            Files.createDirectories(logDir);
        } catch (IOException e) {
            LOGGER.error("Failed to create logs directory", e);
        }
    }

    public static void main(String[] args) {
        launch();
    }

    private HBox createWindowControls(Stage stage) {
        Button minimize = new Button("-");
        minimize.getStyleClass().addAll("window-button", "window-minimize");
        minimize.setOnAction(e -> stage.setIconified(true));

        Button maximize = new Button("[]");
        maximize.getStyleClass().addAll("window-button", "window-maximize");
        maximize.setOnAction(e -> stage.setMaximized(!stage.isMaximized()));

        Button close = new Button("X");
        close.getStyleClass().addAll("window-button", "window-close");
        close.setOnAction(e -> stage.close());

        HBox controls = new HBox(6, minimize, maximize, close);
        controls.setAlignment(Pos.CENTER_RIGHT);
        controls.getStyleClass().add("window-controls");
        return controls;
    }

    private void enableWindowDrag(Stage stage, HBox dragArea) {
        dragArea.setOnMousePressed(event -> {
            dragOffsetX = event.getSceneX();
            dragOffsetY = event.getSceneY();
        });

        dragArea.setOnMouseDragged(event -> {
            stage.setX(event.getScreenX() - dragOffsetX);
            stage.setY(event.getScreenY() - dragOffsetY);
        });

        dragArea.setOnMouseClicked(event -> {
            if (event.getClickCount() == 2) {
                stage.setMaximized(!stage.isMaximized());
            }
        });
    }

    private boolean isRunningAsAdministrator() {
        if (!System.getProperty("os.name").toLowerCase().contains("windows")) {
            return true;
        }

        try {
            // "net session" returns 0 only when running as admin
        ProcessBuilder pb = new ProcessBuilder("net", "session");
            pb.redirectErrorStream(true);
            Process p = pb.start();
            try {
                p.getInputStream().readAllBytes();
                int exitCode = p.waitFor();
                return exitCode == 0;
            } finally {
                p.destroy();
            }
        } catch (IOException | InterruptedException e) {
            LOGGER.warn("Administrator privilege check failed: {}", e.getMessage());
            return false;
        }
    }

}
