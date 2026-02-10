package com.zl.pleasetweakwindows;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for the SubTweak class.
 */
class SubTweakTest {

    @Test
    void testToggleSubTweakCreation() {
        SubTweak toggle = new SubTweak("Test Toggle", SubTweak.SubTweakType.TOGGLE,
                "action-on", "action-off", "Test description");
        
        assertEquals("Test Toggle", toggle.getName());
        assertEquals(SubTweak.SubTweakType.TOGGLE, toggle.getType());
        assertEquals("action-on", toggle.getApplyAction());
        assertEquals("action-off", toggle.getRevertAction());
        assertEquals("Test description", toggle.getDescription());
    }

    @Test
    void testButtonSubTweakCreation() {
        SubTweak button = new SubTweak("Test Button", "button-action", "Button description");
        
        assertEquals("Test Button", button.getName());
        assertEquals(SubTweak.SubTweakType.BUTTON, button.getType());
        assertEquals("button-action", button.getApplyAction());
        assertNull(button.getRevertAction());
        assertEquals("Button description", button.getDescription());
    }

    @Test
    void testToggleSubTweakTypeIsToggle() {
        SubTweak toggle = new SubTweak("Toggle", SubTweak.SubTweakType.TOGGLE,
                "on", "off", "desc");
        
        assertEquals(SubTweak.SubTweakType.TOGGLE, toggle.getType());
    }

    @Test
    void testButtonSubTweakTypeIsButton() {
        SubTweak button = new SubTweak("Button", "action", "desc");
        
        assertEquals(SubTweak.SubTweakType.BUTTON, button.getType());
    }

    @Test
    void testSubTweakWithNullDescription() {
        SubTweak button = new SubTweak("Button", "action", null);
        
        assertNull(button.getDescription());
    }
}
