using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using PleaseTweakWindows.ViewModels;

namespace PleaseTweakWindows.Views;

public partial class TweakCategoryView : UserControl
{
    public TweakCategoryView()
    {
        InitializeComponent();
    }

    private void OnHeaderPressed(object sender, MouseButtonEventArgs e)
    {
        ToggleExpand(sender as IInputElement);
        e.Handled = true;
    }

    private void OnHeaderKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter && e.Key != Key.Space) return;
        ToggleExpand(sender as IInputElement);
        e.Handled = true;
    }

    private void ToggleExpand(IInputElement? focusTarget)
    {
        if (DataContext is not TweakCategoryViewModel vm) return;

        // Focus the header when the category is first activated.
        focusTarget?.Focus();

        vm.ToggleExpandCommand.Execute(null);

        if (vm.IsExpanded)
        {
            var mainVm = FindMainWindowViewModel();
            mainVm?.OnCategoryExpanded(vm);
        }
    }

    private MainWindowViewModel? FindMainWindowViewModel()
    {
        DependencyObject? current = this;
        while (current != null)
        {
            if (current is FrameworkElement fe && fe.DataContext is MainWindowViewModel mvm)
                return mvm;
            current = VisualTreeHelper.GetParent(current);
        }
        return System.Windows.Application.Current?.MainWindow?.DataContext as MainWindowViewModel;
    }
}
