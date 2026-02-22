package com.zl.pleasetweakwindows;

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

    // Guarded by synchronized methods — no longer volatile
    private static Decision decision = Decision.UNKNOWN;
    private static final Object LOCK = new Object();

    public static void markCreated() {
        synchronized (LOCK) {
            decision = Decision.CREATED;
        }
    }

    public static void ensureRestorePoint(Stage owner,
                                          String scriptDirectory,
                                          TextArea logArea,
                                          BooleanProperty scriptsRunning,
                                          Runnable onProceed,
                                          Executor executor) {
        if (onProceed == null) {
            throw new IllegalArgumentException("onProceed callback must not be null");
        }

        synchronized (LOCK) {
            if (decision != Decision.UNKNOWN) {
                onProceed.run();
                return;
            }
        }

        DialogUtils.RestorePointDecision choice = DialogUtils.showRestorePointPrompt(owner);
        switch (choice) {
            case CREATE -> {
                String scriptPath = scriptDirectory + "create_restore_point.ps1";
                scriptsRunning.set(true);
                executor.runScript(scriptPath, logArea, (exitCode) -> {
                    if (exitCode == 0) {
                        synchronized (LOCK) {
                            decision = Decision.CREATED;
                        }
                    }
                    // Stay UNKNOWN on failure so user is prompted again next time
                    scriptsRunning.set(false);
                    onProceed.run();
                }, null);
            }
            case SKIP -> {
                synchronized (LOCK) {
                    decision = Decision.SKIPPED;
                }
                onProceed.run();
            }
            case CANCEL -> {
                // user cancelled
            }
        }
    }
}
