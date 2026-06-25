using System.Collections.ObjectModel;
using System.Text;
using System.Windows.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace PleaseTweakWindows.ViewModels;

/// <summary>
/// A single rendered log line with a foreground brush derived from its prefix
/// so success/failure/warning lines are visually distinguishable.
/// </summary>
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
    // 1 MB cap. When exceeded we drop the oldest ~25% so the buffer stays bounded.
    // Real-world tweak runs produce kilobytes; long batches ("Run All" over the whole
    // Security category with verbose output) can exceed 100 KB, still well under the cap.
    private const int MaxBufferLength = 1_048_576;
    private const int TrimChunk = MaxBufferLength / 4;

    // Bound the rendered line collection independently of the text buffer so the
    // ItemsControl doesn't grow without limit during very long sweeps.
    private const int MaxLines = 5000;
    private const int LineTrimChunk = MaxLines / 4;

    private readonly StringBuilder _buffer = new(capacity: 8192);
    private readonly object _lock = new();

    // Cached brushes resolved lazily from the merged theme dictionary. Falls back to
    // hard-coded colours if the app resources aren't available (e.g. design-time).
    private static Brush? _successBrush;
    private static Brush? _dangerBrush;
    private static Brush? _warningBrush;
    private static Brush? _defaultBrush;

    [ObservableProperty]
    private string _logText = string.Empty;

    /// <summary>Colour-coded log lines for the output panel.</summary>
    public ObservableCollection<LogLine> Lines { get; } = new();

    public void AppendLine(string line)
    {
        string snapshot;
        lock (_lock)
        {
            _buffer.Append(line);
            _buffer.AppendLine();

            if (_buffer.Length > MaxBufferLength)
            {
                _buffer.Remove(0, TrimChunk);
            }

            snapshot = _buffer.ToString();
        }

        // AppendLine is always marshalled onto the UI thread by callers
        // (UiDispatcher.Post), so mutating the collection here is thread-safe.
        Lines.Add(new LogLine(line, BrushFor(line)));
        if (Lines.Count > MaxLines)
        {
            for (var i = 0; i < LineTrimChunk && Lines.Count > 0; i++)
                Lines.RemoveAt(0);
        }

        LogText = snapshot;
    }

    [RelayCommand]
    private void Clear()
    {
        lock (_lock)
        {
            _buffer.Clear();
        }
        Lines.Clear();
        LogText = string.Empty;
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
