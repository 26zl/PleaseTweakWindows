namespace PleaseTweakWindows.Services;

public interface IResourceExtractor
{
    string PrepareScriptsPath();
    void Cleanup();
}
