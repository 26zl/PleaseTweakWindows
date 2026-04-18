using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

public interface ITweakRegistry
{
    IReadOnlyList<Tweak> GetTweaks();
}
