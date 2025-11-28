package com.zl.pleasetweakwindows;

import java.util.regex.Pattern;

/**
 * Utility class for validation operations used across the application.
 * Provides centralized validation logic to ensure consistency and prevent code duplication.
 */
public final class ValidationUtils {

    private static final Pattern VALID_SCRIPT_PATH_PATTERN = Pattern.compile("^[a-zA-Z0-9_\\-./\\s\\\\]+\\.(ps1|bat)$");

    // Private constructor to prevent instantiation
    private ValidationUtils() {
        throw new AssertionError("ValidationUtils is a utility class and should not be instantiated");
    }

    /**
     * Validates that a script path is safe and follows expected naming conventions.
     * This prevents path traversal attacks and ensures only .ps1 or .bat files are processed.
     *
     * @param scriptPath the path to validate
     * @return true if the path is valid and safe, false otherwise
     */
    public static boolean isValidScriptPath(String scriptPath) {
        if (scriptPath == null || scriptPath.trim().isEmpty()) {
            return false;
        }
            else if (scriptPath.contains("..")) {
            return false;
        }

        // Validate against allowed pattern
        return VALID_SCRIPT_PATH_PATTERN.matcher(scriptPath).matches();
    }
}
