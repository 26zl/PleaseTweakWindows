package com.zl.pleasetweakwindows;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;

/**
 * Unit tests for the Tweak class.
 */
class TweakTest {

    @Test
    void testTweakCreation() {
        Tweak tweak = new Tweak("Gaming Optimizations", "gaming.ps1", "revert-gaming.ps1");
        
        assertEquals("Gaming Optimizations", tweak.getTitle());
        assertEquals("gaming.ps1", tweak.getApplyScript());
        assertEquals("revert-gaming.ps1", tweak.getRevertScript());
    }

    @Test
    void testTweakStartsWithNoSubTweaks() {
        Tweak tweak = new Tweak("Test", "test.ps1", "revert.ps1");
        
        List<SubTweak> subTweaks = tweak.getSubTweaks();
        assertNotNull(subTweaks);
        assertTrue(subTweaks.isEmpty());
    }

    @Test
    void testAddSubTweak() {
        Tweak tweak = new Tweak("Test", "test.ps1", "revert.ps1");
        SubTweak subTweak = new SubTweak("Sub Test", "action", "description");
        
        tweak.addSubTweak(subTweak);
        
        List<SubTweak> subTweaks = tweak.getSubTweaks();
        assertEquals(1, subTweaks.size());
        assertEquals("Sub Test", subTweaks.get(0).getName());
    }

    @Test
    void testAddMultipleSubTweaks() {
        Tweak tweak = new Tweak("Test", "test.ps1", "revert.ps1");
        
        tweak.addSubTweak(new SubTweak("Sub 1", "action1", "desc1"));
        tweak.addSubTweak(new SubTweak("Sub 2", "action2", "desc2"));
        tweak.addSubTweak(new SubTweak("Sub 3", "action3", "desc3"));
        
        assertEquals(3, tweak.getSubTweaks().size());
    }

    @Test
    void testTweakWithToggleAndButtonSubTweaks() {
        Tweak tweak = new Tweak("Mixed", "mixed.ps1", "revert-mixed.ps1");
        
        // Add toggle sub-tweak
        tweak.addSubTweak(new SubTweak("Toggle Feature", SubTweak.SubTweakType.TOGGLE,
                "toggle-on", "toggle-off", "Toggle description"));
        
        // Add button sub-tweak
        tweak.addSubTweak(new SubTweak("Button Action", "button-action", "Button description"));
        
        List<SubTweak> subTweaks = tweak.getSubTweaks();
        assertEquals(2, subTweaks.size());
        assertEquals(SubTweak.SubTweakType.TOGGLE, subTweaks.get(0).getType());
        assertEquals(SubTweak.SubTweakType.BUTTON, subTweaks.get(1).getType());
    }

    @Test
    void testTweakTitleNotNull() {
        Tweak tweak = new Tweak("Title", "script.ps1", "revert.ps1");
        assertNotNull(tweak.getTitle());
    }

    @Test
    void testTweakApplyScriptNotNull() {
        Tweak tweak = new Tweak("Title", "script.ps1", "revert.ps1");
        assertNotNull(tweak.getApplyScript());
    }
}
