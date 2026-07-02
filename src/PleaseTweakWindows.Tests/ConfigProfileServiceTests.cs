using FluentAssertions;
using PleaseTweakWindows.Services;
using Xunit;

namespace PleaseTweakWindows.Tests;

public class ConfigProfileServiceTests
{
    private readonly ConfigProfileService _service = new();

    [Fact]
    public void Export_Then_Import_RoundTripsActions()
    {
        var json = _service.Export(new[] { "theme-dark", "wu-disable" }, "2.2.0", DateTimeOffset.UnixEpoch);
        var known = new HashSet<string> { "theme-dark", "wu-disable" };

        var result = _service.Import(json, known);

        result.Error.Should().BeNull();
        result.ValidActions.Should().Equal("theme-dark", "wu-disable");
        result.DroppedActions.Should().BeEmpty();
    }

    [Fact]
    public void Export_DeduplicatesAndSkipsBlanks()
    {
        var json = _service.Export(new[] { "theme-dark", "theme-dark", "  ", "" }, "x", DateTimeOffset.UnixEpoch);

        var result = _service.Import(json, new HashSet<string> { "theme-dark" });
        result.ValidActions.Should().ContainSingle().Which.Should().Be("theme-dark");
    }

    [Fact]
    public void Import_DropsUnknownActionIds()
    {
        var json = _service.Export(new[] { "theme-dark", "not-a-real-action" }, "x", DateTimeOffset.UnixEpoch);

        var result = _service.Import(json, new HashSet<string> { "theme-dark" });

        result.ValidActions.Should().Equal("theme-dark");
        result.DroppedActions.Should().Equal("not-a-real-action");
    }

    [Fact]
    public void Import_RejectsMalformedJson()
    {
        var result = _service.Import("{ this is not json", new HashSet<string>());

        result.Error.Should().NotBeNull();
        result.ValidActions.Should().BeEmpty();
    }

    [Fact]
    public void Import_RejectsUnsupportedSchemaVersion()
    {
        var json = "{\"schemaVersion\":99,\"actions\":[\"theme-dark\"]}";

        var result = _service.Import(json, new HashSet<string> { "theme-dark" });

        result.Error.Should().NotBeNull();
        result.ValidActions.Should().BeEmpty();
    }

    [Fact]
    public void Import_RejectsUnsupportedSchemaVersion_LowercaseKeys()
    {
        // Apply the version guard to case-insensitive JSON keys.
        var json = "{\"schemaversion\":99,\"actions\":[\"theme-dark\"]}";

        var result = _service.Import(json, new HashSet<string> { "theme-dark" });

        result.Error.Should().NotBeNull();
        result.ValidActions.Should().BeEmpty();
    }

    [Fact]
    public void Import_RejectsEmptyActions()
    {
        var json = _service.Export(System.Array.Empty<string>(), "x", DateTimeOffset.UnixEpoch);

        var result = _service.Import(json, new HashSet<string> { "theme-dark" });

        result.Error.Should().NotBeNull();
    }

    [Fact]
    public void Import_RejectsNullProfile()
    {
        // A bare JSON null deserializes to a null profile; must return an Error, not throw (NRE).
        var result = _service.Import("null", new HashSet<string> { "theme-dark" });

        result.Error.Should().NotBeNull();
        result.ValidActions.Should().BeEmpty();
    }

    [Fact]
    public void Import_RejectsNullActions()
    {
        // An explicit "actions": null must hit the null-Actions guard without throwing.
        var json = "{\"schemaVersion\":1,\"actions\":null}";

        var result = _service.Import(json, new HashSet<string> { "theme-dark" });

        result.Error.Should().NotBeNull();
        result.ValidActions.Should().BeEmpty();
    }

    [Fact]
    public void Import_RejectsUnreasonablyLargeProfiles()
    {
        var actions = Enumerable.Range(0, 1001)
            .Select(i => $"action-{i}");
        var json = System.Text.Json.JsonSerializer.Serialize(new
        {
            schemaVersion = 1,
            actions
        });

        var result = _service.Import(json, new HashSet<string>());

        result.Error.Should().Contain("too many actions");
        result.ValidActions.Should().BeEmpty();
    }
}
