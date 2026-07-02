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

        // Require Windows 11 build 22000 or newer.
        if (Environment.OSVersion.Version.Build < 22000)
        {
            MessageBox.Show(
                "PleaseTweakWindows requires Windows 11 (build 22000 or newer). Windows 10 is not supported.",
                AppPaths.ProductName,
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
            return;
        }

        try
        {
            ConfigureLogging();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "PleaseTweakWindows could not initialize logging: " + ex.Message,
                AppPaths.ProductName,
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
            return;
        }

        DispatcherUnhandledException += (s, ex) =>
        {
            Log.Fatal(ex.Exception, "Unhandled UI exception");
            ex.Handled = true;
            try
            {
                MessageBox.Show(
                    "An unexpected error occurred. The action may not have completed. " +
                    "The application will close; see the log for details.",
                    AppPaths.ProductName,
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);
            }
            catch { }
            Shutdown(1);
        };
        AppDomain.CurrentDomain.UnhandledException += (s, ex) =>
            Log.Fatal(ex.ExceptionObject as Exception, "Unhandled domain exception");
        System.Threading.Tasks.TaskScheduler.UnobservedTaskException += (s, ex) =>
        {
            Log.Error(ex.Exception, "Unobserved task exception");
            ex.SetObserved();
        };

        // Surface startup failures before the main window is available.
        try
        {
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
        catch (Exception ex)
        {
            Log.Fatal(ex, "Startup failed");
            MessageBox.Show(
                "PleaseTweakWindows failed to start: " + ex.Message,
                AppPaths.ProductName,
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        try
        {
            if (_serviceProvider != null)
            {
                Log.Information("Shutting down PleaseTweakWindows.");
                try
                {
                    var executor = _serviceProvider.GetRequiredService<IScriptExecutor>();
                    executor.Shutdown();
                    var extractor = _serviceProvider.GetRequiredService<ResourceExtractor>();
                    extractor.Cleanup();
                }
                catch (Exception ex) { Log.Warning(ex, "Shutdown cleanup failed"); }
                _serviceProvider.Dispose();
            }
        }
        finally
        {
            Log.CloseAndFlush();
        }
        base.OnExit(e);
    }

    private static void ConfigureLogging()
    {
        var logDir = AppPaths.GetLogsDirectory();

        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Information()
            .WriteTo.Console(outputTemplate: "{Timestamp:HH:mm:ss.SSS} [{Level:u5}] {Message:lj}{NewLine}{Exception}")
            .WriteTo.File(
                Path.Combine(logDir, $"{AppPaths.ProductName}.log"),
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 14,
                fileSizeLimitBytes: 20 * 1024 * 1024,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.SSS} [{Level:u5}] {SourceContext} - {Message:lj}{NewLine}{Exception}")
            .WriteTo.File(
                Path.Combine(logDir, $"{AppPaths.ProductName}-error.log"),
                restrictedToMinimumLevel: Serilog.Events.LogEventLevel.Error,
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 30,
                fileSizeLimitBytes: 10 * 1024 * 1024,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.SSS} [{Level:u5}] {SourceContext} - {Message:lj}{NewLine}{Exception}")
            .WriteTo.Logger(lc => lc
                .Filter.ByIncludingOnly(ev => ev.Properties.ContainsKey("LocalActivity"))
                .WriteTo.File(
                    Path.Combine(logDir, $"{AppPaths.ProductName}-activity.log"),
                    rollingInterval: RollingInterval.Day,
                    retainedFileCountLimit: 14,
                    fileSizeLimitBytes: 5 * 1024 * 1024,
                    outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.SSS} [{Level:u5}] {SourceContext} - {Message:lj}{NewLine}{Exception}"))
            .CreateLogger();

        Log.Information("Starting PleaseTweakWindows UI. Logs: {LogDir}", logDir);
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddLogging(builder => builder.AddSerilog(dispose: true));

        services.AddSingleton<IProcessRunner, ProcessRunner>();
        services.AddSingleton<IScriptExecutor, ScriptExecutor>();
        services.AddSingleton<ResourceExtractor>();
        services.AddSingleton<TweakRegistry>();
        services.AddSingleton<IDialogService, DialogService>();
        services.AddSingleton<RestorePointGuard>();
        services.AddSingleton<UpdateChecker>();
        services.AddSingleton<ConfigProfileService>();
        services.AddSingleton<AdminChecker>();

        services.AddTransient<MainWindowViewModel>();
    }
}
