package com.zl.pleasetweakwindows;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for Executor cancellation functionality.
 */
class ExecutorCancellationTest {

    private Executor executor;

    @BeforeEach
    void setUp() {
        executor = new Executor();
    }

    @AfterEach
    void tearDown() {
        executor.shutdown();
    }

    @Test
    void testCancellationRequestedInitiallyFalse() {
        assertFalse(executor.isCancellationRequested(),
            "Cancellation should not be requested initially");
    }

    @Test
    void testHasActiveOperationsInitiallyFalse() {
        assertFalse(executor.hasActiveOperations(),
            "Should have no active operations initially");
    }

    @Test
    void testCancellationRequestedAfterCancel() {
        executor.cancelAllOperations();
        assertTrue(executor.isCancellationRequested(),
            "Cancellation should be requested after cancel");
    }

    @Test
    void testCancellationResetsAfterDelay() throws InterruptedException {
        executor.cancelAllOperations();
        assertTrue(executor.isCancellationRequested(),
            "Cancellation should be requested immediately after cancel");

        // Wait for the reset (500ms + buffer)
        Thread.sleep(700);

        assertFalse(executor.isCancellationRequested(),
            "Cancellation should reset after delay");
    }
}
