using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using PleaseTweakWindows.ViewModels;

namespace PleaseTweakWindows.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private void OnMinimizeClick(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }

    private void OnMaximizeClick(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState == WindowState.Maximized
            ? WindowState.Normal
            : WindowState.Maximized;
    }

    private async void OnCloseClick(object sender, RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
        {
            await vm.HandleCloseCommand.ExecuteAsync(null);
        }
        else
        {
            Close();
        }
    }

    protected override async void OnClosing(CancelEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
        {
            // Route closing through the view model while operations are active.
            var services = App.Services;
            if (services != null)
            {
                var executor = (Services.IScriptExecutor)services.GetService(typeof(Services.IScriptExecutor))!;
                if (executor != null && executor.HasActiveOperations)
                {
                    e.Cancel = true;
                    await vm.HandleCloseCommand.ExecuteAsync(null);
                    return;
                }
            }
        }
        base.OnClosing(e);
    }
}
