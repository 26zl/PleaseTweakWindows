using System.Windows;
using System.Windows.Media;

namespace PleaseTweakWindows.Themes;

/// <summary>
/// Replaces the dark theme brushes with Windows high-contrast system colours. It runs once at startup,
/// before any window or style uses the brushes; switching high contrast while the app runs needs a restart.
/// </summary>
internal static class HighContrastTheme
{
    private const string ProbeKey = "PtwBackgroundBrush";

    /// <summary>Every brush in Themes/AppTheme.xaml mapped to the system colour that replaces it.</summary>
    internal static IReadOnlyDictionary<string, Func<Brush>> BrushMap { get; } =
        new Dictionary<string, Func<Brush>>(StringComparer.Ordinal)
        {
            // Surfaces
            ["PtwBackgroundBrush"] = () => SystemColors.WindowBrush,
            ["PtwSurfaceBrush"] = () => SystemColors.WindowBrush,
            ["PtwSurfaceHoverBrush"] = () => SystemColors.WindowBrush,
            ["PtwAccentSubtleBrush"] = () => SystemColors.WindowBrush,
            ["PtwLogBackgroundBrush"] = () => SystemColors.WindowBrush,
            ["PtwSubTweakBrush"] = () => SystemColors.WindowBrush,
            ["PtwSubTweakHoverBrush"] = () => SystemColors.WindowBrush,
            ["PtwUpdateBarBrush"] = () => SystemColors.WindowBrush,
            ["PtwRevertBackgroundBrush"] = () => SystemColors.WindowBrush,
            ["PtwRevertHoverBrush"] = () => SystemColors.WindowBrush,
            ["PtwRevertPressedBrush"] = () => SystemColors.WindowBrush,
            ["PtwSearchBackgroundBrush"] = () => SystemColors.WindowBrush,

            // Text, status colours, borders and the focus outline
            ["PtwTextPrimaryBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwTextSecondaryBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwTextTertiaryBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwSuccessBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwWarningBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwDangerBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwAccentTextBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwBorderBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwBorderStrongBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwUpdateBorderBrush"] = () => SystemColors.WindowTextBrush,
            ["PtwFocusBrush"] = () => SystemColors.WindowTextBrush,

            // Filled buttons and the text on them
            ["PtwAccentBrush"] = () => SystemColors.HighlightBrush,
            ["PtwAccentHoverBrush"] = () => SystemColors.HighlightBrush,
            ["PtwAccentPressedBrush"] = () => SystemColors.HighlightBrush,
            ["PtwDangerButtonBrush"] = () => SystemColors.HighlightBrush,
            ["PtwDangerButtonHoverBrush"] = () => SystemColors.HighlightBrush,
            ["PtwDangerButtonPressedBrush"] = () => SystemColors.HighlightBrush,
            ["PtwOnAccentBrush"] = () => SystemColors.HighlightTextBrush,
        };

    public static void Apply(ResourceDictionary appResources)
    {
        var theme = FindThemeDictionary(appResources)
            ?? throw new InvalidOperationException("The app theme dictionary was not found.");
        foreach (var (key, brush) in BrushMap)
            theme[key] = brush();
    }

    // Replace the entries in the dictionary that defines them, so the theme's own styles pick them up too.
    private static ResourceDictionary? FindThemeDictionary(ResourceDictionary dictionary)
    {
        if (dictionary.Contains(ProbeKey))
            return dictionary;
        foreach (var merged in dictionary.MergedDictionaries)
        {
            var found = FindThemeDictionary(merged);
            if (found != null)
                return found;
        }
        return null;
    }
}
