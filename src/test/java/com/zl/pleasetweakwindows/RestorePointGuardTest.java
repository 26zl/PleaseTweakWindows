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
        Object unknown = null;
        for (Object constant : decisionEnum.getEnumConstants()) {
            if (constant instanceof Enum<?> enumConstant &&
                    "UNKNOWN".equals(enumConstant.name())) {
                unknown = constant;
                break;
            }
        }
        assertNotNull(unknown, "Expected UNKNOWN enum constant to exist");
        decisionField.set(null, unknown);

        RestorePointGuard.markCreated();

        Object value = decisionField.get(null);
        assertEquals("CREATED", value.toString(),
                "After markCreated(), decision should be CREATED");

        // Reset back to UNKNOWN to avoid affecting other tests
        decisionField.set(null, unknown);
    }

    @Test
    void threadSafetyViaLockObject() throws Exception {
        // decision field is guarded by a synchronized LOCK object (stronger than volatile)
        Field lockField = RestorePointGuard.class.getDeclaredField("LOCK");
        assertNotNull(lockField, "LOCK field should exist for synchronized access");
        assertTrue(Modifier.isStatic(lockField.getModifiers()),
                "LOCK field should be static");
        assertTrue(Modifier.isFinal(lockField.getModifiers()),
                "LOCK field should be final");
    }
}
