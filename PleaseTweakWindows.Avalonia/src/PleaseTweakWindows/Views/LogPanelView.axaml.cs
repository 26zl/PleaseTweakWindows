using Avalonia.Controls;
using PleaseTweakWindows.ViewModels;

namespace PleaseTweakWindows.Views;

public partial class LogPanelView : UserControl
{
    public LogPanelView()
    {
        InitializeComponent();

        // Auto-scroll to bottom when log text changes
        if (DataContext is LogPanelViewModel vm)
        {
            vm.PropertyChanged += OnViewModelPropertyChanged;
        }

        DataContextChanged += (_, _) =>
        {
            if (DataContext is LogPanelViewModel newVm)
            {
                newVm.PropertyChanged -= OnViewModelPropertyChanged;
                newVm.PropertyChanged += OnViewModelPropertyChanged;
            }
        };
    }

    private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(LogPanelViewModel.LogText))
        {
            var textBox = this.FindControl<TextBox>("LogTextBox");
            if (textBox != null)
            {
                textBox.CaretIndex = textBox.Text?.Length ?? 0;
            }
        }
    }
}
