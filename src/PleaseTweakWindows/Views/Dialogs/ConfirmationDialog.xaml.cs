using System.Windows;
using System.Windows.Media;

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

    public string? Result { get; private set; }

    public ConfirmationDialog()
    {
        InitializeComponent();
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);

        Title = DialogTitle;
        HeaderText.Text = DialogHeader;
        if (IsHighRisk)
            HeaderText.Foreground = (Brush)FindResource("PtwDangerBrush");

        ContentText.Text = DialogContent;

        ConfirmButton.Content = ConfirmText;
        if (IsHighRisk)
            ConfirmButton.Style = (Style)FindResource("DangerButton");

        CancelButton.Content = CancelText;
        SkipButton.Content = SkipText;
        SkipButton.Visibility = ShowSkipButton ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnConfirmClick(object sender, RoutedEventArgs e) { Result = "confirm"; DialogResult = true; Close(); }
    private void OnCancelClick(object sender, RoutedEventArgs e) { Result = "cancel"; DialogResult = false; Close(); }
    private void OnSkipClick(object sender, RoutedEventArgs e) { Result = "skip"; DialogResult = true; Close(); }
}
