package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class UpdateCheckerTest {

    @Test
    void extractJsonFieldFindsTagName() {
        String json = "{\"tag_name\": \"v1.2.3\", \"html_url\": \"https://example.com/release\"}";
        assertEquals("v1.2.3", UpdateChecker.extractJsonField(json, "tag_name"));
    }

    @Test
    void extractJsonFieldFindsHtmlUrl() {
        String json = "{\"tag_name\": \"v1.2.3\", \"html_url\": \"https://example.com/release\"}";
        assertEquals("https://example.com/release", UpdateChecker.extractJsonField(json, "html_url"));
    }

    @Test
    void extractJsonFieldReturnsNullForMissingField() {
        String json = "{\"tag_name\": \"v1.0.0\"}";
        assertNull(UpdateChecker.extractJsonField(json, "html_url"));
    }

    @Test
    void extractJsonFieldHandlesWhitespace() {
        String json = "{ \"tag_name\" : \"v2.0.0\" }";
        assertEquals("v2.0.0", UpdateChecker.extractJsonField(json, "tag_name"));
    }

    @Test
    void isNewerVersionDetectsNewerMajor() {
        assertTrue(UpdateChecker.isNewerVersion("1.0.0", "2.0.0"));
    }

    @Test
    void isNewerVersionDetectsNewerMinor() {
        assertTrue(UpdateChecker.isNewerVersion("1.0.0", "1.1.0"));
    }

    @Test
    void isNewerVersionDetectsNewerPatch() {
        assertTrue(UpdateChecker.isNewerVersion("1.0.0", "1.0.1"));
    }

    @Test
    void isNewerVersionReturnsFalseForSameVersion() {
        assertFalse(UpdateChecker.isNewerVersion("1.0.0", "1.0.0"));
    }

    @Test
    void isNewerVersionReturnsFalseForOlderVersion() {
        assertFalse(UpdateChecker.isNewerVersion("2.0.0", "1.9.9"));
    }

    @Test
    void isNewerVersionHandlesPartialVersions() {
        assertTrue(UpdateChecker.isNewerVersion("1.0", "1.1"));
        assertTrue(UpdateChecker.isNewerVersion("1", "2"));
    }
}
