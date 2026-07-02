using System.Collections.ObjectModel;
using System.Windows.Media;
using CommunityToolkit.Mvvm.Input;

namespace PleaseTweakWindows.ViewModels;

/// <summary>A rendered log line with prefix-based colouring.</summary>
public sealed class LogLine
{
    public string Text { get; }
    public Brush Foreground { get; }

    public LogLine(string text, Brush foreground)
    {
        Text = text;
        Foreground = foreground;
    }
}

public partial class LogPanelViewModel : ViewModelBase
{
    // Bound the rendered line collection during long runs.
    private const int MaxLines = 5000;
    private const int LineTrimChunk = MaxLines / 4;

    // Resolve cached brushes from the theme with design-time fallbacks.
    private static Brush? _successBrush;
    private static Brush? _dangerBrush;
    private static Brush? _warningBrush;
    private static Brush? _defaultBrush;

    /// <summary>Colour-coded lines displayed by the output panel.</summary>
    public ObservableCollection<LogLine> Lines => _lines;
    private readonly TrimmableLogCollection _lines = new();

    public void AppendLine(string line)
    {
        // Callers marshal AppendLine onto the UI thread.
        _lines.Add(new LogLine(line, BrushFor(line)));
        if (_lines.Count > MaxLines)
        {
            // Trim old lines with one collection reset.
            _lines.TrimHead(LineTrimChunk);
        }
    }

    /// <summary>Collection that removes leading items with one reset notification.</summary>
    private sealed class TrimmableLogCollection : ObservableCollection<LogLine>
    {
        public void TrimHead(int removeCount)
        {
            if (removeCount <= 0) return;
            if (removeCount >= Count) { Clear(); return; }
            ((List<LogLine>)Items).RemoveRange(0, removeCount);
            OnPropertyChanged(new System.ComponentModel.PropertyChangedEventArgs(nameof(Count)));
            OnPropertyChanged(new System.ComponentModel.PropertyChangedEventArgs("Item[]"));
            OnCollectionChanged(new System.Collections.Specialized.NotifyCollectionChangedEventArgs(
                System.Collections.Specialized.NotifyCollectionChangedAction.Reset));
        }
    }

    [RelayCommand]
    private void Clear()
    {
        Lines.Clear();
    }

    /// <summary>Opens the logs directory in Explorer.</summary>
    [RelayCommand]
    private void OpenLogsFolder()
    {
        try
        {
            var dir = Services.AppPaths.GetLogsDirectory();
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = dir,
                UseShellExecute = true,
            });
        }
        catch (Exception ex)
        {
            AppendLine($"[!] Could not open logs folder: {ex.Message}");
        }
    }

    private static Brush BrushFor(string line)
    {
        var trimmed = line.TrimStart();

        if (trimmed.StartsWith("[+]", StringComparison.Ordinal) ||
            trimmed.StartsWith("SUCCESS", StringComparison.OrdinalIgnoreCase))
            return _successBrush ??= Resolve("PtwSuccessBrush", Color.FromRgb(0x22, 0xC5, 0x5E));

        if (trimmed.StartsWith("[X]", StringComparison.Ordinal) ||
            trimmed.StartsWith("[-]", StringComparison.Ordinal) ||
            trimmed.StartsWith("FAILED", StringComparison.OrdinalIgnoreCase) ||
            trimmed.StartsWith("ERROR", StringComparison.OrdinalIgnoreCase))
            return _dangerBrush ??= Resolve("PtwDangerBrush", Color.FromRgb(0xEF, 0x44, 0x44));

        if (trimmed.StartsWith("[!]", StringComparison.Ordinal))
            return _warningBrush ??= Resolve("PtwWarningBrush", Color.FromRgb(0xD9, 0x77, 0x06));

        return _defaultBrush ??= Resolve("PtwTextPrimaryBrush", Color.FromRgb(0xED, 0xED, 0xEF));
    }

    private static Brush Resolve(string resourceKey, Color fallback)
    {
        var app = System.Windows.Application.Current;
        if (app?.TryFindResource(resourceKey) is Brush brush)
            return brush;

        var solid = new SolidColorBrush(fallback);
        solid.Freeze();
        return solid;
    }
}
