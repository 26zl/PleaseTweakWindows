package com.zl.pleasetweakwindows;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Objects;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javafx.application.Application;
import javafx.beans.property.BooleanProperty;
import javafx.beans.property.SimpleBooleanProperty;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;
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

    static {
        try {
            String command = ProcessHandle.current().info().command().orElse(null);
            if (command != null) {
                Path fileName = Path.of(command).getFileName();
                // Only override CWD when running as the native EXE, not via java/javaw
                if (fileName != null && !fileName.toString().toLowerCase().startsWith("java")) {
                    Path exeDir = Path.of(command).toAbsolutePath().getParent();
                    if (exeDir != null && Files.isDirectory(exeDir)) {
                        System.setProperty("user.dir", exeDir.toString());
                        // Set log directory before logback initializes (must happen before Logger field init)
                        System.setProperty("ptw.log.dir", exeDir.resolve("logs").toString());
                    }
                }
            }
        } catch (Exception ignored) {
            // Best-effort: fall back to default user.dir
        }
    }

    private TextArea logArea;
    private final BooleanProperty scriptsRunning = new SimpleBooleanProperty(false);
    private static final Logger LOGGER = LoggerFactory.getLogger(Main.class);
    private double dragOffsetX;
    private double dragOffsetY;
    private Executor executor;
    private UiLogic uiLogic;

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
            Alert alert = new Alert(AlertType.ERROR);
            alert.initStyle(StageStyle.UTILITY);
            alert.setTitle("Administrator Required");
            alert.setHeaderText("PleaseTweakWindows requires Administrator privileges");
            alert.setContentText("Please right-click the application and select \"Run as administrator\".");
            alert.showAndWait();
            System.exit(1);
            return;
        }

        if (!Executor.isPowerShellAvailable()) {
            LOGGER.error("PowerShell 5.1 not found. Scripts cannot execute.");
            Alert psAlert = new Alert(AlertType.ERROR);
            psAlert.initStyle(StageStyle.UTILITY);
            psAlert.setTitle("PowerShell Not Found");
            psAlert.setHeaderText("Windows PowerShell 5.1 is required");
            psAlert.setContentText("""
                                   PleaseTweakWindows requires Windows PowerShell 5.1 (powershell.exe) to run scripts.
                                   
                                   Please ensure PowerShell 5.1 is installed and available at:
                                   """ +
                    System.getenv("SystemRoot") + "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe");
            psAlert.showAndWait();
            System.exit(1);
            return;
        }

        executor = new Executor();
        uiLogic = new UiLogic(executor);

        // Extract bundled PS scripts to a temp directory for execution
        String scriptDirectory;
        try {
            Path scriptsPath = ResourceExtractor.prepareScriptsPath();
            scriptDirectory = scriptsPath.toString() + File.separator;
            executor.setScriptsBaseDir(scriptsPath);
        } catch (Exception e) {
            LOGGER.error("Failed to extract scripts", e);
            Alert extractAlert = new Alert(AlertType.ERROR);
            extractAlert.initStyle(StageStyle.UTILITY);
            extractAlert.setTitle("Startup Error");
            extractAlert.setHeaderText("Failed to extract scripts");
            extractAlert.setContentText("The application could not prepare its scripts directory.\n\n" + e.getMessage());
            extractAlert.showAndWait();
            System.exit(1);
            return;
        }

        logArea = new TextArea();
        logArea.setEditable(false);
        logArea.setFocusTraversable(false);
        logArea.setPromptText("Verbose output will appear here...");
        logArea.setPrefHeight(500);
        logArea.setId("log-area");

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

        VBox topContainer = new VBox();
        topContainer.getChildren().add(headerBox);

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
            executor.runScript(scriptPath, logArea, (exitCode) -> {
                scriptsRunning.set(false);
                if (exitCode == 0) {
                    RestorePointGuard.markCreated();
                }
            }, null);
        });
        tweaksBox.getChildren().add(restorePointBtn);

        for (Tweak tweak : tweakController.getTweaks()) {
            VBox tweakItem = uiLogic.createExpandableTweakItem(tweak, logArea, scriptDirectory, scriptsRunning);
            tweakItem.setUserData(tweak);
            tweaksBox.getChildren().add(tweakItem);
        }

        ScrollPane tweaksScrollPane = new ScrollPane(tweaksBox);
        tweaksScrollPane.setFitToWidth(true);
        tweaksScrollPane.getStyleClass().add("scroll-pane");
        tweaksScrollPane.setPrefWidth(500);

        searchField.textProperty().addListener((obs, oldVal, newVal) -> {
            String filter = newVal.toLowerCase().trim();
            for (var node : tweaksBox.getChildren()) {
                switch (node) {
                    case VBox tweakItem -> {
                        if (filter.isEmpty()) {
                            tweakItem.setVisible(true);
                            tweakItem.setManaged(true);
                            continue;
                        }
                        boolean matches = false;
                        Object userData = tweakItem.getUserData();
                        if (userData instanceof Tweak tweak) {
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
        closeButton.setOnAction(e -> handleCloseRequest(stage));

        HBox buttonBar = new HBox(10, clearButton, closeButton);
        buttonBar.setAlignment(Pos.CENTER);

        rightBox.getChildren().addAll(new Label("Verbose Output:"), logArea, buttonBar);
        VBox.setVgrow(logArea, Priority.ALWAYS);

        BorderPane mainPane = new BorderPane();
        mainPane.setTop(topContainer);
        mainPane.setLeft(tweaksScrollPane);
        mainPane.setCenter(rightBox);

        Scene scene = new Scene(mainPane, 1200, 850);
        scene.getStylesheets().add(Objects.requireNonNull(Main.class.getResource("/com/zl/pleasetweakwindows/application.css")).toExternalForm());
        stage.setScene(scene);
        addStageIcons(stage);
        stage.setTitle("PleaseTweakWindows");
        stage.show();
        LOGGER.info("UI started.");

        new UpdateChecker(topContainer).checkAsync();
    }

    @Override
    public void stop() throws Exception {
        LOGGER.info("Shutting down PleaseTweakWindows.");
        if (executor != null) {
            executor.shutdown();
        }
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
        close.setOnAction(e -> handleCloseRequest(stage));

        HBox controls = new HBox(6, minimize, maximize, close);
        controls.setAlignment(Pos.CENTER_RIGHT);
        controls.getStyleClass().add("window-controls");
        return controls;
    }

    private void handleCloseRequest(Stage stage) {
        if (executor != null && executor.hasActiveOperations()) {
            if (DialogUtils.showCancelConfirmation(stage)) {
                executor.cancelAllOperations();
                stage.close();
            }
        } else {
            stage.close();
        }
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
        String osName = System.getProperty("os.name");
        if (osName == null || !osName.toLowerCase().contains("windows")) {
            return true;
        }

        try {
            // "net session" returns 0 only when running as admin
            ProcessBuilder pb = new ProcessBuilder("net", "session");
            pb.redirectErrorStream(true);
            Process p = pb.start();
            try (var is = p.getInputStream()) {
                is.readAllBytes();
                boolean finished = p.waitFor(5, TimeUnit.SECONDS);
                if (!finished) {
                    p.destroyForcibly();
                    return false;
                }
                return p.exitValue() == 0;
            } finally {
                p.destroy();
            }
        } catch (IOException | InterruptedException e) {
            LOGGER.warn("Administrator privilege check failed: {}", e.getMessage());
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            return false;
        }
    }

}
