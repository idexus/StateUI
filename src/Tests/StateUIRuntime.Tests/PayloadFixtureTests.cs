// The two channels this runtime WRITES - an act's reply and an event's
// payload - held to the fixtures under fixtures/payloads.
//
// The direction is the reverse of every other fixture's: the Swift tests
// author these bytes with the library's own value encoding, the Swift library
// READS them, and this side asserts its WRITER produces exactly the same
// bytes for the same values. Writer and reader meet in the file, so neither
// can drift alone - and a review reads the .txt sidecar beside each.

using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Tests;

public class PayloadFixtureTests
{
    private static void Matches(byte[]? written, string name)
    {
        Assert.NotNull(written);
        Assert.Equal(Fixtures.ReadBytes($"payloads/{name}.bin"), written);
    }

    [Fact]
    public void EveryReplyShapeMatchesItsFixture()
    {
        Matches(SwiftWire.WriteReply(), "reply-void");
        Matches(SwiftWire.WriteReply(SwiftWireValue.Of(true)), "reply-bool");
        Matches(SwiftWire.WriteReply(SwiftWireValue.Of(14, 45, 44, 123)), "reply-clock");
        Matches(SwiftWire.WriteReply(SwiftWireValue.Of("Europe/Warsaw")), "reply-text");
        Matches(
            SwiftWire.WriteFailure("a focus act has to say which view it is for"),
            "reply-failure");
    }

    [Fact]
    public void EveryPayloadShapeMatchesItsFixture()
    {
        Matches(SwiftWire.WritePayload(SwiftWireValue.Of("Hello, world")), "event-text");
        Matches(SwiftWire.WritePayload(SwiftWireValue.Of(true)), "event-toggle");
        Matches(SwiftWire.WritePayload(SwiftWireValue.Of(12.5)), "event-number");
        Matches(SwiftWire.WritePayload(SwiftWireValue.Of(0, 2)), "event-selection");
        Matches(SwiftWire.WritePayload(SwiftWireValue.Of()), "event-selection-empty");
        Matches(
            SwiftWire.WritePayload(
                SwiftWireValue.OfMember((int)SwiftGestureStatus.Running),
                SwiftWireValue.Of(12.5),
                SwiftWireValue.Of(-3)),
            "event-pan");
        Matches(
            SwiftWire.WritePayload(SwiftWireValue.Of(10, 20, 300, 400, 110, 220, 110, 176)),
            "event-frame");
        Matches(
            SwiftWire.WritePayload(
                SwiftWireValue.OfMember((int)SwiftWebNavigationResult.Success),
                SwiftWireValue.OfMember((int)SwiftWebNavigationEvent.NewPage),
                SwiftWireValue.Of("https://example.com/a,b")),
            "event-navigated");
    }

    /// <summary>
    /// And the host-raised event - the one buffer that carries a NAME,
    /// because no element stands behind it.
    /// </summary>
    [Fact]
    public void EveryHostEventShapeMatchesItsFixture()
    {
        Matches(
            SwiftWire.WriteHostEvent(
                "Gallery.BatteryChanged", SwiftWireValue.Of(0.87), SwiftWireValue.Of(true)),
            "host-event");
        Matches(SwiftWire.WriteHostEvent("Gallery.Ping"), "host-event-empty");
    }

    /// <summary>
    /// And the standard environment's pushes - the one buffer that carries a
    /// DOMAIN byte, <see cref="StateUIEnvironment"/>'s own numbers.
    /// </summary>
    [Fact]
    public void EveryEnvironmentShapeMatchesItsFixture()
    {
        Matches(
            SwiftWire.WriteEnvironment(
                Rendering.StateUIEnvironment.BatteryDomain,
                SwiftWireValue.Of(0.87),
                SwiftWireValue.OfMember((int)SwiftBatteryState.Charging),
                SwiftWireValue.OfMember((int)SwiftBatteryPowerSource.Ac),
                SwiftWireValue.OfMember((int)SwiftEnergySaverStatus.On)),
            "environment-battery");
        Matches(
            SwiftWire.WriteEnvironment(
                Rendering.StateUIEnvironment.LocaleDomain,
                SwiftWireValue.Of("pl"), SwiftWireValue.Of("PL"),
                SwiftWireValue.Of("pl-PL"), SwiftWireValue.Of("Europe/Warsaw"),
                SwiftWireValue.Of(true),
                SwiftWireValue.OfMember((int)SwiftWeekday.Monday),
                SwiftWireValue.Of(true)),
            "environment-locale");
    }

    /// <summary>
    /// The writer is deterministic to the byte: the same values twice are the
    /// same bytes twice. Nothing about a payload may depend on when or where
    /// it was written - that is what lets a fixture BE the contract.
    /// </summary>
    [Fact]
    public void TheSameValuesWriteTheSameBytesEveryTime()
    {
        byte[]? first = SwiftWire.WritePayload(
            SwiftWireValue.Of("text"), SwiftWireValue.Of(12.5), SwiftWireValue.Of(1, 2));
        byte[]? again = SwiftWire.WritePayload(
            SwiftWireValue.Of("text"), SwiftWireValue.Of(12.5), SwiftWireValue.Of(1, 2));

        Assert.Equal(first, again);
    }

    /// <summary>
    /// An event with nothing to say crosses no bytes at all - the common
    /// case, every tap, allocating nothing.
    /// </summary>
    [Fact]
    public void NoValuesIsNoPayload()
    {
        Assert.Null(SwiftWire.WritePayload());
    }

    /// <summary>
    /// Every payloads fixture some test in this class matches the writer
    /// against, by file name - the list <see cref="EveryFixtureIsMatched"/>
    /// holds the directory to.
    /// </summary>
    private static readonly string[] MatchedFixtures =
    [
        "environment-battery", "environment-locale", "event-frame",
        "event-navigated", "event-number", "event-pan", "event-selection",
        "event-selection-empty", "event-text", "event-toggle", "host-event",
        "host-event-empty", "reply-bool", "reply-clock", "reply-failure",
        "reply-text", "reply-void",
    ];

    /// <summary>
    /// A payloads fixture nothing here matches fails by name - the walk
    /// <c>ControlTests.EveryFixtureIsChecked</c> makes, over this directory.
    /// </summary>
    [Fact]
    public void EveryFixtureIsMatched()
    {
        foreach (string file in Directory.GetFiles(
            Path.Combine(Fixtures.Directory, "payloads"), "*.bin"))
        {
            string name = Path.GetFileNameWithoutExtension(file);

            Assert.True(MatchedFixtures.Contains(name),
                $"payloads/{name}.bin is authored by the Swift tests and matched by nothing here.");
        }
    }
}
