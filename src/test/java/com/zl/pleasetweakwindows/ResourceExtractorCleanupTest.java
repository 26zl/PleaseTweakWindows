package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;

/**
 * Verifies ResourceExtractor idempotency: repeated calls return the same directory.
 */
class ResourceExtractorCleanupTest {

    @Test
    void prepareScriptsPathIsIdempotent() {
        Path first = ResourceExtractor.prepareScriptsPath();
        assertNotNull(first, "First call should return a non-null path");
        assertTrue(Files.isDirectory(first), "Should return an existing directory");

        Path second = ResourceExtractor.prepareScriptsPath();
        assertEquals(first, second, "Repeated calls should return the same directory");
    }
}
