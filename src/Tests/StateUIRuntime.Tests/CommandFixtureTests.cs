// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The other half of fixtures/commands: batches the Swift tests wrote with the
// REAL typed calls, read here with the exact reader and accessors Perform
// uses - the view name at 0, the length two from the end, the easing last.
//
// This is the check neither suite can make alone: a side tested only against
// itself stays green when length and easing swap places on both at once,
// while every animation runs with a garbage duration.
// The `.bin` is the contract; the `.txt` beside it is the Swift probe's
// rendering, for the reviewer the bytes cannot serve.
using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class CommandFixtureTests
{
    /// <summary>The one command a fixture carries, read as the session reads a batch.</summary>
    private static SwiftCommand One(string name)
    {
        List<SwiftCommand> commands = SwiftWire.ReadCommands(
            Fixtures.ReadBytes($"commands/{name}.bin"), new SwiftWireDictionary());

        return Assert.Single(commands);
    }

    [Fact]
    public void AskingTheTimeCarriesNothingButItsCompletion()
    {
        SwiftCommand command = One("Now");

        Assert.Equal("dateTimeNow", command.Name);
        Assert.Empty(command.Arguments!);
        Assert.True(command.Completion < 0, "someone is waiting for the answer");
    }

    [Fact]
    public void AskingTheZoneCarriesNothingButItsCompletion()
    {
        SwiftCommand command = One("LocalZone");

        Assert.Equal("localTimeZone", command.Name);
        Assert.Empty(command.Arguments!);
        Assert.True(command.Completion < 0, "someone is waiting for the answer");
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
        SwiftCommand command = One("UtcOffset");

        Assert.Equal("getUtcOffset", command.Name);
        Assert.Equal("Europe/Warsaw", command.GetString(0));
        Assert.Equal([2026, 1, 15], command.GetNumbers(1));
        Assert.True(command.Completion < 0, "someone is waiting for the answer");
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
        SwiftCommand command = One("UtcOffsetToday");

        Assert.Equal("getUtcOffset", command.Name);
        Assert.Equal("Europe/Warsaw", command.GetString(0));
        Assert.Equal(2, command.Arguments!.Count);
        Assert.Null(command.GetNumbers(1));
        Assert.True(command.Completion < 0, "someone is waiting for the answer");
    }

    /// <summary>
    /// The one-button alert is told apart from the question by its COUNT -
    /// three arguments, title, message and the dismissing caption.
    /// </summary>
    [Fact]
    public void AnInformingAlertCarriesThreeArguments()
    {
        SwiftCommand command = One("DisplayAlertOneButton");

        Assert.Equal("displayAlertAsync", command.Name);
        Assert.Equal(3, command.Arguments!.Count);
        Assert.Equal("Saved", command.GetString(0));
        Assert.Equal("The draft is safe", command.GetString(1));
        Assert.Equal("OK", command.GetString(2));
        Assert.True(command.Completion < 0, "someone is waiting for the dismissal");
    }

    /// <summary>The question form: accept at 2, cancel at 3, MAUI's order.</summary>
    [Fact]
    public void AQuestionAlertCarriesAcceptBeforeCancel()
    {
        SwiftCommand command = One("DisplayAlert");

        Assert.Equal("displayAlertAsync", command.Name);
        Assert.Equal(4, command.Arguments!.Count);
        Assert.Equal("Delete draft?", command.GetString(0));
        Assert.Equal("This cannot be undone", command.GetString(1));
        Assert.Equal("Delete", command.GetString(2));
        Assert.Equal("Keep", command.GetString(3));
        Assert.True(command.Completion < 0, "someone is waiting for the answer");
    }

    /// <summary>
    /// Title, cancel, destruction, then every button - the params array read
    /// from position 3 to the end, exactly as Dialog() reads it.
    /// </summary>
    [Fact]
    public void AnActionSheetCarriesItsCaptionsThenTheButtons()
    {
        SwiftCommand command = One("DisplayActionSheet");

        Assert.Equal("displayActionSheetAsync", command.Name);
        Assert.Equal("Share via", command.GetString(0));
        Assert.Equal("Cancel", command.GetString(1));
        Assert.Equal("Delete", command.GetString(2));
        Assert.Equal("Mail", command.GetString(3));
        Assert.Equal("Message", command.GetString(4));
        Assert.Equal(5, command.Arguments!.Count);
        Assert.True(command.Completion < 0, "someone is waiting for the choice");
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
        SwiftCommand command = One("DisplayPrompt");

        Assert.Equal("displayPromptAsync", command.Name);
        Assert.Equal("Rename", command.GetString(0));
        Assert.Equal("A new name for the draft", command.GetString(1));
        Assert.Equal("OK", command.GetString(2));
        Assert.Equal("Cancel", command.GetString(3));
        Assert.Equal("Name", command.GetString(4));
        Assert.Equal(40, command.GetInt(5));
        Assert.Equal(Keyboard.Text, SwiftValues.KeyboardOf(command.GetEnumeration(6)));
        Assert.Equal("Draft 1", command.GetString(7));
        Assert.True(command.Completion < 0, "someone is waiting for the text");
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
        SwiftCommand command = One(fixture);

        Assert.Equal(method, command.Name);
        Assert.Equal("email", command.GetString(0));
        Assert.Single(command.Arguments!);
        Assert.True(command.Completion < 0, "the handler is waiting for it");
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
        SwiftCommand command = One("FocusByNumber");

        Assert.Equal("focus", command.Name);
        Assert.Null(command.GetString(0));
        Assert.Equal(7, command.GetDouble(0));
        Assert.Single(command.Arguments!);
        Assert.True(command.Completion < 0, "the handler is waiting for it");
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
        SwiftCommand command = One("HideSoftInput");

        Assert.Equal("hideSoftInput", command.Name);
        Assert.Empty(command.Arguments!);
        Assert.True(command.Completion < 0, "the handler is waiting for the answer");
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
        SwiftCommand command = One(fixture);

        Assert.Equal(method, command.Name);
        Assert.Equal("browser", command.GetString(0));
        Assert.Single(command.Arguments!);
        Assert.True(command.Completion < 0, "the handler is waiting for it to finish");
    }

    /// <summary>
    /// Running JavaScript adds the script at 1, which is exactly where
    /// <c>Perform</c> reads it - and the answer goes back in the result.
    /// </summary>
    [Fact]
    public void RunningJavaScriptCarriesTheViewThenTheScript()
    {
        SwiftCommand command = One("EvaluateJavaScript");

        Assert.Equal("evaluateJavaScriptAsync", command.Name);
        Assert.Equal("browser", command.GetString(0));
        Assert.Equal("document.title", command.GetString(1));
        Assert.True(command.Completion < 0, "the handler is waiting for the answer");
    }

    /// <summary>
    /// Moving a map carries the view, then latitude, longitude and the radius
    /// in METERS - the reads <c>MoveMap</c> makes, in that order, and the unit
    /// MAUI's <c>Distance</c> is at bottom.
    /// </summary>
    [Fact]
    public void MovingAMapCarriesTheViewThenThreeNumbers()
    {
        SwiftCommand command = One("MoveToRegion");

        Assert.Equal("moveToRegion", command.Name);
        Assert.Equal("map", command.GetString(0));
        Assert.Equal(52.2297, command.GetDouble(1));
        Assert.Equal(21.0122, command.GetDouble(2));
        Assert.Equal(3000, command.GetDouble(3));
        Assert.True(command.Completion < 0, "the handler is waiting for it to finish");
    }

    /// <summary>
    /// A ScrollView's offset scroll: the view at 0, then x, y, and whether to
    /// animate - the reads <c>Scroll</c> makes, in ScrollToAsync's own order.
    /// </summary>
    [Fact]
    public void ScrollingToAnOffsetCarriesTheViewTwoOffsetsAndAnimated()
    {
        SwiftCommand command = One("ScrollViewScrollTo");

        Assert.Equal("scrollToAsync", command.Name);
        Assert.Equal("scroller", command.GetString(0));
        Assert.Equal(0, command.GetDouble(1));
        Assert.Equal(400, command.GetDouble(2));
        Assert.False(command.GetBool(3));
        Assert.True(command.Completion < 0, "the handler waits for the glide to finish");
    }


    [Fact]
    public void AFailedHandlerCarriesItsMessageAndWaitsForNobody()
    {
        SwiftCommand command = One("HandlerFailed");

        Assert.Equal("handlerFailed", command.Name);
        Assert.Equal("boom", command.GetString(0));
        Assert.Null(command.Completion);
    }

    /// <summary>
    /// What the accessors answer for an index with no argument at it -
    /// including a negative one, which the tail-relative reads produce on a
    /// command shorter than they expect.
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
        SwiftCommand command = One("HideSoftInput");

        Assert.Null(command.GetString(-1));
        Assert.Null(command.GetDouble(-1));
        Assert.Null(command.GetString(9));
        Assert.Null(command.GetDouble(9));
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
        List<byte> bytes = [SwiftWire.Version];

        void Str(string text)
        {
            bytes.AddRange(BitConverter.GetBytes((uint)text.Length));
            bytes.InsertRange(bytes.Count, System.Text.Encoding.UTF8.GetBytes(text));
        }

        bytes.AddRange([1, 0]);         // one announcement:
        bytes.AddRange([1, 0]);         // name #1 is
        Str("scrollToAsync"); // the act being asked for

        bytes.AddRange([1, 0]);         // one command
        bytes.AddRange([1, 0]);         // name #1
        bytes.AddRange([0xFF, 0xFF, 0xFF, 0xFF]);  // completion -1
        bytes.Add(4);                   // four arguments

        bytes.Add(4); Str("card");
        bytes.Add(3); bytes.AddRange(BitConverter.GetBytes(double.NaN));
        bytes.Add(3); bytes.AddRange(BitConverter.GetBytes(250.0));
        bytes.Add(4); Str("linear");

        SwiftCommand command = Assert.Single(
            SwiftWire.ReadCommands([.. bytes], new SwiftWireDictionary()));

        Assert.Equal("scrollToAsync", command.Name);
        Assert.Null(command.GetDouble(1));
        Assert.Equal(250, command.GetDouble(2));
    }

    /// <summary>
    /// A batch that ends mid-value throws rather than answering something
    /// partial - which is what makes the session cash the receipt and fail
    /// every act in it back to its awaiting handler.
    /// </summary>
    [Fact]
    public void ATruncatedBatchThrowsInsteadOfAnsweringPartially()
    {
        byte[] whole = Fixtures.ReadBytes("commands/DisplayAlert.bin");

        Assert.Throws<InvalidDataException>(
            () => SwiftWire.ReadCommands(
                whole.AsSpan(0, whole.Length - 3).ToArray(), new SwiftWireDictionary()));
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
            SwiftWire.Version,
            0, 0,               // no announcements
            1, 0,               // one command
            0xE7, 0x03,         // name #999, which nothing announced
            0, 0, 0, 0,         // no completion
            0,                  // no arguments
        ];

        Assert.Throws<InvalidDataException>(
            () => SwiftWire.ReadCommands(bytes, new SwiftWireDictionary()));
    }

    /// <summary>
    /// Every commands fixture some test in this class reads, by file name -
    /// the list <see cref="EveryFixtureIsRead"/> holds the directory to.
    /// </summary>
    private static readonly string[] ReadFixtures =
    [
        "DisplayActionSheet", "DisplayAlert", "DisplayAlertOneButton",
        "DisplayPrompt", "EvaluateJavaScript", "Focus", "FocusByNumber",
        "HandlerFailed", "HideSoftInput", "LocalZone", "MoveToRegion", "Now",
        "ScrollViewScrollTo", "Unfocus", "UtcOffset", "UtcOffsetToday",
        "WebViewGoBack", "WebViewGoForward", "WebViewReload",
    ];

    /// <summary>
    /// A commands fixture nothing here reads fails by name - the walk
    /// <c>ControlTests.EveryFixtureIsChecked</c> makes, over this directory.
    /// </summary>
    [Fact]
    public void EveryFixtureIsRead()
    {
        foreach (string file in Directory.GetFiles(
            Path.Combine(Fixtures.Directory, "commands"), "*.bin"))
        {
            string name = Path.GetFileNameWithoutExtension(file);

            Assert.True(ReadFixtures.Contains(name),
                $"commands/{name}.bin is written by the Swift tests and read by nothing here.");
        }
    }
}
