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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class ResourceExtractor {
    // Thread-safe singleton: scripts are extracted once per session
    private static final AtomicReference<Path> scriptsDirectory = new AtomicReference<>();
    private static final Logger LOGGER = LoggerFactory.getLogger(ResourceExtractor.class);

    private ResourceExtractor() {
    }

    // Clean up extracted temp scripts on JVM shutdown
    static {
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            Path dir = scriptsDirectory.get();
            if (dir != null) {
                try {
                    deleteDirectory(dir);
                } catch (IOException e) {
                    LOGGER.warn("Failed to cleanup temp directory: {}", dir, e);
                }
            }
        }));
    }

    public static synchronized Path prepareScriptsPath() {
        Path existing = scriptsDirectory.get();
        if (existing != null) {
            return existing;
        }

        try {
            Path tempDir = Files.createTempDirectory("pleasetweakwindows-scripts");
            copyScripts(tempDir);
            scriptsDirectory.set(tempDir);
            return tempDir;
        } catch (IOException | URISyntaxException e) {
            LOGGER.error("Failed to prepare scripts directory.", e);
            throw new IllegalStateException("Failed to prepare scripts directory", e);
        }
    }

    private static void deleteDirectory(Path directory) throws IOException {
        if (!Files.exists(directory)) {
            return;
        }

        try (Stream<Path> paths = Files.walk(directory)) {
            paths.sorted((a, b) -> b.compareTo(a)) 
                 .forEach(path -> {
                     try {
                         Files.deleteIfExists(path);
                     } catch (IOException e) {
                         LOGGER.debug("Failed to delete temp file: {}", path, e);
                     }
                 });
        }
    }

    private static void copyScripts(Path targetDir) throws IOException, URISyntaxException {
        URL scriptsUrl = ResourceExtractor.class.getResource("/scripts");
        if (scriptsUrl == null) {
            LOGGER.error("Scripts resource not found on classpath.");
            throw new IOException("Scripts resource not found on classpath.");
        }

        URI scriptsUri = scriptsUrl.toURI();
        // jar = running from .jar, file = IDE/dev, fallback = GraalVM native image
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
        // Native image: use index.txt manifest to locate resources
        copyFromIndex(targetDir);
    }

    private static void copyFromJar(URI scriptsUri, Path targetDir) throws IOException {
        String uriString = scriptsUri.toString();
        int separatorIndex = uriString.indexOf("!/");
        URI jarUri = separatorIndex > 0 ? URI.create(uriString.substring(0, separatorIndex)) : scriptsUri;

        FileSystem fileSystem;
        boolean ownedFileSystem = false;
        try {
            fileSystem = FileSystems.newFileSystem(jarUri, Map.of());
            ownedFileSystem = true;
        } catch (FileSystemAlreadyExistsException e) {
            fileSystem = FileSystems.getFileSystem(jarUri);
        }

        try {
            Path scriptsPath = fileSystem.getPath("scripts");
            copyDirectory(scriptsPath, targetDir);
        } finally {
            if (ownedFileSystem) {
                fileSystem.close();
            }
        }
    }

    private static void copyFromIndex(Path targetDir) throws IOException {
        var stream = ResourceExtractor.class.getResourceAsStream("/scripts/index.txt");
        if (stream == null) {
            throw new IOException("Script manifest not found: /scripts/index.txt");
        }
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream))) {
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
                    LOGGER.error("Missing resource: /scripts/{}", relativePath);
                    throw new IOException("Missing resource: /scripts/" + relativePath);
                }
                Files.copy(in, destination, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            LOGGER.error("Failed to copy resource: {}", relativePath, e);
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
                    LOGGER.error("Failed to copy resource: {}", path, e);
                    throw new RuntimeException("Failed to copy resource: " + path, e);
                }
            });
        }
    }
}
