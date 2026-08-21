// The two halves, checked against the same files.
//
// `src/Tests/fixtures/*.bin` are written by the Swift tests and read here: the
// messages one side produces, applied by the other - the `.txt` beside each is
// the probe's rendering, for the reviewer the bytes cannot serve. If the
// format changes on purpose, the Swift test is run with
// STATEUI_UPDATE_FIXTURES=1 and these start exercising the new shape. If it
// changes by accident, one side or the other stops passing.

using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Tests;

public class FixtureTests
{
    private static byte[] Read(string name) => Fixtures.ReadBytes(name);

    [Fact]
    public void TheFirstMessageBuildsTheWholeTree()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("first-render.bin"));

        Assert.Equal(3, stack.Children.Count);
        Assert.Equal(20, stack.Spacing);

        Assert.Equal("Count: 0", ((Label)stack.Children[0]).Text);
        Assert.Equal(20, ((Label)stack.Children[0]).FontSize);
        Assert.Equal("Increment", ((Button)stack.Children[1]).Text);

        var rows = (VerticalStackLayout)stack.Children[2];
        Assert.Equal(["a", "b"], rows.Children.Cast<Label>().Select(l => l.Text));
    }

    [Fact]
    public void TheSecondMessageTouchesOneLabelAndNothingElse()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("first-render.bin"));
        var counter = (Label)stack.Children[0];
        var button = stack.Children[1];
        var rows = (VerticalStackLayout)stack.Children[2];
        var firstRow = rows.Children[0];

        host.ApplyMessage(Read("counter-changed.bin"));

        Assert.Equal("Count: 1", counter.Text);
        Assert.Same(button, stack.Children[1]);
        Assert.Same(firstRow, rows.Children[0]);
        Assert.Equal(20, counter.FontSize);
    }

    [Fact]
    public void AnInsertedRowMovesTheOthersRatherThanRewritingThem()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("first-render.bin"));
        var rows = (VerticalStackLayout)stack.Children[2];
        var a = rows.Children[0];
        var b = rows.Children[1];

        host.ApplyMessage(Read("counter-changed.bin"));
        host.ApplyMessage(Read("list-inserted.bin"));

        Assert.Equal(3, rows.Children.Count);
        Assert.Equal("z", ((Label)rows.Children[0]).Text);
        Assert.Same(a, rows.Children[1]);
        Assert.Same(b, rows.Children[2]);
    }

    [Fact]
    public void ARemovedRowLeavesAndTheSurvivorsKeepTheirControls()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("first-render.bin"));
        var rows = (VerticalStackLayout)stack.Children[2];

        host.ApplyMessage(Read("counter-changed.bin"));
        host.ApplyMessage(Read("list-inserted.bin"));

        var z = rows.Children[0];
        var b = rows.Children[2];

        host.ApplyMessage(Read("list-removed.bin"));

        Assert.Equal(2, rows.Children.Count);
        Assert.Same(z, rows.Children[0]);
        Assert.Same(b, rows.Children[1]);
    }

    /// <summary>
    /// A resync says so in the envelope and carries the SAME identities, so it
    /// applies onto the controls already showing - nothing is replaced, and
    /// focus, caret and scroll live on. The complete-tree part of applying it
    /// is the session's and the window's business; what this side of the
    /// fixture pins is the envelope and the reuse.
    /// </summary>
    [Fact]
    public void AResyncReappliesInPlaceRatherThanReplacing()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("first-render.bin"));
        var counter = (Label)stack.Children[0];
        var rows = (VerticalStackLayout)stack.Children[2];

        host.ApplyMessage(Read("counter-changed.bin"));
        host.ApplyMessage(Read("list-inserted.bin"));
        host.ApplyMessage(Read("list-removed.bin"));

        var z = rows.Children[0];
        var b = rows.Children[1];

        SwiftMessage message = SwiftWire.ReadMessage(Read("resync.bin"), host.Names);
        Assert.True(message.Complete, "the envelope says it, so nobody has to infer it");

        var after = (VerticalStackLayout)host.ApplyMessage(Read("resync.bin"));

        Assert.Same(stack, after);
        Assert.Same(counter, after.Children[0]);
        Assert.Equal("Count: 1", counter.Text);
        Assert.Same(z, rows.Children[0]);
        Assert.Same(b, rows.Children[1]);
    }

    /// <summary>
    /// The last message of the sequence: the counting label stops saying how
    /// big it is, and the size goes back to MAUI's default on the control that
    /// was already there.
    /// </summary>
    /// <remarks>
    /// The whole message is one label and one key - no <c>replace</c>, no
    /// complete node, nothing rebuilt - which is what a lost property is
    /// worth. Read the sidecar beside the fixture: it is six lines.
    /// </remarks>
    [Fact]
    public void APropertyThatWentAwayIsClearedRatherThanRebuildingAnything()
    {
        var host = new Host();

        var stack = (VerticalStackLayout)host.ApplyMessage(Read("first-render.bin"));
        var counter = (Label)stack.Children[0];
        var rows = (VerticalStackLayout)stack.Children[2];

        Assert.Equal(20, counter.FontSize);

        host.ApplyMessage(Read("counter-changed.bin"));
        host.ApplyMessage(Read("list-inserted.bin"));
        host.ApplyMessage(Read("list-removed.bin"));
        host.ApplyMessage(Read("resync.bin"));

        var z = rows.Children[0];

        var after = (VerticalStackLayout)host.ApplyMessage(Read("property-cleared.bin"));

        Assert.Same(stack, after);
        Assert.Same(counter, after.Children[0]);
        Assert.Same(z, rows.Children[0]);

        Assert.NotEqual(20, counter.FontSize);
        Assert.Equal("Count: 1", counter.Text);
    }

    /// <summary>
    /// A message from another wire version is refused on its first byte, and
    /// the refusal names BOTH versions - the one the message says and the one
    /// this runtime reads - so a mismatched pair of halves is diagnosable
    /// from the exception alone.
    /// </summary>
    [Fact]
    public void AMessageFromAnotherWireVersionIsRefusedNamingBoth()
    {
        var host = new Host();
        byte[] bytes = Read("first-render.bin");
        bytes[0] = SwiftWire.Version + 1;

        var refusal = Assert.Throws<InvalidDataException>(
            () => SwiftWire.ReadMessage(bytes, host.Names));

        Assert.Contains($"wire version {SwiftWire.Version + 1}", refusal.Message);
        Assert.Contains($"reads {SwiftWire.Version}", refusal.Message);
    }

    /// <summary>
    /// A message that ends mid-value throws rather than answering a partial
    /// tree - the same refusal a truncated command batch makes, which is what
    /// keeps an apply all-or-nothing.
    /// </summary>
    [Fact]
    public void ATruncatedMessageThrowsInsteadOfAnsweringAPartialTree()
    {
        var host = new Host();
        byte[] whole = Read("first-render.bin");

        Assert.Throws<InvalidDataException>(
            () => SwiftWire.ReadMessage(
                whole.AsSpan(0, whole.Length - 3).ToArray(), host.Names));
    }

    [Fact]
    public void EveryFixtureIsAppliedInOrderWithoutSurprises()
    {
        var host = new Host();

        foreach (string name in new[]
        {
            "first-render.bin", "counter-changed.bin",
            "list-inserted.bin", "list-removed.bin", "resync.bin",
        })
        {
            host.ApplyMessage(Read(name));
        }

        // Nothing reported an event: applying a message is not the user doing
        // anything.
        Assert.Empty(host.Dispatched);
    }
}
