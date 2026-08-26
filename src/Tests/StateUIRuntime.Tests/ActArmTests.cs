// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The acts, PERFORMED - the arms themselves, not the bytes that name them.
//
// CommandFixtureTests reads the same fixtures and stops at the SwiftCommand:
// the name, the arguments, the completion id. What happened next - the switch
// in StateUISession.Perform, twenty-three arms of it, the refusal sentences,
// the catch blocks - had never executed in a test in either language. A whole
// half of the runtime was reachable only from a device.
//
// What made it unreachable was not the session: `StateUIApplication` builds
// one on every MultiWindowTests run. It was that every way IN and OUT of the
// act loop is a static P/Invoke. The way in is `PerformCommands`, which reads a
// native buffer and frees it - so the batch is handed to `Perform(commands)`
// instead, read from the very fixtures Swift wrote. The way out is the reply,
// which resumes a Swift handler that does not exist here - so `Replies` is
// substituted and the test reads what the arm answered.
//
// WHAT THESE DO NOT PROVE, and it matters: not the marshalling. The `out int
// length`, the pinning, who owns which pointer - all of that is the real
// boundary and stays device-only. A green run here says the ARM is right, never
// that a native build is.
//
// The failures a target collects are ignored on purpose: after a reply the
// session pumps, the pump reaches the native library, and there is none. That
// is honest for a headless session and is not what any of these is about.

using Microsoft.Maui.Dispatching;
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;
using Xunit;

namespace StateUI.Runtime.Tests;

/// <summary>
/// A target that draws nothing and remembers what it was told - enough for the
/// act loop, which never renders.
/// </summary>
internal sealed class RecordingTarget : IStateUITarget
{
    /// <summary>Every diagnostic the session raised.</summary>
    internal List<string> Failures { get; } = [];

    /// <summary>No platform underneath, which is what a null dispatcher means
    /// and what makes the thread check pass.</summary>
    public IDispatcher? Dispatcher => null;

    /// <summary>Accepts anything; these tests never render.</summary>
    public bool Apply(SwiftNode application, bool complete) => true;

    /// <summary>Remembers the diagnostic.</summary>
    public void Fail(string message, Exception? exception) => Failures.Add(message);
}

public class ActArmTests
{
    /// <summary>The zone `commands/UtcOffset.bin` asks about.</summary>
    private const string FixtureZone = "Europe/Warsaw";

    /// <summary>The day it asks about, at NOON - which is the contract, not a
    /// convenience: a date read at midnight lands on the wrong side of a
    /// daylight change in the zones where one falls that night.</summary>
    private static readonly DateTime FixtureNoon = new(2026, 1, 15, 12, 0, 0);

    /// <summary>
    /// What one arm answered: the completion id it went to, and the BYTES.
    /// </summary>
    /// <remarks>
    /// Bytes rather than a decoded value, and deliberately: the C# side has a
    /// writer and no reader for a reply - Swift is the only thing that reads
    /// one - so a decoder here would be a second implementation of the format
    /// with nothing checking it against the first. Comparing against
    /// <c>SwiftWire.WriteReply(...)</c> asks the question that matters and asks
    /// it of the writer that ships.
    /// </remarks>
    /// <param name="fixture">The `fixtures/commands` batch to perform.</param>
    /// <param name="shown">What is ON SCREEN while it runs: each view is
    /// tracked under its node's id first, exactly as a render leaves it - a
    /// string id in the named map, a numeric one in the identity map.</param>
    private static (int Completion, byte[] Reply) Answer(
        string fixture, params (VisualElement View, string Node)[] shown)
    {
        List<(int, byte[])> replies = [];

        StateUISession session = new(new RecordingTarget())
        {
            Replies = (id, reply) => replies.Add((id, reply)),
        };

        foreach ((VisualElement view, string node) in shown)
        {
            session.Renderer.Track(view, Host.Parse(node));
        }

        session.Perform(SwiftWire.ReadCommands(
            Fixtures.ReadBytes($"commands/{fixture}.bin"), new SwiftWireDictionary()));

        return replies.Count == 0 ? (0, []) : replies[0];
    }

    // ---- The three the whole dates contract rests on ------------------------

    /// <summary>
    /// The host's clock crosses as four numbers - hour, minute, second,
    /// millisecond - which is what `ClockTime.now()` reads on four platforms.
    /// </summary>
    [Fact]
    public void TheClockCrossesAsFourNumbers()
    {
        (int completion, byte[] reply) = Answer("Now");

        Assert.True(completion < 0, "someone was awaiting it");

        // ONE value, which is a LIST of four numbers - not four values, and
        // that distinction is the arm's whole shape. Pinned against the writer
        // rather than against byte indices written down here: same length, same
        // answered flag, same count as a four-number list this side builds.
        // The numbers themselves are the clock's and cannot be foreseen.
        byte[] shape = SwiftWire.WriteReply(SwiftWireValue.Of([0.0, 0.0, 0.0, 0.0]));

        Assert.Equal(shape.Length, reply.Length);
        Assert.Equal(shape[1], reply[1]);
        Assert.Equal(shape[2], reply[2]);
    }

    /// <summary>
    /// The zone is named the IANA way whatever the host calls it - which is the
    /// whole reason this act exists, Windows spelling its zones differently.
    /// </summary>
    [Fact]
    public void TheZoneIsNamedTheIanaWay()
    {
        (_, byte[] reply) = Answer("LocalZone");

        // Not compared against a hardcoded zone - this runs on whatever machine
        // it runs on. What is pinned is that the answer is the one the host's
        // own conversion produces, so a Windows agent asserts the same thing.
        TimeZoneInfo local = TimeZoneInfo.Local;
        string expected = local.HasIanaId
            ? local.Id
            : TimeZoneInfo.TryConvertWindowsIdToIanaId(local.Id, out string? iana) ? iana : local.Id;

        Assert.Equal(SwiftWire.WriteReply(SwiftWireValue.Of(expected)), reply);
    }

    /// <summary>
    /// The offset is read at NOON of the day asked about, signed, in minutes -
    /// the contract that keeps TimeZoneInfo.getUtcOffset(of:on:) answering the
    /// same on all four platforms: zones and locale are the host's to answer
    /// (README, "Dates, times and Foundation").
    /// </summary>
    [Fact]
    public void TheOffsetIsReadAtNoonOfTheDayAsked()
    {
        (_, byte[] reply) = Answer("UtcOffset");

        // The zone and the day are the FIXTURE's; the expected offset is read
        // from the host rather than written down, so the assertion says "the
        // arm agrees with .NET" rather than "the arm agrees with me". Noon is
        // the contract: a date read at midnight lands on the wrong side of a
        // daylight change.
        TimeZoneInfo zone = TimeZoneInfo.FindSystemTimeZoneById(FixtureZone);
        double expected = zone.GetUtcOffset(FixtureNoon).TotalMinutes;

        Assert.Equal(SwiftWire.WriteReply(SwiftWireValue.Of(expected)), reply);
    }

    // ---- What happens when nobody is waiting, and when nobody knows ---------

    /// <summary>
    /// A handler's escaped error is REPORTED and answers nobody: it carries no
    /// completion, so nothing may be dispatched back.
    /// </summary>
    [Fact]
    public void AFailedHandlerAnswersNobody()
    {
        (int completion, byte[] reply) = Answer("HandlerFailed");

        Assert.Equal(0, completion);
        Assert.Empty(reply);
    }

    /// <summary>
    /// An act this runtime has no case for - and no application registered -
    /// answers the awaiting handler with a FAILURE rather than a silence.
    /// </summary>
    [Fact]
    public void AnUnknownActAnswersTheCompletionWithAReason()
    {
        (int completion, byte[] reply) = Perform("Gallery.NobodyRegisteredThis", -7);

        Assert.Equal(-7, completion);

        // A failure is [version][0 = refused][1][the reason], so byte 1 is what
        // tells a refusal from an answer, and an empty ANSWER from one.
        Assert.NotEmpty(reply);
        Assert.Equal(0, reply[1]);
        Assert.NotEqual(SwiftWire.WriteReply(), reply);
    }

    /// <summary>
    /// A registered act is found BEFORE the unknown arm - which is what makes a
    /// registration impossible to shadow a library act with, and what an
    /// application's own acts ride on.
    /// </summary>
    [Fact]
    public void ARegisteredActAnswersBeforeTheUnknownArm()
    {
        StateUIActs.Add("Gallery.AnsweredByTheApp", _ => [SwiftWireValue.Of(42.0)]);

        (int completion, byte[] reply) = Perform("Gallery.AnsweredByTheApp", -9);

        Assert.Equal(-9, completion);
        Assert.Equal(SwiftWire.WriteReply(SwiftWireValue.Of(42.0)), reply);
    }

    // ---- Aiming an act at a view on screen ----------------------------------
    //
    // The refusals compare BYTES against WriteFailure of the exact sentence,
    // because the sentence is the whole answer: it is what the Swift
    // `try await` throws, and the only thing telling a stale handle from a
    // wrong aim. EvaluateJavaScript never runs against a PRESENT WebView here:
    // MAUI completes it from the platform handler, which a headless control
    // has none of, so the await would suspend this test forever - the very
    // trap the Scroll arm's handler check exists for.

    /// <summary>
    /// A WebView act reaches the control named at argument 0 and answers
    /// nothing - GoBack is a MAUI method without a result - so what says
    /// "performed" is an empty reply that is a SUCCESS, not a failure.
    /// </summary>
    [Fact]
    public void AWebViewActDrivesTheControlItNames()
    {
        (int completion, byte[] reply) = Answer(
            "WebViewGoBack", (new WebView(), """{"id":"browser","type":"WebView"}"""));

        Assert.Equal(-1, completion);
        Assert.Equal(SwiftWire.WriteReply(), reply);
    }

    /// <summary>
    /// A view nobody is showing refuses with the name the author aimed with -
    /// a name is quoted the way the author wrote it.
    /// </summary>
    [Fact]
    public void AWebViewActNamingNothingOnScreenIsRefused()
    {
        (int completion, byte[] reply) = Answer("EvaluateJavaScript");

        Assert.Equal(-1, completion);
        Assert.Equal(
            SwiftWire.WriteFailure("there is no view called 'browser' on screen"), reply);
    }

    /// <summary>
    /// A view of another type is a FAILURE rather than a silence - an act that
    /// does nothing looks exactly like a page with no history - and the
    /// sentence says what the view actually is.
    /// </summary>
    [Fact]
    public void AWebViewActAimedAtAnotherControlIsRefused()
    {
        (_, byte[] reply) = Answer(
            "WebViewReload", (new Label(), """{"id":"browser","type":"Label"}"""));

        Assert.Equal(
            SwiftWire.WriteFailure("the view called 'browser' is a Label, not a WebView"), reply);
    }

    /// <summary>
    /// An aimed act whose argument 0 is neither a name nor a number cannot say
    /// which view it is for, and is refused rather than guessed at.
    /// </summary>
    [Fact]
    public void AWebViewActWithNoTargetIsRefused()
    {
        (int completion, byte[] reply) =
            Perform(new SwiftCommand(SwiftAct.GoBack, "goBack", [], -3));

        Assert.Equal(-3, completion);
        Assert.Equal(
            SwiftWire.WriteFailure("a WebView act has to say which view it is for"), reply);
    }

    /// <summary>
    /// MoveToRegion reaches the Map named at argument 0: the empty reply is
    /// the arm having found it, checked its type, read the three numbers and
    /// made MAUI's call without throwing.
    /// </summary>
    [Fact]
    public void MoveToRegionSlidesTheMapItNames()
    {
        (int completion, byte[] reply) = Answer(
            "MoveToRegion",
            (new Microsoft.Maui.Controls.Maps.Map(), """{"id":"map","type":"Map"}"""));

        Assert.Equal(-1, completion);
        Assert.Equal(SwiftWire.WriteReply(), reply);
    }

    [Fact]
    public void MoveToRegionNamingNothingOnScreenIsRefused()
    {
        (_, byte[] reply) = Answer("MoveToRegion");

        Assert.Equal(
            SwiftWire.WriteFailure("there is no view called 'map' on screen"), reply);
    }

    [Fact]
    public void MoveToRegionAimedAtAnotherControlIsRefused()
    {
        (_, byte[] reply) = Answer(
            "MoveToRegion", (new Label(), """{"id":"map","type":"Label"}"""));

        Assert.Equal(
            SwiftWire.WriteFailure("the view called 'map' is a Label, not a Map"), reply);
    }

    /// <summary>
    /// A scroller that is not ATTACHED is reported done without calling: MAUI
    /// completes ScrollToAsync from the platform handler, which a headless
    /// scroller has none of, and awaiting it would suspend the Swift handler
    /// forever with nothing anywhere saying why.
    /// </summary>
    [Fact]
    public void ScrollingADetachedScrollerIsReportedDone()
    {
        (int completion, byte[] reply) = Answer(
            "ScrollViewScrollTo",
            (new ScrollView(), """{"id":"scroller","type":"ScrollView"}"""));

        Assert.Equal(-1, completion);
        Assert.Equal(SwiftWire.WriteReply(), reply);
    }

    [Fact]
    public void ScrollToNamingNothingOnScreenIsRefused()
    {
        (_, byte[] reply) = Answer("ScrollViewScrollTo");

        Assert.Equal(
            SwiftWire.WriteFailure("there is no view called 'scroller' on screen"), reply);
    }

    [Fact]
    public void ScrollToAimedAtAnotherControlIsRefused()
    {
        (_, byte[] reply) = Answer(
            "ScrollViewScrollTo", (new Label(), """{"id":"scroller","type":"Label"}"""));

        Assert.Equal(
            SwiftWire.WriteFailure("the view called 'scroller' is a Label, not a ScrollView"),
            reply);
    }

    /// <summary>
    /// An aimed focus answers MAUI's OWN answer, and a view with no platform
    /// underneath says no - which crosses as a VALUE, not a failure: a view
    /// refusing the focus is an ordinary outcome.
    /// </summary>
    [Fact]
    public void AnAimedFocusAnswersWhetherTheViewTookIt()
    {
        (int completion, byte[] reply) = Answer(
            "Focus", (new Entry(), """{"id":"email","type":"Entry"}"""));

        Assert.Equal(-1, completion);
        Assert.Equal(SwiftWire.WriteReply(SwiftWireValue.Of(false)), reply);
    }

    [Fact]
    public void AnAimedFocusNamingNothingOnScreenIsRefused()
    {
        (_, byte[] reply) = Answer("Focus");

        Assert.Equal(
            SwiftWire.WriteFailure("there is no view called 'email' on screen"), reply);
    }

    /// <summary>
    /// A numeric argument 0 aims through the identity map - the namespace a
    /// ControlState uses - so an unnamed control is still reachable.
    /// </summary>
    [Fact]
    public void AFocusAimedByIdentityFindsTheTrackedControl()
    {
        (int completion, byte[] reply) = Answer(
            "FocusByNumber", (new Entry(), """{"id":7,"type":"Entry"}"""));

        Assert.Equal(-1, completion);
        Assert.Equal(SwiftWire.WriteReply(SwiftWireValue.Of(false)), reply);
    }

    /// <summary>
    /// A missing identity is named the way it was aimed - "#7", never a quoted
    /// name - so the thrown message says which HANDLE went stale.
    /// </summary>
    [Fact]
    public void AFocusAimedAtAnIdentityGoneNamesItByNumber()
    {
        (_, byte[] reply) = Answer("FocusByNumber");

        Assert.Equal(SwiftWire.WriteFailure("there is no view #7 on screen"), reply);
    }

    /// <summary>
    /// An act by NAME, for the two no fixture carries - an unregistered one
    /// and an application's own.
    /// </summary>
    private static (int Completion, byte[] Reply) Perform(string act, int completion) =>
        Perform(new SwiftCommand(SwiftAct.None, act, [], completion));

    /// <summary>
    /// One act, assembled by hand rather than read from a fixture - for what
    /// no fixture can carry, such as an aimed act with its target left out.
    /// </summary>
    private static (int Completion, byte[] Reply) Perform(SwiftCommand command)
    {
        List<(int, byte[])> replies = [];

        StateUISession session = new(new RecordingTarget())
        {
            Replies = (id, reply) => replies.Add((id, reply)),
        };

        session.Perform([command]);

        return replies.Count == 0 ? (0, []) : replies[0];
    }
}
