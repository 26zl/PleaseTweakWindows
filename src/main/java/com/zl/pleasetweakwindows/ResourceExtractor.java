package com.zl.pleasetweakwindows;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.FileSystem;
import java.nio.file.FileSystemAlreadyExistsException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Stream;

/**
 * Copies packaged script resources to a temporary directory so they can be executed
 * regardless of the current working directory or packaging format (jar/native image).
 */
public final class ResourceExtractor {
    private static final AtomicReference<Path> scriptsDirectory = new AtomicReference<>();

    private ResourceExtractor() {
    }

    public static Path prepareScriptsPath() {
        Path existing = scriptsDirectory.get();
        if (existing != null) {
            return existing;
        }

        try {
            Path tempDir = Files.createTempDirectory("pleasetweakwindows-scripts");
            copyScripts(tempDir);
            scriptsDirectory.compareAndSet(null, tempDir);
            return scriptsDirectory.get();
        } catch (IOException | URISyntaxException e) {
            throw new IllegalStateException("Failed to prepare scripts directory", e);
        }
    }

    private static void copyScripts(Path targetDir) throws IOException, URISyntaxException {
        URL scriptsUrl = ResourceExtractor.class.getResource("/scripts");
        if (scriptsUrl == null) {
            throw new IOException("Scripts resource not found on classpath.");
        }

        URI scriptsUri = scriptsUrl.toURI();
        String scheme = scriptsUri.getScheme();
        if ("jar".equalsIgnoreCase(scheme)) {
            copyFromJar(scriptsUri, targetDir);
            return;
        }

        if ("file".equalsIgnoreCase(scheme)) {
            Path scriptsPath = Paths.get(scriptsUri);
            copyDirectory(scriptsPath, targetDir);
            return;
        }

        // Fallback for runtime environments without a real filesystem (e.g., GraalVM native image).
        copyFromIndex(targetDir);
    }

    private static void copyFromJar(URI scriptsUri, Path targetDir) throws IOException {
        // Strip the !/scripts suffix to get the jar location
        String uriString = scriptsUri.toString();
        int separatorIndex = uriString.indexOf("!/");
        URI jarUri = separatorIndex > 0 ? URI.create(uriString.substring(0, separatorIndex)) : scriptsUri;

        FileSystem fileSystem;
        try {
            fileSystem = FileSystems.newFileSystem(jarUri, Map.of());
        } catch (FileSystemAlreadyExistsException e) {
            fileSystem = FileSystems.getFileSystem(jarUri);
        }

        Path scriptsPath = fileSystem.getPath("scripts");
        copyDirectory(scriptsPath, targetDir);
    }

    private static void copyFromIndex(Path targetDir) throws IOException {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                ResourceExtractor.class.getResourceAsStream("/scripts/index.txt")))) {
            reader.lines().forEach(relativePath -> copySingleResource(relativePath, targetDir));
        }
    }

    private static void copySingleResource(String relativePath, Path targetDir) {
        if (relativePath == null || relativePath.isBlank()) {
            return;
        }
        try {
            Path destination = targetDir.resolve(relativePath);
            Path parent = destination.getParent();
            if (parent != null) {
                Files.createDirectories(parent);
            }
            try (var in = ResourceExtractor.class.getResourceAsStream("/scripts/" + relativePath)) {
                if (in == null) {
                    throw new IOException("Missing resource: /scripts/" + relativePath);
                }
                Files.copy(in, destination, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            throw new RuntimeException("Failed to copy resource: " + relativePath, e);
        }
    }

    private static void copyDirectory(Path sourceDir, Path targetDir) throws IOException {
        try (Stream<Path> paths = Files.walk(sourceDir)) {
            paths.forEach(path -> {
                try {
                    Path relative = sourceDir.relativize(path);
                    Path destination = targetDir.resolve(relative.toString());
                    if (Files.isDirectory(path)) {
                        Files.createDirectories(destination);
                    } else {
                        Path parent = destination.getParent();
                        if (parent != null) {
                            Files.createDirectories(parent);
                        }
                        Files.copy(path, destination, StandardCopyOption.REPLACE_EXISTING);
                    }
                } catch (IOException e) {
                    throw new RuntimeException("Failed to copy resource: " + path, e);
                }
            });
        }
    }
}
