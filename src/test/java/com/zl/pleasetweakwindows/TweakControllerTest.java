package com.zl.pleasetweakwindows;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;

/**
 * Unit tests for the TweakController class.
 */
class TweakControllerTest {

    @Test
    void testInitiallyEmpty() {
        TweakController controller = new TweakController();
        assertTrue(controller.getTweaks().isEmpty(), "Controller should start empty");
    }

    @Test
    void testAddTweak() {
        TweakController controller = new TweakController();
        Tweak tweak = new Tweak("Test Tweak", "test.ps1", "test-revert.ps1");
        controller.addTweak(tweak);

        List<Tweak> tweaks = controller.getTweaks();
        assertEquals(1, tweaks.size(), "Should have one tweak");
        assertEquals("Test Tweak", tweaks.get(0).getTitle(), "Tweak title should match");
    }

    @Test
    void testLoadTweaks() {
        TweakController controller = new TweakController();
        controller.loadTweaks();

        List<Tweak> tweaks = controller.getTweaks();
        assertEquals(6, tweaks.size(), "Should load 6 default tweaks (including Privacy and Security)");

        // Verify all expected tweaks are loaded
        boolean hasGaming = tweaks.stream().anyMatch(t -> t.getTitle().contains("Gaming"));
        boolean hasNetwork = tweaks.stream().anyMatch(t -> t.getTitle().contains("Network"));
        boolean hasGeneral = tweaks.stream().anyMatch(t -> t.getTitle().contains("General"));
        boolean hasServices = tweaks.stream().anyMatch(t -> t.getTitle().contains("Services"));
        boolean hasPrivacy = tweaks.stream().anyMatch(t -> t.getTitle().contains("Privacy"));
        boolean hasSecurity = tweaks.stream().anyMatch(t -> t.getTitle().contains("Security"));

        assertTrue(hasGaming, "Should have Gaming Optimizations");
        assertTrue(hasNetwork, "Should have Network Optimizations");
        assertTrue(hasGeneral, "Should have General Tweaks");
        assertTrue(hasServices, "Should have Services Management");
        assertTrue(hasPrivacy, "Should have Privacy");
        assertTrue(hasSecurity, "Should have Security");
    }

    @Test
    void testMultipleAddTweaks() {
        TweakController controller = new TweakController();
        controller.addTweak(new Tweak("Tweak 1", "test1.ps1", "revert1.ps1"));
        controller.addTweak(new Tweak("Tweak 2", "test2.ps1", "revert2.ps1"));
        controller.addTweak(new Tweak("Tweak 3", "test3.ps1", "revert3.ps1"));

        assertEquals(3, controller.getTweaks().size(), "Should have 3 tweaks");
    }
}
