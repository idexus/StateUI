// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The channels this runtime WRITES - an act's reply, an event's payload, an
// event the host raised by name, an environment push, and what it realizes -
// held to the fixtures under fixtures/payloads.
//
// The direction is the reverse of every other fixture's: the Swift tests
// author these bytes with the library's own value encoding, the Swift library
// READS them, and this side asserts its WRITER produces exactly the same
// bytes for the same values. Writer and reader meet in the file, so neither
// can drift alone - and a review reads the .txt sidecar beside each.

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Tests;

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
        Matches(WireCodec.WriteReply(), "reply-void");
        Matches(WireCodec.WriteReply(HostValue.Of(true)), "reply-bool");
        Matches(WireCodec.WriteReply(HostValue.Of(14, 45, 44, 123)), "reply-clock");
        Matches(WireCodec.WriteReply(HostValue.Of("Europe/Warsaw")), "reply-text");
        Matches(
            WireCodec.WriteFailure("a focus act has to say which view it is for"),
            "reply-failure");

        // A reader who dismissed a dialog. The value IS the answer, so the
        // writer has to be able to write a nothing: without the arm it threw
        // where the reply is built, and the awaiting Swift handler - which has
        // no timeout by design - would never resume.
        Matches(
            WireCodec.WriteReply(new HostValue(HostValue.TagNothing)),
            "reply-nothing");
    }

    [Fact]
    public void EveryPayloadShapeMatchesItsFixture()
    {
        Matches(WireCodec.WritePayload(HostValue.Of("Hello, world")), "event-text");
        Matches(WireCodec.WritePayload(HostValue.Of(true)), "event-toggle");
        Matches(WireCodec.WritePayload(HostValue.Of(12.5)), "event-number");
        Matches(WireCodec.WritePayload(HostValue.Of(0, 2)), "event-selection");
        Matches(WireCodec.WritePayload(HostValue.Of()), "event-selection-empty");
        Matches(
            WireCodec.WritePayload(
                HostValue.OfMember((int)HostGesturePhase.Running),
                HostValue.Of(12.5),
                HostValue.Of(-3)),
            "event-pan");
        Matches(
            WireCodec.WritePayload(HostValue.Of(10, 20, 300, 400, 110, 220, 110, 176)),
            "event-frame");
        Matches(
            WireCodec.WritePayload(
                HostValue.OfMember((int)HostWebNavigationResult.Success),
                HostValue.OfMember((int)HostWebNavigationEvent.NewPage),
                HostValue.Of("https://example.com/a,b")),
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
            WireCodec.WriteHostEvent(
                "Gallery.BatteryChanged", HostValue.Of(0.87), HostValue.Of(true)),
            "host-event");
        Matches(WireCodec.WriteHostEvent("Gallery.Ping"), "host-event-empty");
    }

    /// <summary>
    /// And the standard environment's pushes - the one buffer that carries a
    /// DOMAIN byte, <see cref="StateUIEnvironment"/>'s own numbers.
    /// </summary>
    [Fact]
    public void EveryEnvironmentShapeMatchesItsFixture()
    {
        Matches(
            WireCodec.WriteEnvironment(
                Rendering.StateUIEnvironment.BatteryDomain,
                HostValue.Of(0.87),
                HostValue.OfMember((int)HostBatteryState.Charging),
                HostValue.OfMember((int)HostBatteryPowerSource.Ac),
                HostValue.OfMember((int)HostEnergySaverStatus.On)),
            "environment-battery");
        Matches(
            WireCodec.WriteEnvironment(
                Rendering.StateUIEnvironment.LocaleDomain,
                HostValue.Of("pl"), HostValue.Of("PL"),
                HostValue.Of("pl-PL"), HostValue.Of("Europe/Warsaw"),
                HostValue.Of(true),
                HostValue.OfMember((int)HostWeekday.Monday),
                HostValue.Of(true)),
            "environment-locale");
    }

    /// <summary>
    /// And what this host realizes - said once, at start-up, before any
    /// message: its elements, then its members, each sorted whatever order
    /// they were gathered in.
    /// </summary>
    [Fact]
    public void TheRealizationMatchesItsFixture()
    {
        Matches(
            WireCodec.WriteRealization(
                ["Label", "Gallery.TrafficLight"],
                [
                    ("Label", "Label", "maximumLines"),
                    ("Label", "FontElement", "fontSize"),
                    ("Gallery.TrafficLight", "Gallery.TrafficLight", "lampTapped"),
                ]),
            "realization");
    }

    /// <summary>
    /// The writer is deterministic to the byte: the same values twice are the
    /// same bytes twice. Nothing about a payload may depend on when or where
    /// it was written - that is what lets a fixture BE the contract.
    /// </summary>
    [Fact]
    public void TheSameValuesWriteTheSameBytesEveryTime()
    {
        byte[]? first = WireCodec.WritePayload(
            HostValue.Of("text"), HostValue.Of(12.5), HostValue.Of(1, 2));
        byte[]? again = WireCodec.WritePayload(
            HostValue.Of("text"), HostValue.Of(12.5), HostValue.Of(1, 2));

        Assert.Equal(first, again);
    }

    /// <summary>
    /// An event with nothing to say crosses no bytes at all - the common
    /// case, every tap, allocating nothing.
    /// </summary>
    [Fact]
    public void NoValuesIsNoPayload()
    {
        Assert.Null(WireCodec.WritePayload());
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
        "host-event-empty", "realization", "reply-bool", "reply-clock", "reply-failure",
        "reply-nothing", "reply-text", "reply-void",
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
