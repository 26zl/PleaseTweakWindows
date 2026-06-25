namespace PleaseTweakWindows.Models;

/// <summary>
/// How destructive a sub-tweak's Apply action is. Drives whether a confirmation
/// dialog is shown (Confirm or High) and whether it is treated as high-risk (High).
/// High implies Confirm.
/// </summary>
public enum SubTweakRisk { None, Confirm, High }

/// <summary>
/// A dependency: this sub-tweak's Apply is only enabled when the registry DWORD at
/// <see cref="RegistryPath"/>\<see cref="ValueName"/> equals <see cref="ExpectedValue"/>
/// (i.e. the prerequisite tweak is actually applied on this machine). Otherwise the
/// Apply button is greyed and <see cref="UnmetMessage"/> is shown as a tooltip.
/// RegistryPath uses the full hive form, e.g. "HKEY_LOCAL_MACHINE\\SYSTEM\\...".
/// </summary>
public sealed record SubTweakRequirement(
    string RegistryPath,
    string ValueName,
    int ExpectedValue,
    string UnmetMessage);

public sealed record SubTweak(
    string Name,
    SubTweakType Type,
    string ApplyAction,
    string? RevertAction,
    string? Description)
{
    /// <summary>Optional prerequisite that must already be applied for Apply to be enabled.</summary>
    public SubTweakRequirement? Requires { get; init; }

    /// <summary>How destructive the Apply action is (drives confirmation + high-risk classification).</summary>
    public SubTweakRisk Risk { get; init; } = SubTweakRisk.None;

    /// <summary>
    /// Confirmation-dialog warning template for the Apply action. <c>{0}</c> is replaced
    /// with the action's display name. Null falls back to the generic warning.
    /// </summary>
    public string? Warning { get; init; }

    public SubTweak(string name, string applyAction, string? description)
        : this(name, SubTweakType.Button, applyAction, null, description) { }
}
