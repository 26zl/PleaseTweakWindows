using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Data;

namespace PleaseTweakWindows.Converters;

public sealed class BoolToVisibilityConverter : IValueConverter
{
    public static readonly BoolToVisibilityConverter Instance = new();

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? Visibility.Visible : Visibility.Collapsed;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is Visibility v && v == Visibility.Visible;
}

public sealed class InverseBoolConverter : IValueConverter
{
    public static readonly InverseBoolConverter Instance = new();

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is not true;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is not true;
}

public sealed class InverseBoolToVisibilityConverter : IValueConverter
{
    public static readonly InverseBoolToVisibilityConverter Instance = new();

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is Visibility v && v == Visibility.Collapsed;
}

public sealed class StringNotEmptyToVisibilityConverter : IValueConverter
{
    public static readonly StringNotEmptyToVisibilityConverter Instance = new();

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => string.IsNullOrEmpty(value as string) ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

/// <summary>
/// MultiBinding converter that returns <c>false</c> when ANY bound bool is true,
/// otherwise <c>true</c>. Used to disable a control while either the local run flag
/// or the global run flag is set: IsEnabled = !(IsRunning || IsGloballyRunning).
/// </summary>
public sealed class NotAnyTrueConverter : IMultiValueConverter
{
    public static readonly NotAnyTrueConverter Instance = new();

    public object Convert(object?[] values, Type targetType, object? parameter, CultureInfo culture)
        => !values.Any(v => v is true);

    public object[] ConvertBack(object? value, Type[] targetTypes, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

public sealed class ExpandArrowConverter : IValueConverter
{
    public static readonly ExpandArrowConverter Instance = new();

    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? "\u25B2" : "\u25BC";

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
