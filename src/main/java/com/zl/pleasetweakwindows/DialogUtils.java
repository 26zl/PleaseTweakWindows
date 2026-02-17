package com.zl.pleasetweakwindows;

import java.util.Optional;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;
import javafx.scene.control.ButtonBar.ButtonData;
import javafx.scene.control.ButtonType;
import javafx.stage.Stage;
import javafx.stage.StageStyle;

public class DialogUtils {

    private static final Logger LOGGER = LoggerFactory.getLogger(DialogUtils.class);

    // Actions that show a confirmation dialog before executing
    private static final Set<String> DESTRUCTIVE_ACTIONS = Set.of(
        "bloatware-remove",
        "services-disable",
        "driver-clean",
        "cleanup-run",
        "registry-apply",
        "tls-hardening",
        "firewall-hardening",
        "smart-optimize-aggressive",
        "ui-online-content-disable",
        "ui-secure-recent-docs",
        "ui-remove-this-pc-folders",
        "ui-lock-screen-notifications-disable",
        "ui-store-open-with-disable",
        "ui-quick-access-recent-disable",
        "ui-sync-provider-notifications-disable",
        "ui-hibernation-disable",
        "ui-camera-osd-enable",
        "copilot-disable",
        "security-improve-network",
        "security-clipboard-data-disable",
        "security-spectre-meltdown-enable",
        "security-dep-enable",
        "security-autorun-disable",
        "security-lock-screen-camera-disable",
        "security-lm-hash-disable",
        "security-always-install-elevated-disable",
        "security-sehop-enable",
        "security-ps2-downgrade-protection-enable",
        "security-wcn-disable"
    );

    // Subset with stronger warning text
    private static final Set<String> HIGH_RISK_ACTIONS = Set.of(
        "services-disable",
        "driver-clean",
        "tls-hardening"
    );

    public static boolean requiresConfirmation(String action) {
        return action != null && DESTRUCTIVE_ACTIONS.contains(action);
    }

    public static boolean isHighRisk(String action) {
        return action != null && HIGH_RISK_ACTIONS.contains(action);
    }

    public static boolean showConfirmation(String action, String actionName, Stage owner) {
        String title = isHighRisk(action) ? "High-Risk Operation" : "Confirm Action";
        String header = isHighRisk(action) 
            ? "This operation may cause system instability!"
            : "Are you sure you want to proceed?";
        
        String content = getActionWarning(action, actionName);
        
        Alert alert = new Alert(AlertType.CONFIRMATION);
        if (owner != null) {
            alert.initOwner(owner);
        }
        alert.initStyle(StageStyle.UTILITY);
        alert.setTitle(title);
        alert.setHeaderText(header);
        alert.setContentText(content);

        ButtonType yesButton = new ButtonType("Yes, Proceed", ButtonData.OK_DONE);
        ButtonType noButton = new ButtonType("Cancel", ButtonData.CANCEL_CLOSE);
        alert.getButtonTypes().setAll(yesButton, noButton);

        Optional<ButtonType> result = alert.showAndWait();
        boolean confirmed = result.isPresent() && result.get() == yesButton;
        LOGGER.info("Confirmation dialog for '{}': {}", action, confirmed ? "confirmed" : "cancelled");
        return confirmed;
    }

    public enum RestorePointDecision {
        CREATE,
        SKIP,
        CANCEL
    }

    public static RestorePointDecision showRestorePointPrompt(Stage owner) {
        Alert alert = new Alert(AlertType.WARNING);
        if (owner != null) {
            alert.initOwner(owner);
        }
        alert.initStyle(StageStyle.UTILITY);
        alert.setTitle("Restore Point Required");
        alert.setHeaderText("Create a restore point before making changes?");
        alert.setContentText("""
            Best practice: create a restore point before applying tweaks.

            You can continue without one, but you may not be able to fully undo changes.""");

        ButtonType createButton = new ButtonType("Create Restore Point", ButtonData.OK_DONE);
        ButtonType continueButton = new ButtonType("Continue Without", ButtonData.NO);
        ButtonType cancelButton = new ButtonType("Cancel", ButtonData.CANCEL_CLOSE);
        alert.getButtonTypes().setAll(createButton, continueButton, cancelButton);

        Optional<ButtonType> result = alert.showAndWait();
        if (result.isEmpty() || result.get() == cancelButton) {
            return RestorePointDecision.CANCEL;
        }
        if (result.get() == createButton) {
            return RestorePointDecision.CREATE;
        }
        return RestorePointDecision.SKIP;
    }

    public static boolean showCancelConfirmation(Stage owner) {
        Alert alert = new Alert(AlertType.WARNING);
        if (owner != null) {
            alert.initOwner(owner);
        }
        alert.initStyle(StageStyle.UTILITY);
        alert.setTitle("Cancel Operation");
        alert.setHeaderText("Cancel running operation?");
        alert.setContentText("""
            This will forcibly terminate the running script. \
            The system may be left in an inconsistent state.

            Are you sure you want to cancel?""");

        ButtonType yesButton = new ButtonType("Yes, Cancel", ButtonData.OK_DONE);
        ButtonType noButton = new ButtonType("No, Continue", ButtonData.CANCEL_CLOSE);
        alert.getButtonTypes().setAll(yesButton, noButton);

        Optional<ButtonType> result = alert.showAndWait();
        boolean confirmed = result.isPresent() && result.get() == yesButton;
        LOGGER.info("Cancel confirmation: {}", confirmed ? "user cancelled operation" : "user continued");
        return confirmed;
    }

    private static String getActionWarning(String action, String actionName) {
        return switch (action) {
            case "bloatware-remove" -> 
                "'" + actionName + "' will uninstall pre-installed Windows apps.\n\n" +
                "Some apps may be difficult to reinstall. Make sure you have a restore point.";
            case "services-disable" -> 
                "'" + actionName + "' will disable Windows services.\n\n" +
                "WARNING: This may break Windows features like printing, Bluetooth, or remote desktop.\n" +
                "A system restore point is STRONGLY recommended.";
            case "driver-clean" -> 
                "'" + actionName + "' will remove GPU drivers using DDU.\n\n" +
                "Your display may go blank temporarily. Have a new driver ready to install.";
            case "cleanup-run" -> 
                "'" + actionName + "' will delete temporary files and caches.\n\n" +
                "This is generally safe but cannot be undone.";
            case "registry-apply" -> 
                "'" + actionName + "' will modify Windows registry settings.\n\n" +
                "A restore point is recommended before proceeding.";
            case "tls-hardening" -> 
                "'" + actionName + "' will disable legacy TLS/SSL protocols.\n\n" +
                "WARNING: This may break connectivity with older websites, VPNs, or enterprise systems.";
            case "firewall-hardening" ->
                "'" + actionName + "' will modify Windows Firewall policies.\n\n" +
                "This changes default inbound/outbound rules for all profiles. " +
                "Some applications may be blocked.";
            case "security-improve-network" ->
                "'" + actionName + "' will harden SMB/NetBIOS and disable legacy network components.\n\n" +
                "This may affect file sharing, remote access, or older devices on your network.";
            case "security-clipboard-data-disable" ->
                "'" + actionName + "' will disable clipboard sync and history.\n\n" +
                "Clipboard sync across devices and history will stop working.";
            case "security-ps2-downgrade-protection-enable" ->
                "'" + actionName + "' will disable PowerShell 2.0 optional features.\n\n" +
                "Legacy scripts requiring PowerShell 2.0 may stop working.";
            case "smart-optimize-aggressive" ->
                "'" + actionName + "' applies aggressive network adapter changes.\n\n" +
                "It may disable Flow Control/Jumbo Frames and force Interrupt Moderation.\n" +
                "This can reduce throughput on some LANs or increase latency.";
            case "copilot-disable" ->
                "'" + actionName + "' will disable Windows Copilot.\n\n" +
                "This removes the Copilot app and sets group policy to prevent it from running.";
            case "ui-remove-this-pc-folders" ->
                "'" + actionName + "' will hide standard folders from This PC.\n\n" +
                "The folders remain on disk, but Explorer shortcuts will be hidden.";
            case "ui-hibernation-disable" ->
                "'" + actionName + "' will disable hibernation.\n\n" +
                "This removes hiberfil.sys and may affect Fast Startup and sleep behavior.";
            default -> 
                "'" + actionName + "' will make changes to your system.\n\n" +
                "Are you sure you want to proceed?";
        };
    }
}
