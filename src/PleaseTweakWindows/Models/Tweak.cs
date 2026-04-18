using System.Collections.Immutable;

namespace PleaseTweakWindows.Models;

public sealed record Tweak(
    string Title,
    string ApplyScript,
    string RevertScript,
    ImmutableList<SubTweak> SubTweaks);
