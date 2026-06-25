using System.Collections.Generic;
using System.Linq;
using System.Windows;

namespace PleaseTweakWindows.Views.Dialogs;

/// <summary>One reviewable row in the import dialog. IsSelected is bound TwoWay to a CheckBox.</summary>
public sealed class ConfigReviewItem
{
    public string ActionId { get; }
    public string DisplayName { get; }
    public bool IsSelected { get; set; } = true;

    public ConfigReviewItem(string actionId, string displayName)
    {
        ActionId = actionId;
        DisplayName = displayName;
    }
}

public partial class ConfigReviewDialog : Window
{
    private readonly IReadOnlyList<ConfigReviewItem> _items;

    public IReadOnlyList<string> SelectedActionIds { get; private set; } = [];

    public ConfigReviewDialog(IReadOnlyList<ConfigReviewItem> items, int droppedCount)
    {
        _items = items;
        InitializeComponent();
        ItemsHost.ItemsSource = _items;
        SubText.Text = droppedCount > 0
            ? $"{_items.Count} tweak(s) from this profile match this build. {droppedCount} unknown entr(ies) were skipped. Uncheck anything you don't want, then Apply."
            : $"{_items.Count} tweak(s) found. Uncheck anything you don't want, then Apply.";
    }

    private void OnApplyClick(object sender, RoutedEventArgs e)
    {
        SelectedActionIds = _items.Where(i => i.IsSelected).Select(i => i.ActionId).ToList();
        DialogResult = true;
        Close();
    }

    private void OnCancelClick(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
