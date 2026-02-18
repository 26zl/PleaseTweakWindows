package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

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
    @SuppressWarnings("unused")
    void setUp() {
        executor = new Executor();
    }

    @AfterEach
    @SuppressWarnings("unused")
    void tearDown() {
        executor.shutdown();
    }

    @Test
    void successfulScriptFiresCallbackWithZeroExitCode(@TempDir Path tempDir) throws IOException, InterruptedException {
        Path script = tempDir.resolve("success.ps1");
        Files.writeString(script, "Write-Output 'Hello from test'\nexit 0\n");

        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean callbackFired = new AtomicBoolean(false);
        AtomicInteger receivedExitCode = new AtomicInteger(-999);

        executor.runScript(script.toString(), null, (exitCode) -> {
            receivedExitCode.set(exitCode);
            callbackFired.set(true);
            latch.countDown();
        }, null);

        assertTrue(latch.await(10, TimeUnit.SECONDS), "Callback should fire within timeout");
        assertTrue(callbackFired.get(), "Callback should have been invoked");
        assertEquals(0, receivedExitCode.get(), "Successful script should report exit code 0");
    }

    @Test
    void failingScriptFiresCallbackWithNonZeroExitCode(@TempDir Path tempDir) throws IOException, InterruptedException {
        Path script = tempDir.resolve("failure.ps1");
        Files.writeString(script, "Write-Output 'About to fail'\nexit 1\n");

        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean callbackFired = new AtomicBoolean(false);
        AtomicInteger receivedExitCode = new AtomicInteger(-999);

        executor.runScript(script.toString(), null, (exitCode) -> {
            receivedExitCode.set(exitCode);
            callbackFired.set(true);
            latch.countDown();
        }, null);

        assertTrue(latch.await(10, TimeUnit.SECONDS), "Callback should fire even on failure");
        assertTrue(callbackFired.get(), "Callback should have been invoked on failure");
        assertEquals(1, receivedExitCode.get(), "Failing script should report exit code 1");
    }

    @Test
    void noActiveOperationsAfterCompletion(@TempDir Path tempDir) throws IOException, InterruptedException {
        Path script = tempDir.resolve("quick.ps1");
        Files.writeString(script, "exit 0\n");

        CountDownLatch latch = new CountDownLatch(1);
        executor.runScript(script.toString(), null, (exitCode) -> latch.countDown(), null);

        assertTrue(latch.await(10, TimeUnit.SECONDS), "Script should complete within timeout");
        // Small delay to let futures clean up
        Thread.sleep(100);
        assertFalse(executor.hasActiveOperations(), "No active operations after completion");
    }
}
