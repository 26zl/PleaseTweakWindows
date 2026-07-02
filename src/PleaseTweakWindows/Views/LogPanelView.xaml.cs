using System.Collections.Specialized;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PleaseTweakWindows.ViewModels;

namespace PleaseTweakWindows.Views;

public partial class LogPanelView : UserControl
{
    // The ScrollViewer lives inside the ItemsControl template, so resolve it from the visual tree.
    private ScrollViewer? _logScrollViewer;

    public LogPanelView()
    {
        InitializeComponent();

        DataContextChanged += (_, e) =>
        {
            if (e.OldValue is LogPanelViewModel oldVm)
                oldVm.Lines.CollectionChanged -= OnLinesChanged;
            if (e.NewValue is LogPanelViewModel newVm)
                newVm.Lines.CollectionChanged += OnLinesChanged;
        };
    }

    // Auto-scroll only when the user was already near the bottom.
    private void OnLinesChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        var scrollViewer = _logScrollViewer ??= FindScrollViewer(this);
        if (scrollViewer != null &&
            scrollViewer.VerticalOffset >= scrollViewer.ScrollableHeight - 1.0)
            scrollViewer.ScrollToEnd();
    }

    private static ScrollViewer? FindScrollViewer(DependencyObject root)
    {
        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var i = 0; i < count; i++)
        {
            var child = VisualTreeHelper.GetChild(root, i);
            if (child is ScrollViewer scrollViewer)
                return scrollViewer;

            var found = FindScrollViewer(child);
            if (found != null)
                return found;
        }

        return null;
    }
}
