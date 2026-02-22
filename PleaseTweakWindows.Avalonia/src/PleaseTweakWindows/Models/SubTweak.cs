namespace PleaseTweakWindows.Models;

public sealed record SubTweak(
    string Name,
    SubTweakType Type,
    string ApplyAction,
    string? RevertAction,
    string? Description)
{
    /// <summary>Button-type constructor (apply-only, no revert).</summary>
    public SubTweak(string name, string applyAction, string? description)
        : this(name, SubTweakType.Button, applyAction, null, description) { }
}
