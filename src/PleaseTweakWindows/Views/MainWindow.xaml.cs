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
            // If there are active operations, cancel the default close
            // and route through the VM to prompt the user.
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
