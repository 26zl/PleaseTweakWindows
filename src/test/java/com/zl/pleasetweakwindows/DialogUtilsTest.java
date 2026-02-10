package com.zl.pleasetweakwindows;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for the DialogUtils class.
 * Tests confirmation dialog categorization logic.
 */
class DialogUtilsTest {

    @Test
    void testDestructiveActionsRequireConfirmation() {
        // These actions should require confirmation
        assertTrue(DialogUtils.requiresConfirmation("bloatware-remove"), 
            "bloatware-remove should require confirmation");
        assertTrue(DialogUtils.requiresConfirmation("services-disable"), 
            "services-disable should require confirmation");
        assertTrue(DialogUtils.requiresConfirmation("driver-clean"), 
            "driver-clean should require confirmation");
        assertTrue(DialogUtils.requiresConfirmation("cleanup-run"), 
            "cleanup-run should require confirmation");
        assertTrue(DialogUtils.requiresConfirmation("registry-apply"), 
            "registry-apply should require confirmation");
        assertTrue(DialogUtils.requiresConfirmation("tls-hardening"), 
            "tls-hardening should require confirmation");
    }

    @Test
    void testNonDestructiveActionsDoNotRequireConfirmation() {
        // These actions should NOT require confirmation
        assertFalse(DialogUtils.requiresConfirmation("power-plan-on"), 
            "power-plan-on should not require confirmation");
        assertFalse(DialogUtils.requiresConfirmation("dns-cloudflare"), 
            "dns-cloudflare should not require confirmation");
        assertFalse(DialogUtils.requiresConfirmation("widgets-disable"), 
            "widgets-disable should not require confirmation");
        assertFalse(DialogUtils.requiresConfirmation("nvidia-settings-on"), 
            "nvidia-settings-on should not require confirmation");
    }

    @Test
    void testNullAndEmptyActionsDoNotRequireConfirmation() {
        assertFalse(DialogUtils.requiresConfirmation(null), 
            "null action should not require confirmation");
        assertFalse(DialogUtils.requiresConfirmation(""), 
            "empty action should not require confirmation");
    }

    @Test
    void testHighRiskActions() {
        // These are high-risk actions
        assertTrue(DialogUtils.isHighRisk("services-disable"), 
            "services-disable should be high-risk");
        assertTrue(DialogUtils.isHighRisk("driver-clean"), 
            "driver-clean should be high-risk");
        assertTrue(DialogUtils.isHighRisk("tls-hardening"), 
            "tls-hardening should be high-risk");
    }

    @Test
    void testNonHighRiskActions() {
        // These are destructive but not high-risk
        assertFalse(DialogUtils.isHighRisk("bloatware-remove"), 
            "bloatware-remove should not be high-risk");
        assertFalse(DialogUtils.isHighRisk("cleanup-run"), 
            "cleanup-run should not be high-risk");
        assertFalse(DialogUtils.isHighRisk("registry-apply"), 
            "registry-apply should not be high-risk");
        
        // Non-destructive actions
        assertFalse(DialogUtils.isHighRisk("power-plan-on"), 
            "power-plan-on should not be high-risk");
        assertFalse(DialogUtils.isHighRisk(null), 
            "null action should not be high-risk");
    }
}
