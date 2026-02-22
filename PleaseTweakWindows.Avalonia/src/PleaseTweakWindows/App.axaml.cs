using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Serilog;
using PleaseTweakWindows.Services;
using PleaseTweakWindows.ViewModels;
using PleaseTweakWindows.Views;

namespace PleaseTweakWindows;

public class App : Application
{
    private ServiceProvider? _serviceProvider;

    public static IServiceProvider Services { get; private set; } = null!;

    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        ConfigureLogging();

        var services = new ServiceCollection();
        ConfigureServices(services);
        _serviceProvider = services.BuildServiceProvider();
        Services = _serviceProvider;

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var mainVm = _serviceProvider.GetRequiredService<MainWindowViewModel>();
            desktop.MainWindow = new MainWindow { DataContext = mainVm };

            desktop.ShutdownRequested += (_, _) =>
            {
                Log.Information("Shutting down PleaseTweakWindows.");
                var executor = _serviceProvider.GetRequiredService<IScriptExecutor>();
                executor.Shutdown();
                var extractor = _serviceProvider.GetRequiredService<IResourceExtractor>();
                extractor.Cleanup();
                Log.CloseAndFlush();
            };

            // Initialize after window is shown
            mainVm.InitializeAsync();
        }

        base.OnFrameworkInitializationCompleted();
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
                .Filter.ByIncludingOnly(e => e.Properties.ContainsKey("Telemetry"))
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

        // Services
        services.AddSingleton<IProcessRunner, ProcessRunner>();
        services.AddSingleton<IScriptExecutor, ScriptExecutor>();
        services.AddSingleton<IResourceExtractor, ResourceExtractor>();
        services.AddSingleton<ITweakRegistry, TweakRegistry>();
        services.AddSingleton<IDialogService, DialogService>();
        services.AddSingleton<IRestorePointGuard, RestorePointGuard>();
        services.AddSingleton<IUpdateChecker, UpdateChecker>();
        services.AddSingleton<AdminChecker>();

        // ViewModels
        services.AddTransient<MainWindowViewModel>();
        services.AddTransient<LogPanelViewModel>();
    }
}
