package com.zl.pleasetweakwindows;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Button;
import javafx.scene.control.Hyperlink;
import javafx.scene.control.Label;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.Region;
import javafx.scene.layout.VBox;

public class UpdateChecker {

    static final String CURRENT_VERSION = loadVersion();
    private static final String RELEASES_API = "https://api.github.com/repos/26zl/PleaseTweakWindows/releases/latest";
    private static final Logger LOGGER = LoggerFactory.getLogger(UpdateChecker.class);
    private final VBox topContainer;

    private static String loadVersion() {
        try {
            Properties props = new Properties();
            try (var in = UpdateChecker.class.getResourceAsStream("/META-INF/maven/com.zl/PleaseTweakWindows/pom.properties")) {
                if (in != null) {
                    props.load(in);
                    String version = props.getProperty("version");
                    if (version != null && !version.isBlank()) {
                        return version;
                    }
                }
            }
        } catch (Exception ignored) {
            // fall through to default
        }
        return "1.0.0";
    }

    public UpdateChecker(VBox topContainer) {
        this.topContainer = topContainer;
    }

    public void checkAsync() {
        Thread thread = new Thread(() -> {
            try (HttpClient client = HttpClient.newBuilder()
                        .connectTimeout(Duration.ofSeconds(5))
                        .followRedirects(HttpClient.Redirect.NORMAL)
                        .build()) {

                HttpRequest request = HttpRequest.newBuilder()
                        .uri(URI.create(RELEASES_API))
                        .timeout(Duration.ofSeconds(10))
                        .header("Accept", "application/vnd.github.v3+json")
                        .GET()
                        .build();

                HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
                if (response.statusCode() != 200) {
                    LOGGER.debug("Update check returned status {}", response.statusCode());
                    return;
                }

                String body = response.body();
                String tagName = extractJsonField(body, "tag_name");
                String htmlUrl = extractJsonField(body, "html_url");

                if (tagName == null || htmlUrl == null) {
                    LOGGER.debug("Could not parse release info from GitHub API response");
                    return;
                }

                String remoteVersion = tagName.startsWith("v") ? tagName.substring(1) : tagName;

                if (!isNewerVersion(CURRENT_VERSION, remoteVersion)) {
                    LOGGER.debug("Current version {} is up to date (remote: {})", CURRENT_VERSION, remoteVersion);
                    return;
                }

                if (isDismissed(remoteVersion)) {
                    LOGGER.debug("Version {} was previously dismissed", remoteVersion);
                    return;
                }

                Platform.runLater(() -> showUpdateBar(remoteVersion, htmlUrl));
            } catch (IOException | InterruptedException e) {
                LOGGER.debug("Update check failed: {}", e.getMessage());
                if (e instanceof InterruptedException) {
                    Thread.currentThread().interrupt();
                }
            }
        });
        thread.setDaemon(true);
        thread.setName("ptw-update-checker");
        thread.start();
    }

    static String extractJsonField(String json, String field) {
        Pattern pattern = Pattern.compile("\"" + Pattern.quote(field) + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"");
        Matcher matcher = pattern.matcher(json);
        if (matcher.find()) {
            return matcher.group(1).replace("\\\"", "\"").replace("\\\\", "\\");
        }
        return null;
    }

    static boolean isNewerVersion(String current, String remote) {
        int[] cur = parseVersion(current);
        int[] rem = parseVersion(remote);
        for (int i = 0; i < 3; i++) {
            if (rem[i] > cur[i]) return true;
            if (rem[i] < cur[i]) return false;
        }
        return false;
    }

    private static int[] parseVersion(String version) {
        int[] parts = {0, 0, 0};
        String[] split = version.split("\\.");
        for (int i = 0; i < Math.min(split.length, 3); i++) {
            try {
                parts[i] = Integer.parseInt(split[i]);
            } catch (NumberFormatException ignored) {
                // keep 0
            }
        }
        return parts;
    }

    private void showUpdateBar(String version, String url) {
        HBox bar = new HBox(10);
        bar.setAlignment(Pos.CENTER_LEFT);
        bar.setPadding(new Insets(6, 12, 6, 12));
        bar.setStyle("-fx-background-color: #2a4d2a; -fx-border-color: #3d6b3d; -fx-border-width: 0 0 1 0;");

        Label icon = new Label("\u2b06");
        icon.setStyle("-fx-text-fill: #90ee90; -fx-font-size: 14px;");

        Label text = new Label("Version " + version + " is available!");
        text.setStyle("-fx-text-fill: #d0ffd0; -fx-font-size: 13px;");

        Hyperlink download = new Hyperlink("Download");
        download.setStyle("-fx-text-fill: #90ee90; -fx-font-size: 13px; -fx-underline: true;");
        download.setOnAction(e -> openBrowser(url));

        Region spacer = new Region();
        HBox.setHgrow(spacer, Priority.ALWAYS);

        Button dismiss = new Button("X");
        dismiss.setStyle("-fx-background-color: transparent; -fx-text-fill: #90ee90; -fx-font-size: 12px; -fx-cursor: hand;");
        dismiss.setOnAction(e -> {
            topContainer.getChildren().remove(bar);
            saveDismissed(version);
        });

        bar.getChildren().addAll(icon, text, download, spacer, dismiss);
        topContainer.getChildren().add(0, bar);
    }

    private void openBrowser(String url) {
        try {
            URI uri = URI.create(url);
            String scheme = uri.getScheme();
            if (!"https".equalsIgnoreCase(scheme) && !"http".equalsIgnoreCase(scheme)) {
                LOGGER.warn("Refused to open non-HTTP URL: {}", url);
                return;
            }
            Process process = new ProcessBuilder("cmd", "/c", "start", "", url.replace("&", "^&")).start();
            process.getInputStream().close();
            process.getErrorStream().close();
            process.getOutputStream().close();
        } catch (IllegalArgumentException e) {
            LOGGER.warn("Invalid URL: {}", url);
        } catch (IOException e) {
            LOGGER.warn("Failed to open browser: {}", e.getMessage());
        }
    }

    private Path getPrefsPath() {
        return Paths.get(System.getProperty("user.dir"), "ptw-update-prefs.properties");
    }

    private boolean isDismissed(String version) {
        Path prefs = getPrefsPath();
        if (!Files.exists(prefs)) return false;
        try {
            Properties props = new Properties();
            try (var in = Files.newInputStream(prefs)) {
                props.load(in);
            }
            return version.equals(props.getProperty("dismissed_version"));
        } catch (IOException e) {
            return false;
        }
    }

    private void saveDismissed(String version) {
        try {
            Properties props = new Properties();
            props.setProperty("dismissed_version", version);
            try (var out = Files.newOutputStream(getPrefsPath())) {
                props.store(out, "PleaseTweakWindows update preferences");
            }
        } catch (IOException e) {
            LOGGER.debug("Failed to save update preferences: {}", e.getMessage());
        }
    }
}
