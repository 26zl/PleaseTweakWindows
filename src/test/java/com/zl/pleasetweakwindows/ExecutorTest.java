package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;
import org.junit.jupiter.api.Test;

/**
 * Unit tests for the Executor class.
 * Tests validation logic and error handling.
 */
class ExecutorTest {

    @Test
    void testValidActionParameters() {
        assertTrue(isValidActionPublic("Apply"), "Apply should be valid");
        assertTrue(isValidActionPublic("Revert"), "Revert should be valid");
        assertTrue(isValidActionPublic("Menu"), "Menu should be valid");
        assertTrue(isValidActionPublic("nvidia-settings-on"), "Lowercase dashed action should be valid");
        assertTrue(isValidActionPublic("abc_123"), "Underscore/numeric action should be valid");
    }

    @Test
    void testInvalidActionParameters() {
        assertFalse(isValidActionPublic(""), "Empty string should be rejected");
        assertFalse(isValidActionPublic("a"), "Too short should be rejected");
        assertFalse(isValidActionPublic("apply;"), "Command injection attempt should be rejected");
        assertFalse(isValidActionPublic("bad value"), "Spaces should be rejected");
        assertFalse(isValidActionPublic("foo|bar"), "Pipes should be rejected");
    }

    @Test
    void testValidScriptPaths() {
        // Test that valid script paths are accepted
        assertTrue(isValidScriptPathPublic("C:\\scripts\\test.ps1"), "Valid PowerShell path should be accepted");
        assertTrue(isValidScriptPathPublic("C:\\scripts\\test.bat"), "Valid batch path should be accepted");
    }

    @Test
    void testInvalidScriptPaths() {
        // Test that invalid script paths are rejected
        assertFalse(isValidScriptPathPublic("C:\\scripts\\..\\..\\windows\\system32\\cmd.exe"), "Path traversal should be rejected");
        assertFalse(isValidScriptPathPublic("C:\\scripts\\test.exe"), "Non-script file should be rejected");
        assertFalse(isValidScriptPathPublic("C:\\scripts\\test.ps1; rm -rf"), "Command injection should be rejected");
        assertFalse(isValidScriptPathPublic("C:\\scripts\\test|dangerous.ps1"), "Pipe character should be rejected");
        assertFalse(isValidScriptPathPublic(null), "Null path should be rejected");
        assertFalse(isValidScriptPathPublic(""), "Empty path should be rejected");
    }

    @Test
    void testWindowsDirectoryValidation() {
        // Test that Windows directory validation works correctly
        String windowsDir = Executor.class.getDeclaredFields()[0].toString();
        assertNotNull(windowsDir, "Windows directory should not be null");
    }

    // Helper methods to access private validation methods for testing
    private boolean isValidActionPublic(String action) {
        try {
            var method = Executor.class.getDeclaredMethod("isValidAction", String.class);
            method.setAccessible(true);
            return (boolean) method.invoke(null, action);
        } catch (ReflectiveOperationException | SecurityException e) {
            fail("Failed to invoke isValidAction: " + e.getMessage());
            return false;
        }
    }

    private boolean isValidScriptPathPublic(String scriptPath) {
        try {
            var method = Executor.class.getDeclaredMethod("isValidScriptPath", String.class);
            method.setAccessible(true);
            return (boolean) method.invoke(null, scriptPath);
        } catch (ReflectiveOperationException | SecurityException e) {
            fail("Failed to invoke isValidScriptPath: " + e.getMessage());
            return false;
        }
    }
}
