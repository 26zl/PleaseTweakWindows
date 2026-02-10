package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import java.util.List;

import org.junit.jupiter.api.Test;

/**
 * Ensures that loaded tweaks reference scripts that exist on disk.
 */
class TweakControllerPathTest {

    @Test
    void loadedTweaksHaveExistingScripts() {
        TweakController controller = new TweakController();
        controller.loadTweaks();

        String scriptRoot = "src/main/resources/scripts/";
        List<Tweak> tweaks = controller.getTweaks();
        assertTrue(tweaks.size() >= 6, "Should load at least 6 tweak categories (including Privacy and Security)");
        assertTrue(tweaks.stream().anyMatch(t -> "Privacy".equals(t.getTitle())),
                "Privacy tweak should be loaded");
        assertTrue(tweaks.stream().anyMatch(t -> "Security".equals(t.getTitle())),
                "Security tweak should be loaded");

        tweaks.forEach(tweak -> {
            assertExists(scriptRoot + tweak.getApplyScript());
            assertExists(scriptRoot + tweak.getRevertScript());
            tweak.getSubTweaks().forEach(sub -> assertTrue(sub.getName() != null && !sub.getName().isBlank()));
        });
    }

    private void assertExists(String path) {
        File f = new File(path);
        assertTrue(f.exists(), "Expected file to exist: " + path);
    }
}
