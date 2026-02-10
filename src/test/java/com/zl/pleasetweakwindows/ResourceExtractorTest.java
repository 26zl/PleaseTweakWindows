package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;

/**
 * Sanity checks that packaged resources can be extracted and key scripts exist.
 */
class ResourceExtractorTest {

    @Test
    void prepareScriptsPathCopiesExpectedFiles() {
        Path scriptsDir = ResourceExtractor.prepareScriptsPath();
        assertTrue(Files.exists(scriptsDir), "Scripts directory should exist");

        assertScriptExists(scriptsDir, "Gaming optimizations/Gaming-Optimizations.ps1");
        assertScriptExists(scriptsDir, "Network optimizations/Network-Optimizations.ps1");
        assertScriptExists(scriptsDir, "General Tweaks/General-Tweaks.ps1");
        assertScriptExists(scriptsDir, "Services management/Services-Management.ps1");
        assertScriptExists(scriptsDir, "Privacy Security/privacy.ps1");
        assertScriptExists(scriptsDir, "Privacy Security/security.ps1");
        assertScriptExists(scriptsDir, "create_restore_point.ps1");
    }

    private void assertScriptExists(Path root, String relative) {
        Path p = root.resolve(relative);
        if (!Files.exists(p)) {
            fail("Missing extracted script: " + p);
        }
    }
}
