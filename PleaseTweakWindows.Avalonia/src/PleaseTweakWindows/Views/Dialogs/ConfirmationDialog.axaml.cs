using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Markup.Xaml;

namespace PleaseTweakWindows.Views.Dialogs;

public partial class ConfirmationDialog : Window
{
    public string DialogTitle { get; set; } = "Confirm";
    public string DialogHeader { get; set; } = "";
    public string DialogContent { get; set; } = "";
    public string ConfirmText { get; set; } = "Confirm";
    public string CancelText { get; set; } = "Cancel";
    public string SkipText { get; set; } = "Skip";
    public bool ShowSkipButton { get; set; }
    public bool IsHighRisk { get; set; }

    public ConfirmationDialog()
    {
        InitializeComponent();
    }

    private void InitializeComponent()
    {
        AvaloniaXamlLoader.Load(this);
    }

    protected override void OnOpened(EventArgs e)
    {
        base.OnOpened(e);

        Title = DialogTitle;

        var headerText = this.FindControl<TextBlock>("HeaderText")!;
        headerText.Text = DialogHeader;
        if (IsHighRisk)
            headerText.Foreground = Avalonia.Media.Brushes.IndianRed;

        this.FindControl<TextBlock>("ContentText")!.Text = DialogContent;

        var confirmBtn = this.FindControl<Button>("ConfirmButton")!;
        confirmBtn.Content = ConfirmText;
        if (IsHighRisk)
            confirmBtn.Classes.Remove("accent");
            confirmBtn.Classes.Add(IsHighRisk ? "danger" : "accent");

        var cancelBtn = this.FindControl<Button>("CancelButton")!;
        cancelBtn.Content = CancelText;

        var skipBtn = this.FindControl<Button>("SkipButton")!;
        skipBtn.Content = SkipText;
        skipBtn.IsVisible = ShowSkipButton;
    }

    private void OnConfirmClick(object? sender, RoutedEventArgs e) => Close("confirm");
    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close("cancel");
    private void OnSkipClick(object? sender, RoutedEventArgs e) => Close("skip");
}
