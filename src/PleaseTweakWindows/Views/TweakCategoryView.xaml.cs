using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PleaseTweakWindows.ViewModels;

namespace PleaseTweakWindows.Views;

public partial class TweakCategoryView : UserControl
{
    public TweakCategoryView()
    {
        InitializeComponent();
    }

    // Mouse, Enter/Space and UI Automation all arrive here through the header button's Click.
    private void OnHeaderClick(object sender, RoutedEventArgs e)
    {
        if (DataContext is not TweakCategoryViewModel vm) return;

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
