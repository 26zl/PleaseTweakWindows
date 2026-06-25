using Microsoft.Win32;
using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

/// <summary>
/// Reads live registry state to evaluate sub-tweak dependencies. Windows-only at runtime;
/// fails OPEN (returns satisfied) on any read error so a transient failure never locks the UI.
/// </summary>
public static class RegistryState
{
    public static bool IsSatisfied(SubTweakRequirement? requirement)
    {
        if (requirement is null) return true;
        try
        {
            var value = Registry.GetValue(requirement.RegistryPath, requirement.ValueName, null);
            if (value is null) return false;
            return Convert.ToInt32(value) == requirement.ExpectedValue;
        }
        catch
        {
            return true;
        }
    }
}
