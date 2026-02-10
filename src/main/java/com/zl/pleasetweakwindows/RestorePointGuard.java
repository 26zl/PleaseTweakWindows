package com.zl.pleasetweakwindows;

import javafx.application.Platform;
import javafx.beans.property.BooleanProperty;
import javafx.scene.control.TextArea;
import javafx.stage.Stage;

public final class RestorePointGuard {
    private RestorePointGuard() {
    }

    private enum Decision {
        UNKNOWN,
        CREATED,
        SKIPPED
    }

    // Prompt once per session, remember the choice
    private static Decision decision = Decision.UNKNOWN;

    public static void markCreated() {
        decision = Decision.CREATED;
    }

    public static void ensureRestorePoint(Stage owner,
                                          String scriptDirectory,
                                          TextArea logArea,
                                          BooleanProperty scriptsRunning,
                                          Runnable onProceed) {
        if (decision != Decision.UNKNOWN) {
            onProceed.run();
            return;
        }

        DialogUtils.RestorePointDecision choice = DialogUtils.showRestorePointPrompt(owner);
        switch (choice) {
            case CREATE -> {
                decision = Decision.CREATED;
                String scriptPath = scriptDirectory + "create_restore_point.ps1";
                scriptsRunning.set(true);
                Executor.runScript(scriptPath, logArea, () -> Platform.runLater(() -> {
                    scriptsRunning.set(false);
                    onProceed.run();
                }), null);
            }
            case SKIP -> {
                decision = Decision.SKIPPED;
                onProceed.run();
            }
            case CANCEL -> {
                // user cancelled
            }
        }
    }
}
