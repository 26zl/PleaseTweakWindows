package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledOnOs;
import org.junit.jupiter.api.condition.OS;
import org.junit.jupiter.api.io.TempDir;

/**
 * Integration tests that run real PowerShell scripts via Executor.
 */
@EnabledOnOs(OS.WINDOWS)
class ExecutorIntegrationTest {

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
    void successfulScriptFiresCallback(@TempDir Path tempDir) throws IOException, InterruptedException {
        Path script = tempDir.resolve("success.ps1");
        Files.writeString(script, "Write-Output 'Hello from test'\nexit 0\n");

        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean callbackFired = new AtomicBoolean(false);

        executor.runScript(script.toString(), null, () -> {
            callbackFired.set(true);
            latch.countDown();
        }, null);

        assertTrue(latch.await(10, TimeUnit.SECONDS), "Callback should fire within timeout");
        assertTrue(callbackFired.get(), "Callback should have been invoked");
    }

    @Test
    void failingScriptStillFiresCallback(@TempDir Path tempDir) throws IOException, InterruptedException {
        Path script = tempDir.resolve("failure.ps1");
        Files.writeString(script, "Write-Output 'About to fail'\nexit 1\n");

        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean callbackFired = new AtomicBoolean(false);

        executor.runScript(script.toString(), null, () -> {
            callbackFired.set(true);
            latch.countDown();
        }, null);

        assertTrue(latch.await(10, TimeUnit.SECONDS), "Callback should fire even on failure");
        assertTrue(callbackFired.get(), "Callback should have been invoked on failure");
    }

    @Test
    void noActiveOperationsAfterCompletion(@TempDir Path tempDir) throws IOException, InterruptedException {
        Path script = tempDir.resolve("quick.ps1");
        Files.writeString(script, "exit 0\n");

        CountDownLatch latch = new CountDownLatch(1);
        executor.runScript(script.toString(), null, latch::countDown, null);

        assertTrue(latch.await(10, TimeUnit.SECONDS), "Script should complete within timeout");
        // Small delay to let futures clean up
        Thread.sleep(100);
        assertFalse(executor.hasActiveOperations(), "No active operations after completion");
    }
}
