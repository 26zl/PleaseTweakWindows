package com.zl.pleasetweakwindows;

import org.junit.jupiter.api.Test;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;

import static org.junit.jupiter.api.Assertions.*;

class RestorePointGuardTest {

    @Test
    void decisionStartsAsUnknown() throws Exception {
        Field decisionField = RestorePointGuard.class.getDeclaredField("decision");
        decisionField.setAccessible(true);
        Object value = decisionField.get(null);
        assertEquals("UNKNOWN", value.toString(),
                "Initial decision should be UNKNOWN");
    }

    @Test
    void markCreatedSetsDecisionToCreated() throws Exception {
        Field decisionField = RestorePointGuard.class.getDeclaredField("decision");
        decisionField.setAccessible(true);

        // Reset to UNKNOWN before test
        Class<?> decisionEnum = Class.forName(
                "com.zl.pleasetweakwindows.RestorePointGuard$Decision");
        Object unknown = Enum.valueOf((Class<Enum>) decisionEnum, "UNKNOWN");
        decisionField.set(null, unknown);

        RestorePointGuard.markCreated();

        Object value = decisionField.get(null);
        assertEquals("CREATED", value.toString(),
                "After markCreated(), decision should be CREATED");

        // Reset back to UNKNOWN to avoid affecting other tests
        decisionField.set(null, unknown);
    }

    @Test
    void decisionFieldIsVolatile() throws Exception {
        Field decisionField = RestorePointGuard.class.getDeclaredField("decision");
        assertTrue(Modifier.isVolatile(decisionField.getModifiers()),
                "decision field should be volatile for thread safety");
    }
}
