using Microsoft.Win32;
using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

/// <summary>Evaluates registry-backed dependencies and treats read errors as unmet requirements.</summary>
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
        catch (Exception ex)
        {
            Serilog.Log.Warning(ex,
                "Could not read prerequisite {Path}\\{Value}; treating dependency as UNMET (fail-closed).",
                requirement.RegistryPath, requirement.ValueName);
            return false;
        }
    }
}
