using System.Windows;

namespace PleaseTweakWindows.ViewModels;

internal static class UiDispatcher
{
    public static void Post(Action action)
    {
        var app = Application.Current;
        if (app == null)
        {
            action();
            return;
        }
        if (app.Dispatcher.CheckAccess())
            action();
        else
            app.Dispatcher.BeginInvoke(action);
    }
}
