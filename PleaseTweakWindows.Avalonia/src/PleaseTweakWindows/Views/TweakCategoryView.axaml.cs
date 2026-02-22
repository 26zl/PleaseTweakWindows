using System.Globalization;
using Avalonia.Controls;
using Avalonia.Data.Converters;
using Avalonia.Input;
using PleaseTweakWindows.ViewModels;

namespace PleaseTweakWindows.Views;

public partial class TweakCategoryView : UserControl
{
    public static readonly IValueConverter ArrowConverter = new ExpandArrowConverter();

    public TweakCategoryView()
    {
        InitializeComponent();
    }

    private void OnHeaderPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is TweakCategoryViewModel vm)
        {
            vm.ToggleExpandCommand.Execute(null);

            // Accordion behavior: notify parent to collapse others
            if (vm.IsExpanded)
            {
                var mainVm = FindMainWindowViewModel();
                mainVm?.OnCategoryExpanded(vm);
            }
        }
    }

    private MainWindowViewModel? FindMainWindowViewModel()
    {
        var window = TopLevel.GetTopLevel(this);
        return window?.DataContext as MainWindowViewModel;
    }

    private class ExpandArrowConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
            => value is true ? "\u25B2" : "\u25BC";

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
            => throw new NotSupportedException();
    }
}
