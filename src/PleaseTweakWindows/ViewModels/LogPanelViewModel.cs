using System.Text;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace PleaseTweakWindows.ViewModels;

public partial class LogPanelViewModel : ViewModelBase
{
    // 1 MB cap. When exceeded we drop the oldest ~25% so the buffer stays bounded.
    // Real-world tweak runs produce kilobytes; long batches ("Run All" over the whole
    // Security category with verbose output) can exceed 100 KB, still well under the cap.
    private const int MaxBufferLength = 1_048_576;
    private const int TrimChunk = MaxBufferLength / 4;

    private readonly StringBuilder _buffer = new(capacity: 8192);
    private readonly object _lock = new();

    [ObservableProperty]
    private string _logText = string.Empty;

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
        LogText = snapshot;
    }

    [RelayCommand]
    private void Clear()
    {
        lock (_lock)
        {
            _buffer.Clear();
        }
        LogText = string.Empty;
    }
}
