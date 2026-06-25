using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public sealed partial class TweakRegistry
{
    private static Tweak BuildCustomize() => new(
        "Customize",
        $"Customize{S}Customize.ps1",
        [
            new SubTweak("Dark Mode", SubTweakType.Toggle, "theme-dark", "theme-light",
                "Switch Windows apps and system to dark mode; revert restores light mode"),
            new SubTweak("Show File Extensions", SubTweakType.Toggle, "file-ext-show", "file-ext-hide",
                "Show known file-type extensions in Explorer; revert hides them (Windows default)"),
            new SubTweak("Show Hidden Files", SubTweakType.Toggle, "hidden-files-show", "hidden-files-hide",
                "Show hidden files and folders in Explorer; revert hides them (Windows default)"),
            new SubTweak("Show Protected OS Files", SubTweakType.Toggle, "super-hidden-show", "super-hidden-hide",
                "Show protected operating-system files. WARNING: reveals system files (pagefile, boot files) that can break Windows if deleted; revert hides them")
            {
                Risk = SubTweakRisk.Confirm,
                Warning =
                    "'{0}' will reveal protected operating-system files in Explorer.\n\n" +
                    "These include boot files and the page file. Deleting or editing them can break Windows. Revert hides them again.",
            },
            new SubTweak("Left-align Taskbar", SubTweakType.Toggle, "taskbar-align-left", "taskbar-align-center",
                "Align taskbar icons to the left (Windows 10 style); revert centers them (Windows 11 default)"),
            new SubTweak("Hide Task View Button", SubTweakType.Toggle, "taskview-hide", "taskview-show",
                "Hide the Task View button on the taskbar; revert shows it"),
            new SubTweak("Open Explorer to This PC", SubTweakType.Toggle, "explorer-this-pc", "explorer-quick-access",
                "Open File Explorer to This PC; revert opens to Quick Access / Home (Windows default)"),
            new SubTweak("Classic Context Menu (Windows 11)", SubTweakType.Toggle, "context-menu-classic", "context-menu-default",
                "Restore the full Windows 10 style right-click menu on Windows 11; revert restores the compact default menu"),
            new SubTweak("Hide Taskbar Search", SubTweakType.Toggle, "search-box-hide", "search-box-show",
                "Hide the taskbar search box/icon; revert shows the search box"),
            new SubTweak("Disable Lock Screen", SubTweakType.Toggle, "lockscreen-disable", "lockscreen-enable",
                "Skip lock screen on sign-in"),
            new SubTweak("Clean Start Menu & Taskbar", "startmenu-clean",
                "Remove default pinned items from Start Menu and Taskbar"),
            new SubTweak("Add Start Menu Shortcuts", "shortcuts-add",
                "Add useful shortcuts to Start Menu"),
            new SubTweak("Disable Keyboard Shortcuts", SubTweakType.Toggle, "keyboard-disable", "keyboard-enable",
                "Disable Windows key shortcuts"),
        ]);
}
