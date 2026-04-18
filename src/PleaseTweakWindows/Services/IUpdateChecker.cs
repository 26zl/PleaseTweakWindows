namespace PleaseTweakWindows.Services;

public interface IUpdateChecker
{
    Task<UpdateInfo?> CheckForUpdateAsync();
    void DismissVersion(string version);
}

public sealed record UpdateInfo(string Version, string DownloadUrl);
