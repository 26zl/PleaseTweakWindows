package com.zl.pleasetweakwindows;

import java.io.File;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javafx.application.Platform;
import javafx.beans.property.BooleanProperty;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.ProgressIndicator;
import javafx.scene.control.TextArea;
import javafx.scene.control.Tooltip;
import javafx.scene.layout.HBox;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;
import javafx.stage.Window;

import java.util.ArrayList;
import java.util.List;

public class UiLogic {

    private static final Logger LOGGER = LoggerFactory.getLogger(UiLogic.class);
    // Tracked for accordion behavior: only one category open at a time
    private static final List<VBox> allSubTweaksBoxes = new ArrayList<>();
    private static final List<Button> allExpandButtons = new ArrayList<>();

    public static VBox createExpandableTweakItem(Tweak tweak, TextArea logArea, String scriptDirectory, BooleanProperty scriptsRunning) {
        VBox container = new VBox(5);
        container.getStyleClass().add("tweak-container");

        HBox headerBox = new HBox(10);
        headerBox.getStyleClass().add("tweak-header");
        headerBox.setAlignment(Pos.CENTER_LEFT);
        headerBox.setPadding(new Insets(10));

        Label categoryLabel = new Label(tweak.getTitle());
        categoryLabel.getStyleClass().add("category-title");
        categoryLabel.setStyle("-fx-font-size: 16px; -fx-font-weight: bold;");

        Button expandButton = new Button("▼");
        expandButton.getStyleClass().add("expand-button");
        expandButton.setMinWidth(40);

        VBox subTweaksBox = new VBox(8);
        subTweaksBox.getStyleClass().add("sub-tweaks-box");
        subTweaksBox.setPadding(new Insets(10, 10, 10, 30));
        subTweaksBox.setManaged(false);
        subTweaksBox.setVisible(false);

        if (tweak.hasSubTweaks()) {
            for (SubTweak subTweak : tweak.getSubTweaks()) {
                subTweaksBox.getChildren().add(createSubTweakItem(subTweak, tweak, logArea, scriptDirectory, scriptsRunning));
            }
        }

        allSubTweaksBoxes.add(subTweaksBox);
        allExpandButtons.add(expandButton);

        // Accordion: collapse all others, then toggle this one
        expandButton.setOnAction(e -> {
            boolean isExpanded = subTweaksBox.isVisible();

            for (int i = 0; i < allSubTweaksBoxes.size(); i++) {
                VBox box = allSubTweaksBoxes.get(i);
                Button btn = allExpandButtons.get(i);
                if (box != subTweaksBox) {
                    box.setVisible(false);
                    box.setManaged(false);
                    btn.setText("▼");
                }
            }
            
            subTweaksBox.setVisible(!isExpanded);
            subTweaksBox.setManaged(!isExpanded);
            expandButton.setText(isExpanded ? "▼" : "▲");
        });

        Button runFullScriptButton = new Button("Run Full Script");
        runFullScriptButton.getStyleClass().add("run-full-script-button");
        runFullScriptButton.setTooltip(new Tooltip("Opens the PowerShell menu for this category"));
        runFullScriptButton.disableProperty().bind(scriptsRunning);
        runFullScriptButton.setOnAction(e -> {
            String scriptPath = scriptDirectory + tweak.getApplyScript();
            File scriptFile = new File(scriptPath);
            if (scriptFile.exists()) {
                LOGGER.info("Running full script menu for: {}", tweak.getTitle());
                Stage owner = resolveOwnerStage(runFullScriptButton);
                Runnable runAction = () -> {
                    scriptsRunning.set(true);
                    Executor.runScript(scriptPath, logArea, () -> {
                        Platform.runLater(() -> scriptsRunning.set(false));
                    }, "Menu");
                };
                RestorePointGuard.ensureRestorePoint(owner, scriptDirectory, logArea, scriptsRunning, runAction);
            } else {
                LOGGER.warn("Script not found: {}", scriptPath);
            }
        });

        headerBox.getChildren().addAll(expandButton, categoryLabel, runFullScriptButton);
        container.getChildren().addAll(headerBox, subTweaksBox);

        return container;
    }

    private static HBox createSubTweakItem(SubTweak subTweak, Tweak parentTweak, TextArea logArea, String scriptDirectory, BooleanProperty scriptsRunning) {
        HBox itemBox = new HBox(10);
        itemBox.setAlignment(Pos.CENTER_LEFT);
        itemBox.getStyleClass().add("sub-tweak-item");
        itemBox.setPadding(new Insets(5));

        Label nameLabel = new Label(subTweak.getName());
        nameLabel.setMinWidth(200);
        nameLabel.getStyleClass().add("sub-tweak-name");

        if (subTweak.getDescription() != null && !subTweak.getDescription().isEmpty()) {
            Tooltip tooltip = new Tooltip(subTweak.getDescription());
            tooltip.setWrapText(true);
            tooltip.setMaxWidth(400);
            Tooltip.install(nameLabel, tooltip);
        }

        ProgressIndicator spinner = new ProgressIndicator();
        spinner.setMaxSize(20, 20);
        spinner.setVisible(false);

        String applyLabel = subTweak.getApplyLabel();
        Button applyButton = new Button((applyLabel == null || applyLabel.isBlank()) ? "Apply" : applyLabel);
        applyButton.setMinWidth(70);
        applyButton.getStyleClass().add("apply-button");
        applyButton.disableProperty().bind(scriptsRunning);

        Button revertButton = null;
        if (subTweak.getType() == SubTweak.SubTweakType.TOGGLE && subTweak.getRevertAction() != null) {
            String revertLabel = subTweak.getRevertLabel();
            revertButton = new Button((revertLabel == null || revertLabel.isBlank()) ? "Revert" : revertLabel);
            revertButton.setMinWidth(70);
            revertButton.getStyleClass().add("revert-button");
            revertButton.disableProperty().bind(scriptsRunning);
        }

        // Effectively final copy for use in lambdas
        Button finalRevertButton = revertButton;

        applyButton.setOnAction(e -> executeSubTweakAction(
                scriptDirectory + parentTweak.getApplyScript(),
                subTweak.getApplyAction(), "apply",
                applyButton, applyButton, finalRevertButton,
                spinner, logArea, scriptsRunning, scriptDirectory, subTweak.getName()));

        itemBox.getChildren().addAll(nameLabel, applyButton);

        if (revertButton != null) {
            Button finalRevertButtonInner = revertButton;
            revertButton.setOnAction(e -> {
                String revertScript = parentTweak.getRevertScript();
                String revertPath = scriptDirectory + ((revertScript == null || revertScript.isBlank())
                        ? parentTweak.getApplyScript() : revertScript);
                executeSubTweakAction(revertPath, subTweak.getRevertAction(), "revert",
                        finalRevertButtonInner, applyButton, finalRevertButtonInner,
                        spinner, logArea, scriptsRunning, scriptDirectory, subTweak.getName());
            });

            itemBox.getChildren().add(revertButton);
        }

        itemBox.getChildren().add(spinner);

        return itemBox;
    }

    // Shared handler for both apply and revert button clicks
    private static void executeSubTweakAction(String scriptPath, String action, String actionType,
                                                Button triggerButton, Button applyButton, Button revertButton,
                                                ProgressIndicator spinner, TextArea logArea,
                                                BooleanProperty scriptsRunning, String scriptDirectory,
                                                String subTweakName) {
        if (scriptsRunning.get()) return;

        if (action == null || action.isEmpty()) {
            LOGGER.warn("No {} action defined for: {}", actionType, subTweakName);
            logArea.appendText("No " + actionType + " action defined for " + subTweakName + "\n");
            return;
        }

        Stage owner = resolveOwnerStage(triggerButton);
        Runnable runAction = () -> {
            if (DialogUtils.requiresConfirmation(action)) {
                if (!DialogUtils.showConfirmation(action, subTweakName, owner)) {
                    return;
                }
            }

            LOGGER.debug("Executing {} action: {} for {}", actionType, action, subTweakName);
            applyButton.setDisable(true);
            if (revertButton != null) revertButton.setDisable(true);
            spinner.setVisible(true);
            scriptsRunning.set(true);
            Executor.runScript(scriptPath, logArea, () -> Platform.runLater(() -> {
                scriptsRunning.set(false);
                spinner.setVisible(false);
                applyButton.setDisable(false);
                if (revertButton != null) revertButton.setDisable(false);
            }), action);
        };

        RestorePointGuard.ensureRestorePoint(owner, scriptDirectory, logArea, scriptsRunning, runAction);
    }

    private static Stage resolveOwnerStage(Button button) {
        if (button.getScene() == null) {
            return null;
        }
        Window window = button.getScene().getWindow();
        if (window instanceof Stage stage) {
            return stage;
        }
        return null;
    }
}
