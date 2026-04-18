using System.Windows;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Serilog;
using PleaseTweakWindows.Services;
using PleaseTweakWindows.ViewModels;
using PleaseTweakWindows.Views;

namespace PleaseTweakWindows;

public partial class App : Application
{
    private ServiceProvider? _serviceProvider;

    public static IServiceProvider Services { get; private set; } = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        ConfigureLogging();

        var services = new ServiceCollection();
        ConfigureServices(services);
        _serviceProvider = services.BuildServiceProvider();
        Services = _serviceProvider;

        var mainVm = _serviceProvider.GetRequiredService<MainWindowViewModel>();
        var mainWindow = new MainWindow { DataContext = mainVm };
        MainWindow = mainWindow;
        mainWindow.Show();

        _ = mainVm.InitializeAsync();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_serviceProvider != null)
        {
            Log.Information("Shutting down PleaseTweakWindows.");
            try
            {
                var executor = _serviceProvider.GetRequiredService<IScriptExecutor>();
                executor.Shutdown();
                var extractor = _serviceProvider.GetRequiredService<IResourceExtractor>();
                extractor.Cleanup();
            }
            catch { }
            Log.CloseAndFlush();
            _serviceProvider.Dispose();
        }
        base.OnExit(e);
    }

    private static void ConfigureLogging()
    {
        var exeDir = AppContext.BaseDirectory;
        var logDir = Path.Combine(exeDir, "logs");
        Directory.CreateDirectory(logDir);

        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Information()
            .WriteTo.Console(outputTemplate: "{Timestamp:HH:mm:ss.SSS} [{Level:u5}] {Message:lj}{NewLine}{Exception}")
            .WriteTo.File(
                Path.Combine(logDir, "PleaseTweakWindows.log"),
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 30,
                fileSizeLimitBytes: 500 * 1024 * 1024,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.SSS} [{Level:u5}] {SourceContext} - {Message:lj}{NewLine}{Exception}")
            .WriteTo.File(
                Path.Combine(logDir, "PleaseTweakWindows-error.log"),
                restrictedToMinimumLevel: Serilog.Events.LogEventLevel.Error,
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 90,
                fileSizeLimitBytes: 200 * 1024 * 1024,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.SSS} [{Level:u5}] {SourceContext} - {Message:lj}{NewLine}{Exception}")
            .WriteTo.Logger(lc => lc
                .Filter.ByIncludingOnly(ev => ev.Properties.ContainsKey("Telemetry"))
                .WriteTo.File(
                    Path.Combine(logDir, "PleaseTweakWindows-telemetry.log"),
                    rollingInterval: RollingInterval.Day,
                    retainedFileCountLimit: 30,
                    fileSizeLimitBytes: 200 * 1024 * 1024,
                    outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.SSS} [{Level:u5}] {SourceContext} - {Message:lj}{NewLine}{Exception}"))
            .CreateLogger();

        Log.Information("Starting PleaseTweakWindows UI.");
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddLogging(builder => builder.AddSerilog(dispose: true));

        services.AddSingleton<IProcessRunner, ProcessRunner>();
        services.AddSingleton<IScriptExecutor, ScriptExecutor>();
        services.AddSingleton<IResourceExtractor, ResourceExtractor>();
        services.AddSingleton<ITweakRegistry, TweakRegistry>();
        services.AddSingleton<IDialogService, DialogService>();
        services.AddSingleton<IRestorePointGuard, RestorePointGuard>();
        services.AddSingleton<IUpdateChecker, UpdateChecker>();
        services.AddSingleton<AdminChecker>();

        services.AddTransient<MainWindowViewModel>();
        services.AddTransient<LogPanelViewModel>();
    }
}
