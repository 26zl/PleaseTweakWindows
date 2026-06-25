using Microsoft.Win32;
using PleaseTweakWindows.Models;

namespace PleaseTweakWindows.Services;

/// <summary>
/// Reads live registry state to evaluate sub-tweak dependencies. Windows-only at runtime.
/// Fails CLOSED (returns NOT satisfied) on any read error: a dependent tweak — e.g. HVCI
/// Mandatory or Secure Launch, which can affect boot — must never be enabled on an
/// unverified prerequisite. The reason is logged so a genuine read failure is diagnosable.
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
        catch (Exception ex)
        {
            Serilog.Log.Warning(ex,
                "Could not read prerequisite {Path}\\{Value}; treating dependency as UNMET (fail-closed).",
                requirement.RegistryPath, requirement.ValueName);
            return false;
        }
    }
}
