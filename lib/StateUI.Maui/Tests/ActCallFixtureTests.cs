// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The other half of fixtures/act-calls: batches the Swift tests wrote with the
// REAL typed calls, read here with the exact reader and accessors Perform
// uses - the view name at 0, the length two from the end, the easing last.
//
// This is the check neither suite can make alone: a side tested only against
// itself stays green when length and easing swap places on both at once,
// while every animation runs with a garbage duration.
// The `.bin` is the contract; the `.txt` beside it is the Swift probe's
// rendering, for the reviewer the bytes cannot serve.
using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace StateUI.Maui.Tests;

public class ActCallFixtureTests
{
    /// <summary>The one act a fixture carries, read as the session reads a batch.</summary>
    private static HostActCall One(string name)
    {
        List<HostActCall> calls = WireCodec.ReadActCalls(
            Fixtures.ReadBytes($"act-calls/{name}.bin"), new WireDictionary());

        return Assert.Single(calls);
    }

    [Fact]
    public void AskingTheTimeCarriesNothingButItsCompletion()
    {
        HostActCall call = One("Now");

        Assert.Equal("currentTime", call.Name);
        Assert.Empty(call.Arguments!);
        Assert.True(call.Completion < 0, "someone is waiting for the answer");
    }

    [Fact]
    public void AskingTheZoneCarriesNothingButItsCompletion()
    {
        HostActCall call = One("LocalZone");

        Assert.Equal("currentTimeZone", call.Name);
        Assert.Empty(call.Arguments!);
        Assert.True(call.Completion < 0, "someone is waiting for the answer");
    }

    /// <summary>
    /// The zone first, as the text someone wrote it as, and the day second, as
    /// the three numbers a <c>CalendarDate</c> is.
    /// </summary>
    /// <remarks>
    /// The zone is an IANA identifier a reader could have typed and this side
    /// hands straight to <c>TimeZoneInfo.FindSystemTimeZoneById</c>, so it is
    /// text; the day is built here out of its fields, no formatter on either
    /// side. <see cref="AskingForAnOffsetWithNoDayCarriesNothingWhereTheDayIs"/>
    /// is the other half of the pair.
    /// </remarks>
    [Fact]
    public void AskingForAnOffsetCarriesTheZoneThenTheDay()
    {
        HostActCall call = One("UtcOffset");

        Assert.Equal("utcOffset", call.Name);
        Assert.Equal("Europe/Warsaw", call.GetString(0));
        Assert.Equal([2026, 1, 15], call.GetNumbers(1));
        Assert.True(call.Completion < 0, "someone is waiting for the answer");
    }

    /// <summary>
    /// A day nobody asked about is NOTHING at argument 1, not a missing
    /// argument: the day KEEPS its place and reads as null here, which is what
    /// tells the host to answer for today.
    /// </summary>
    /// <remarks>
    /// The only fixture in the suite that carries the wire's own nothing, so it
    /// is what holds tag 12 to reading as absent through a typed accessor - the
    /// whole reason an absent argument stopped borrowing an empty string or a
    /// -1 to say so.
    /// </remarks>
    [Fact]
    public void AskingForAnOffsetWithNoDayCarriesNothingWhereTheDayIs()
    {
        HostActCall call = One("UtcOffsetToday");

        Assert.Equal("utcOffset", call.Name);
        Assert.Equal("Europe/Warsaw", call.GetString(0));
        Assert.Equal(2, call.Arguments!.Count);
        Assert.Null(call.GetNumbers(1));
        Assert.True(call.Completion < 0, "someone is waiting for the answer");
    }

    /// <summary>
    /// An alert carries three arguments: title, message and the dismissing
    /// caption.
    /// </summary>
    [Fact]
    public void AnAlertCarriesThreeArguments()
    {
        HostActCall call = One("Alert");

        Assert.Equal("alert", call.Name);
        Assert.Equal(3, call.Arguments!.Count);
        Assert.Equal("Saved", call.GetString(0));
        Assert.Equal("The draft is safe", call.GetString(1));
        Assert.Equal("OK", call.GetString(2));
        Assert.True(call.Completion < 0, "someone is waiting for the dismissal");
    }

    /// <summary>A confirmation: accept at 2, cancel at 3, MAUI's order.</summary>
    [Fact]
    public void AConfirmationCarriesAcceptBeforeCancel()
    {
        HostActCall call = One("Confirm");

        Assert.Equal("confirm", call.Name);
        Assert.Equal(4, call.Arguments!.Count);
        Assert.Equal("Delete draft?", call.GetString(0));
        Assert.Equal("This cannot be undone", call.GetString(1));
        Assert.Equal("Delete", call.GetString(2));
        Assert.Equal("Keep", call.GetString(3));
        Assert.True(call.Completion < 0, "someone is waiting for the answer");
    }

    /// <summary>
    /// Title, cancel, destruction, then every button - the params array read
    /// from position 3 to the end, exactly as Dialog() reads it.
    /// </summary>
    [Fact]
    public void AChoiceOfActionsCarriesItsCaptionsThenTheButtons()
    {
        HostActCall call = One("ChooseAction");

        Assert.Equal("chooseAction", call.Name);
        Assert.Equal("Share via", call.GetString(0));
        Assert.Equal("Cancel", call.GetString(1));
        Assert.Equal("Delete", call.GetString(2));
        Assert.Equal("Mail", call.GetString(3));
        Assert.Equal("Message", call.GetString(4));
        Assert.Equal(5, call.Arguments!.Count);
        Assert.True(call.Completion < 0, "someone is waiting for the choice");
    }

    /// <summary>
    /// All eight of MAUI's parameters in MAUI's order, the limit as a number,
    /// and the keyboard as a MEMBER of the same closed vocabulary the
    /// <c>keyboard</c> property carries - a number both sides give the member,
    /// never its name.
    /// </summary>
    /// <remarks>
    /// An absent limit would cross as NOTHING, which this side turns into
    /// MAUI's own -1; the sentinel is MAUI's and never the wire's. This fixture
    /// carries a limit, so the absence is
    /// <see cref="AskingForAnOffsetWithNoDayCarriesNothingWhereTheDayIs"/>'s to
    /// pin.
    /// </remarks>
    [Fact]
    public void APromptCarriesEveryParameterInMauisOrder()
    {
        HostActCall call = One("Prompt");

        Assert.Equal("prompt", call.Name);
        Assert.Equal("Rename", call.GetString(0));
        Assert.Equal("A new name for the draft", call.GetString(1));
        Assert.Equal("OK", call.GetString(2));
        Assert.Equal("Cancel", call.GetString(3));
        Assert.Equal("Name", call.GetString(4));
        Assert.Equal(40, call.GetInt(5));
        Assert.Equal(Keyboard.Text, SwiftValues.KeyboardOf(call.GetEnumeration(6)));
        Assert.Equal("Draft 1", call.GetString(7));
        Assert.True(call.Completion < 0, "someone is waiting for the text");
    }

    /// <summary>
    /// A focus act carries the view and nothing else, so the session's read is
    /// the one at 0 - the same place an animation keeps it.
    /// </summary>
    [Theory]
    [InlineData("Focus", "focus")]
    [InlineData("Unfocus", "unfocus")]
    public void AFocusActCarriesTheViewAndNothingElse(string fixture, string method)
    {
        HostActCall call = One(fixture);

        Assert.Equal(method, call.Name);
        Assert.Equal("email", call.GetString(0));
        Assert.Single(call.Arguments!);
        Assert.True(call.Completion < 0, "the handler is waiting for it");
    }

    /// <summary>
    /// An act on a control the author never NAMED aims with the element's
    /// NUMBER - the differ's identity, in the same argument 0 a name rides,
    /// so it reads as null through the string door and as the number through
    /// the number door, which is exactly how <c>TargetOf</c> tells the two
    /// namespaces apart.
    /// </summary>
    [Fact]
    public void AFocusActByElementNumberCarriesTheNumberNotAString()
    {
        HostActCall call = One("FocusByNumber");

        Assert.Equal("focus", call.Name);
        Assert.Null(call.GetString(0));
        Assert.Equal(7, call.GetDouble(0));
        Assert.Single(call.Arguments!);
        Assert.True(call.Completion < 0, "the handler is waiting for it");
    }

    /// <summary>
    /// Closing the keyboard names no view: the Swift side cannot know which
    /// control the reader touched last, so the page is asked instead. Its name
    /// is this library's own, MAUI having no method for the question - the two
    /// MAUI does have are the page property and Unfocus above.
    /// </summary>
    [Fact]
    public void ClosingTheKeyboardNamesNoViewAtAll()
    {
        HostActCall call = One("HideOnScreenKeyboard");

        Assert.Equal("hideOnScreenKeyboard", call.Name);
        Assert.Empty(call.Arguments!);
        Assert.True(call.Completion < 0, "the handler is waiting for the answer");
    }

    /// <summary>
    /// The three parameterless WebView acts carry the view and nothing else -
    /// the read Focus makes - and each is pinned by name.
    /// </summary>
    [Theory]
    [InlineData("WebViewGoBack", "goBack")]
    [InlineData("WebViewGoForward", "goForward")]
    [InlineData("WebViewReload", "reload")]
    public void AWebViewActCarriesTheViewAndNothingElse(string fixture, string method)
    {
        HostActCall call = One(fixture);

        Assert.Equal(method, call.Name);
        Assert.Equal("browser", call.GetString(0));
        Assert.Single(call.Arguments!);
        Assert.True(call.Completion < 0, "the handler is waiting for it to finish");
    }

    /// <summary>
    /// Running JavaScript adds the script at 1, which is exactly where
    /// <c>Perform</c> reads it - and the answer goes back in the result.
    /// </summary>
    [Fact]
    public void RunningJavaScriptCarriesTheViewThenTheScript()
    {
        HostActCall call = One("EvaluateJavaScript");

        Assert.Equal("evaluateJavaScript", call.Name);
        Assert.Equal("browser", call.GetString(0));
        Assert.Equal("document.title", call.GetString(1));
        Assert.True(call.Completion < 0, "the handler is waiting for the answer");
    }

    /// <summary>
    /// Moving a map carries the view, then latitude, longitude and the radius
    /// in METERS - the reads <c>MoveMap</c> makes, in that order, and the unit
    /// MAUI's <c>Distance</c> is at bottom.
    /// </summary>
    [Fact]
    public void MovingAMapCarriesTheViewThenThreeNumbers()
    {
        HostActCall call = One("MoveToRegion");

        Assert.Equal("moveToRegion", call.Name);
        Assert.Equal("map", call.GetString(0));
        Assert.Equal(52.2297, call.GetDouble(1));
        Assert.Equal(21.0122, call.GetDouble(2));
        Assert.Equal(3000, call.GetDouble(3));
        Assert.True(call.Completion < 0, "the handler is waiting for it to finish");
    }

    [Fact]
    public void AFailedHandlerCarriesItsMessageAndWaitsForNobody()
    {
        HostActCall call = One("HandlerFailed");

        Assert.Equal("handlerFailed", call.Name);
        Assert.Equal("boom", call.GetString(0));
        Assert.Null(call.Completion);
    }

    /// <summary>
    /// What the accessors answer for an index with no argument at it -
    /// including a negative one, which the tail-relative reads produce on an
    /// act shorter than they expect.
    /// </summary>
    /// <remarks>
    /// An index past the end and the wire's own NOTHING both read as null, and
    /// they are not the same thing: nothing is a value that was written, and
    /// <see cref="AskingForAnOffsetWithNoDayCarriesNothingWhereTheDayIs"/> is
    /// where the count proves it was.
    /// </remarks>
    [Fact]
    public void AnIndexWithNoArgumentAtItReadsAsNull()
    {
        HostActCall call = One("HideOnScreenKeyboard");

        Assert.Null(call.GetString(-1));
        Assert.Null(call.GetDouble(-1));
        Assert.Null(call.GetString(9));
        Assert.Null(call.GetDouble(9));
    }

    /// <summary>
    /// A NaN crosses as its own bits - the binary wire needs no null for it -
    /// and reads as "not a number", which is what makes the session refuse it
    /// rather than act on a zero nobody asked for. The bytes are
    /// hand-assembled here because no typed call ever writes one on purpose.
    /// </summary>
    [Fact]
    public void ANaNArgumentIsNotANumber()
    {
        List<byte> bytes = [WireCodec.Version];

        void Str(string text)
        {
            bytes.AddRange(BitConverter.GetBytes((uint)text.Length));
            bytes.InsertRange(bytes.Count, System.Text.Encoding.UTF8.GetBytes(text));
        }

        bytes.AddRange([1, 0]);         // one announcement:
        bytes.AddRange([1, 0]);         // name #1 is
        Str("scrollToAsync"); // the act being asked for

        bytes.AddRange([1, 0]);         // one act
        bytes.AddRange([1, 0]);         // name #1
        bytes.AddRange([0xFF, 0xFF, 0xFF, 0xFF]);  // completion -1
        bytes.Add(4);                   // four arguments

        bytes.Add(4); Str("card");
        bytes.Add(3); bytes.AddRange(BitConverter.GetBytes(double.NaN));
        bytes.Add(3); bytes.AddRange(BitConverter.GetBytes(250.0));
        bytes.Add(4); Str("linear");

        HostActCall call = Assert.Single(
            WireCodec.ReadActCalls([.. bytes], new WireDictionary()));

        Assert.Equal("scrollToAsync", call.Name);
        Assert.Null(call.GetDouble(1));
        Assert.Equal(250, call.GetDouble(2));
    }

    /// <summary>
    /// A batch that ends mid-value throws rather than answering something
    /// partial - which is what makes the session cash the receipt and fail
    /// every act in it back to its awaiting handler.
    /// </summary>
    [Fact]
    public void ATruncatedBatchThrowsInsteadOfAnsweringPartially()
    {
        byte[] whole = Fixtures.ReadBytes("act-calls/Confirm.bin");

        Assert.Throws<InvalidDataException>(
            () => WireCodec.ReadActCalls(
                whole.AsSpan(0, whole.Length - 3).ToArray(), new WireDictionary()));
    }

    /// <summary>
    /// An id no message ever announced is a protocol error, not a name: the
    /// batch is refused whole, the session cashes the receipt, and every act
    /// in it fails back to its awaiting handler with the reason - never a
    /// quiet misread. The write side makes this unreachable by construction;
    /// the refusal is what makes it survivable anyway.
    /// </summary>
    [Fact]
    public void AnUnannouncedNameRefusesTheBatch()
    {
        byte[] bytes =
        [
            WireCodec.Version,
            0, 0,               // no announcements
            1, 0,               // one act
            0xE7, 0x03,         // name #999, which nothing announced
            0, 0, 0, 0,         // no completion
            0,                  // no arguments
        ];

        Assert.Throws<InvalidDataException>(
            () => WireCodec.ReadActCalls(bytes, new WireDictionary()));
    }

    /// <summary>
    /// Every act-calls fixture some test in this class reads, by file name -
    /// the list <see cref="EveryFixtureIsRead"/> holds the directory to.
    /// </summary>
    private static readonly string[] ReadFixtures =
    [
        "Alert", "ChooseAction", "Confirm",
        "Prompt", "EvaluateJavaScript", "Focus", "FocusByNumber",
        "HandlerFailed", "HideOnScreenKeyboard", "LocalZone", "MoveToRegion", "Now",
        "Unfocus", "UtcOffset", "UtcOffsetToday",
        "WebViewGoBack", "WebViewGoForward", "WebViewReload",
    ];

    /// <summary>
    /// An act-calls fixture nothing here reads fails by name - the walk
    /// <c>ControlTests.EveryFixtureIsChecked</c> makes, over this directory.
    /// </summary>
    [Fact]
    public void EveryFixtureIsRead()
    {
        foreach (string file in Directory.GetFiles(
            Path.Combine(Fixtures.Directory, "act-calls"), "*.bin"))
        {
            string name = Path.GetFileNameWithoutExtension(file);

            Assert.True(ReadFixtures.Contains(name),
                $"act-calls/{name}.bin is written by the Swift tests and read by nothing here.");
        }
    }
}
