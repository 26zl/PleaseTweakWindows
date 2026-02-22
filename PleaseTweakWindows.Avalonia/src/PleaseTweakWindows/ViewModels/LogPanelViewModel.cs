using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace PleaseTweakWindows.ViewModels;

public partial class LogPanelViewModel : ViewModelBase
{
    [ObservableProperty]
    private string _logText = string.Empty;

    public void AppendLine(string line)
    {
        LogText += line + Environment.NewLine;
    }

    [RelayCommand]
    private void Clear()
    {
        LogText = string.Empty;
    }
}
