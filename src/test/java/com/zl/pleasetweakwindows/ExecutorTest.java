package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Unit tests for the Executor class.
 * Tests validation logic and error handling.
 */
class ExecutorTest {

    private Executor executor;

    @BeforeEach
    void setUp() {
        executor = new Executor();
    }

    @AfterEach
    void tearDown() {
        executor.shutdown();
    }

    @Test
    void testValidActionParameters() {
        assertTrue(executor.isValidAction("Apply"), "Apply should be valid");
        assertTrue(executor.isValidAction("Revert"), "Revert should be valid");
        assertTrue(executor.isValidAction("Menu"), "Menu should be valid");
        assertTrue(executor.isValidAction("nvidia-settings-on"), "Lowercase dashed action should be valid");
        assertTrue(executor.isValidAction("abc_123"), "Underscore/numeric action should be valid");
    }

    @Test
    void testInvalidActionParameters() {
        assertFalse(executor.isValidAction(""), "Empty string should be rejected");
        assertFalse(executor.isValidAction("a"), "Too short should be rejected");
        assertFalse(executor.isValidAction("apply;"), "Command injection attempt should be rejected");
        assertFalse(executor.isValidAction("bad value"), "Spaces should be rejected");
        assertFalse(executor.isValidAction("foo|bar"), "Pipes should be rejected");
    }

    @Test
    void testValidScriptPaths() {
        assertTrue(executor.isValidScriptPath("C:\\scripts\\test.ps1"), "Valid PowerShell path should be accepted");
        assertFalse(executor.isValidScriptPath("C:\\scripts\\test.bat"), "Batch files should be rejected (only .ps1 supported)");
    }

    @Test
    void testInvalidScriptPaths() {
        assertFalse(executor.isValidScriptPath("C:\\scripts\\..\\..\\windows\\system32\\cmd.exe"), "Path traversal should be rejected");
        assertFalse(executor.isValidScriptPath("C:\\scripts\\test.exe"), "Non-script file should be rejected");
        assertFalse(executor.isValidScriptPath("C:\\scripts\\test.ps1; rm -rf"), "Command injection should be rejected");
        assertFalse(executor.isValidScriptPath("C:\\scripts\\test|dangerous.ps1"), "Pipe character should be rejected");
        assertFalse(executor.isValidScriptPath(null), "Null path should be rejected");
        assertFalse(executor.isValidScriptPath(""), "Empty path should be rejected");
    }

    @Test
    void testWindowsDirectoryNotNull() throws Exception {
        var field = Executor.class.getDeclaredField("WINDOWS_DIR");
        field.setAccessible(true);
        String windowsDir = (String) field.get(null);
        assertNotNull(windowsDir, "Windows directory should not be null");
        assertFalse(windowsDir.isBlank(), "Windows directory should not be blank");
    }
}
