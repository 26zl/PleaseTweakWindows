package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;

/**
 * Verifies that all action IDs registered in TweakController have matching
 * handlers in the PowerShell dispatcher scripts.
 */
class ActionIdConsistencyTest {

    private static final Path SCRIPTS_DIR = Path.of("src/main/resources/scripts");

    @Test
    void allJavaActionIdsHavePowerShellHandlers() throws IOException {
        TweakController controller = new TweakController();
        controller.loadTweaks();

        Set<String> javaActions = new HashSet<>();
        for (Tweak tweak : controller.getTweaks()) {
            for (SubTweak sub : tweak.getSubTweaks()) {
                if (sub.getApplyAction() != null) {
                    javaActions.add(sub.getApplyAction());
                }
                if (sub.getRevertAction() != null) {
                    javaActions.add(sub.getRevertAction());
                }
            }
        }

        // Collect all quoted strings from PowerShell switch cases and ValidateSet
        Set<String> psActions = new HashSet<>();
        try (Stream<Path> paths = Files.walk(SCRIPTS_DIR)) {
            paths.filter(p -> p.toString().endsWith(".ps1"))
                 .filter(p -> !p.getFileName().toString().equals("CommonFunctions.ps1"))
                 .filter(p -> !p.getFileName().toString().equals("create_restore_point.ps1"))
                 .forEach(p -> {
                     try {
                         String content = Files.readString(p);
                         // Match quoted action IDs in switch cases and ValidateSet
                         Pattern pattern = Pattern.compile("\"([a-z][a-z0-9-]+)\"");
                         Matcher matcher = pattern.matcher(content);
                         while (matcher.find()) {
                             psActions.add(matcher.group(1));
                         }
                     } catch (IOException e) {
                         throw new RuntimeException(e);
                     }
                 });
        }

        // Exclude revert action IDs (handled by revert scripts with -Mode, not -Action)
        Set<String> nonRevertActions = new HashSet<>();
        for (String action : javaActions) {
            if (!action.endsWith("-revert")) {
                nonRevertActions.add(action);
            }
        }

        Set<String> missing = new HashSet<>();
        for (String action : nonRevertActions) {
            if (!psActions.contains(action)) {
                missing.add(action);
            }
        }

        assertTrue(missing.isEmpty(),
                "Java action IDs missing from PowerShell scripts: " + missing);
    }
}
