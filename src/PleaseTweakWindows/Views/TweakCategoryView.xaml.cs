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
        if (DataContext is TweakCategoryViewModel vm)
        {
            vm.ToggleExpandCommand.Execute(null);

            if (vm.IsExpanded)
            {
                var mainVm = FindMainWindowViewModel();
                mainVm?.OnCategoryExpanded(vm);
            }
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
