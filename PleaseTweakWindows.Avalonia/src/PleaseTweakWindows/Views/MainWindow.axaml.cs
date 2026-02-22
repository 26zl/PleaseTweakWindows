using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using PleaseTweakWindows.ViewModels;

namespace PleaseTweakWindows.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        // Enable dragging the window by the title bar area
        TitleBar.PointerPressed += OnTitleBarPointerPressed;
    }

    private void OnTitleBarPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            BeginMoveDrag(e);
        }
    }

    private void OnMinimizeClick(object? sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }

    private void OnMaximizeClick(object? sender, RoutedEventArgs e)
    {
        WindowState = WindowState == WindowState.Maximized
            ? WindowState.Normal
            : WindowState.Maximized;
    }

    private async void OnCloseClick(object? sender, RoutedEventArgs e)
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
}
