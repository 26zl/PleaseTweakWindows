package com.zl.pleasetweakwindows;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Verifies that Executor builds the correct command line and passes -Action for consolidated scripts.
 */
class ExecutorCommandBuildTest {

    private final List<List<String>> capturedCommands = new ArrayList<>();
    private Executor executor;

    @BeforeEach
    void setUp() {
        executor = new Executor();
    }

    @AfterEach
    void tearDown() {
        executor.resetProcessRunnerFactory();
        capturedCommands.clear();
        executor.shutdown();
    }

    @Test
    void buildsPowerShellCommandWithActionForConsolidatedScripts() {
        executor.setProcessRunnerFactory(cmd -> new FakeProcessRunner(cmd, capturedCommands));

        CountDownLatch done = new CountDownLatch(1);
        // Use a real existing script path to pass validation, but process start is stubbed.
        String realScriptPath = ResourceExtractor.prepareScriptsPath()
                .resolve("Gaming optimizations")
                .resolve("Gaming-Optimizations.ps1")
                .toString();

        executor.runScript(realScriptPath, null, done::countDown, "nvidia-settings-on");
        try {
            done.await(2, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        assertFalse(capturedCommands.isEmpty(), "Should capture at least one command");
        List<String> command = capturedCommands.get(0);

        assertTrue(command.get(0).toLowerCase().contains("powershell"), "Should invoke PowerShell");
        assertTrue(command.contains("-File"), "Should include -File");
        assertTrue(command.stream().anyMatch(s -> s.toLowerCase().endsWith("gaming-optimizations.ps1")),
                "Should include script path");
        assertTrue(command.contains("-Action"), "Should include -Action for consolidated script");
        assertTrue(command.contains("nvidia-settings-on"), "Should pass the provided action");
    }

    private static class FakeProcessRunner implements ProcessRunner {
        private final Map<String, String> env = new HashMap<>();

        FakeProcessRunner(List<String> command, List<List<String>> capture) {
            capture.add(new ArrayList<>(command));
        }

        @Override
        public Process start() throws IOException {
            return new FakeProcess();
        }

        @Override
        public ProcessRunner redirectErrorStream(boolean redirectErrorStream) {
            return this;
        }

        @Override
        public Map<String, String> environment() {
            return env;
        }

        private static class FakeProcess extends Process {
            private final InputStream empty = new ByteArrayInputStream(new byte[0]);
            private final OutputStream sink = new ByteArrayOutputStream();

            @Override
            public OutputStream getOutputStream() {
                return sink;
            }

            @Override
            public InputStream getInputStream() {
                return empty;
            }

            @Override
            public InputStream getErrorStream() {
                return empty;
            }

            @Override
            public int waitFor() {
                return 0;
            }

            @Override
            public int exitValue() {
                return 0;
            }

            @Override
            public void destroy() {
            }
        }
    }
}
