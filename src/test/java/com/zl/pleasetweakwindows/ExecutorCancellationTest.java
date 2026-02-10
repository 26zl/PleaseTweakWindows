package com.zl.pleasetweakwindows;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for Executor cancellation functionality.
 */
class ExecutorCancellationTest {

    @BeforeEach
    void setUp() {
        // Reset any cancellation state before each test
        Executor.resetProcessRunnerFactory();
    }

    @AfterEach
    void tearDown() {
        // Clean up after tests
        Executor.resetProcessRunnerFactory();
    }

    @Test
    void testCancellationRequestedInitiallyFalse() {
        assertFalse(Executor.isCancellationRequested(), 
            "Cancellation should not be requested initially");
    }

    @Test
    void testHasActiveOperationsInitiallyFalse() {
        assertFalse(Executor.hasActiveOperations(), 
            "Should have no active operations initially");
    }

    @Test
    void testCancelAllOperationsReturnsTrue() {
        boolean result = Executor.cancelAllOperations();
        assertTrue(result, "cancelAllOperations should return true");
    }

    @Test
    void testCancellationRequestedAfterCancel() {
        Executor.cancelAllOperations();
        assertTrue(Executor.isCancellationRequested(), 
            "Cancellation should be requested after cancel");
    }

    @Test
    void testCancellationResetsAfterDelay() throws InterruptedException {
        Executor.cancelAllOperations();
        assertTrue(Executor.isCancellationRequested(), 
            "Cancellation should be requested immediately after cancel");
        
        // Wait for the reset (500ms + buffer)
        Thread.sleep(700);
        
        assertFalse(Executor.isCancellationRequested(), 
            "Cancellation should reset after delay");
    }
}
