using System.Windows;
using System.Windows.Automation;
using System.Windows.Automation.Peers;
using System.Windows.Automation.Provider;
using System.Windows.Controls;

namespace PleaseTweakWindows.Views.Controls;

/// <summary>
/// Header button that expands or collapses a section. Screen readers see a button with the
/// ExpandCollapse pattern, so they announce "expanded"/"collapsed" and can toggle it.
/// </summary>
public sealed class ExpanderHeaderButton : Button
{
    public static readonly DependencyProperty IsExpandedProperty = DependencyProperty.Register(
        nameof(IsExpanded),
        typeof(bool),
        typeof(ExpanderHeaderButton),
        new FrameworkPropertyMetadata(false, OnIsExpandedChanged));

    public bool IsExpanded
    {
        get => (bool)GetValue(IsExpandedProperty);
        set => SetValue(IsExpandedProperty, value);
    }

    protected override AutomationPeer OnCreateAutomationPeer() => new ExpanderHeaderButtonAutomationPeer(this);

    private static void OnIsExpandedChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (UIElementAutomationPeer.FromElement((UIElement)d) is ExpanderHeaderButtonAutomationPeer peer)
            peer.RaiseExpandCollapseStateChanged((bool)e.OldValue, (bool)e.NewValue);
    }
}

internal sealed class ExpanderHeaderButtonAutomationPeer(ExpanderHeaderButton owner)
    : ButtonAutomationPeer(owner), IExpandCollapseProvider
{
    private ExpanderHeaderButton Header => (ExpanderHeaderButton)Owner;

    public ExpandCollapseState ExpandCollapseState => ToState(Header.IsExpanded);

    public override object GetPattern(PatternInterface patternInterface) =>
        patternInterface == PatternInterface.ExpandCollapse ? this : base.GetPattern(patternInterface);

    public void Expand()
    {
        if (!Header.IsExpanded)
            Toggle();
    }

    public void Collapse()
    {
        if (Header.IsExpanded)
            Toggle();
    }

    internal void RaiseExpandCollapseStateChanged(bool oldValue, bool newValue) =>
        RaisePropertyChangedEvent(
            ExpandCollapsePatternIdentifiers.ExpandCollapseStateProperty,
            ToState(oldValue),
            ToState(newValue));

    // Go through Invoke so automation runs the same Click handler as mouse and keyboard.
    private void Toggle() => ((IInvokeProvider)this).Invoke();

    private static ExpandCollapseState ToState(bool expanded) =>
        expanded ? ExpandCollapseState.Expanded : ExpandCollapseState.Collapsed;
}
