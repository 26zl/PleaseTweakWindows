using System.Collections.Immutable;

namespace PleaseTweakWindows.Models;

public sealed record Tweak(
    string Title,
    string ApplyScript,
    string RevertScript,
    ImmutableList<SubTweak> SubTweaks)
{
    /// <summary>Convenience ctor for categories whose Apply and Revert run the same script.</summary>
    public Tweak(string title, string script, ImmutableList<SubTweak> subTweaks)
        : this(title, script, script, subTweaks) { }
}
