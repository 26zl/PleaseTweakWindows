using System.ComponentModel;
using System.Windows.Controls;
using PleaseTweakWindows.ViewModels;

namespace PleaseTweakWindows.Views;

public partial class LogPanelView : UserControl
{
    public LogPanelView()
    {
        InitializeComponent();

        DataContextChanged += (_, e) =>
        {
            if (e.OldValue is INotifyPropertyChanged oldVm)
                oldVm.PropertyChanged -= OnViewModelPropertyChanged;
            if (e.NewValue is LogPanelViewModel newVm)
                newVm.PropertyChanged += OnViewModelPropertyChanged;
        };
    }

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(LogPanelViewModel.LogText))
        {
            LogTextBox.CaretIndex = LogTextBox.Text?.Length ?? 0;
            LogTextBox.ScrollToEnd();
        }
    }
}
