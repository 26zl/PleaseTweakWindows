namespace PleaseTweakWindows.Models;

/// <summary>Controls confirmation and high-risk handling for an Apply action.</summary>
public enum SubTweakRisk { None, Confirm, High }

/// <summary>Defines the registry value required to enable a sub-tweak's Apply action.</summary>
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

    /// <summary>Warning template where <c>{0}</c> is replaced with the action name.</summary>
    public string? Warning { get; init; }

    /// <summary>Whether this toggle is eligible for its category's Run All command.</summary>
    public bool IncludeInRunAll { get; init; } = true;

    public SubTweak(string name, string applyAction, string? description)
        : this(name, SubTweakType.Button, applyAction, null, description) { }
}
