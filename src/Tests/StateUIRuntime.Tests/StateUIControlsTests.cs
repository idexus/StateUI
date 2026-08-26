// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The application's own controls: a factory and an applier registered under a
// node type, consulted by the renderer before the unknown-control marker.
// What the registration promises - created once, applied on every message,
// the shared tier around it, events finding their handler - is pinned here,
// headlessly, through the same Render path every built-in takes.

using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;

namespace StateUI.Runtime.Tests;

public class StateUIControlsTests
{
    /// <summary>A stand-in an application could have written - headless-safe,
    /// like every control these tests build.</summary>
    private sealed class Lamp : Label;

    [Fact]
    public void ARegisteredControlIsCreatedAndItsPropertiesApplied()
    {
        StateUIControls.Add("Test.Lamp",
            create: _ => new Lamp(),
            apply: (view, node) =>
            {
                if (node.GetString("caption") is string caption)
                {
                    ((Lamp)view).Text = caption;
                }
            });

        var host = new Host();
        var lamp = Assert.IsType<Lamp>(host.Apply(
            """{"id":1,"type":"Test.Lamp","props":{"caption":"lit","opacity":0.5}}"""));

        Assert.Equal("lit", lamp.Text);

        // The shared tier is applied AROUND the registration's own apply, so
        // a registered control takes margins, opacity and the rest exactly as
        // a built-in does.
        Assert.Equal(0.5, lamp.Opacity);
    }

    [Fact]
    public void ARegisteredControlIsKeptBetweenRenders()
    {
        int created = 0;
        StateUIControls.Add("Test.Kept", _ => { created++; return new Lamp(); });

        var host = new Host();
        var first = host.Apply("""{"id":1,"type":"Test.Kept"}""");
        var again = host.Apply("""{"id":1,"type":"Test.Kept"}""");

        Assert.Same(first, again);
        Assert.Equal(1, created);
    }

    /// <summary>
    /// The raise the factory receives finds the handler id the tree carried -
    /// wired ONCE at creation, read at fire time, the rule every built-in
    /// follows - and the payload crosses as typed values.
    /// </summary>
    [Fact]
    public void ARaisedEventFindsItsHandlerAndCarriesItsPayload()
    {
        StateUIRaise? raise = null;
        StateUIControls.Add("Test.Beacon", given => { raise = given; return new Lamp(); });

        var host = new Host();
        var beacon = host.Apply(
            """{"id":1,"type":"Test.Beacon","events":{"blinked":7}}""");

        raise!(beacon, "blinked", SwiftWireValue.Of(2));

        Assert.Equal([(7, "2")], host.Dispatched);
    }

    /// <summary>
    /// A type nobody registered still draws the marker - the registry sits
    /// BEFORE it, never instead of it.
    /// </summary>
    [Fact]
    public void AnUnregisteredTypeStillDrawsTheMarker()
    {
        var host = new Host();
        var marker = Assert.IsType<Label>(host.Apply("""{"id":1,"type":"Test.Nobody"}"""));

        Assert.Contains("unknown node type 'Test.Nobody'", marker.Text);
    }

    /// <summary>A control whose value is a BindableProperty, for the
    /// declared-properties road.</summary>
    private sealed class Gauge : ContentView
    {
        public static readonly BindableProperty LevelProperty = BindableProperty.Create(
            nameof(Level), typeof(double), typeof(Gauge), 0.0);

        public double Level
        {
            get => (double)GetValue(LevelProperty);
            set => SetValue(LevelProperty, value);
        }
    }

    /// <summary>
    /// A DECLARED property is assigned by the renderer with no applier
    /// written - the registration names the BindableProperty, the message
    /// carries the value, and the generic conversion a style's setter takes
    /// does the rest.
    /// </summary>
    [Fact]
    public void ADeclaredPropertyIsAppliedWithoutAnApplier()
    {
        StateUIControls.Add("Test.Gauge",
            create: _ => new Gauge(),
            properties: new Dictionary<string, BindableProperty>
            {
                ["level"] = Gauge.LevelProperty,
            });

        var host = new Host();
        var gauge = Assert.IsType<Gauge>(host.Apply(
            """{"id":1,"type":"Test.Gauge","props":{"level":0.75}}"""));

        Assert.Equal(0.75, gauge.Level);
    }

    /// <summary>
    /// A declared property joins the table the library's own animations
    /// resolve through, which is what lets a Swift handle
    /// <c>animate(.level, to: …)</c> a registered control - and a property
    /// nobody declared still resolves to nothing, so the animation fails
    /// loudly rather than walking to nowhere.
    /// </summary>
    [Fact]
    public void ADeclaredPropertyIsReachableByAnAnimation()
    {
        StateUIControls.Add("Test.Dial",
            create: _ => new Gauge(),
            properties: new Dictionary<string, BindableProperty>
            {
                ["level"] = Gauge.LevelProperty,
            });

        Assert.Same(
            Gauge.LevelProperty,
            SwiftStyles.Property(SwiftNodeType.None, "Test.Dial", SwiftKey.Own("level")));

        Assert.Null(SwiftStyles.Property(SwiftNodeType.None, "Test.Dial", SwiftKey.Own("volume")));
    }

    /// <summary>
    /// A property an application declares under a name the LIBRARY also has is
    /// still its own - the value arrives under the library's member, the
    /// registration is still asked by name, and the control is still assigned.
    /// </summary>
    /// <remarks>
    /// The reader cannot tell whose a name is: it resolves <c>count</c> to
    /// <see cref="SwiftProp.Count"/> and puts the value in the library's bag,
    /// whoever declared it. A lookup that read only the application's bag would
    /// find nothing here and the control would go unwritten, silently - which
    /// the gallery's own Badge, with a <c>count</c>, would have shown.
    /// </remarks>
    [Fact]
    public void ADeclaredPropertyNamedLikeOneOfTheLibrarysIsStillTheApplications()
    {
        StateUIControls.Add("Test.Tally",
            create: _ => new Gauge(),
            properties: new Dictionary<string, BindableProperty>
            {
                ["count"] = Gauge.LevelProperty,
            });

        var host = new Host();
        var tally = Assert.IsType<Gauge>(host.Apply(
            """{"id":1,"type":"Test.Tally","props":{"count":4}}"""));

        Assert.Equal(4, tally.Level);
    }

    /// <summary>
    /// Two registered controls are told apart at one identity, and the second
    /// is BUILT rather than handed the first.
    /// </summary>
    /// <remarks>
    /// Every registered type is <see cref="SwiftNodeType.None"/> - that is what
    /// the member means - so the type member alone says two different
    /// registrations are the same control. The spelling is what separates them,
    /// and it is compared exactly where the member cannot decide.
    /// </remarks>
    [Fact]
    public void TwoRegisteredControlsAtOneIdentityAreNotEachOther()
    {
        StateUIControls.Add("Test.First", create: _ => new Gauge());
        StateUIControls.Add("Test.Second", create: _ => new Chip());

        var host = new Host();

        Assert.IsType<Gauge>(host.Apply("""{"id":1,"type":"Test.First"}"""));
        Assert.IsType<Chip>(host.Apply("""{"id":1,"type":"Test.Second"}"""));
    }

    /// <summary>A container an application could have written: one slot,
    /// filled by the registration's <c>content</c> setter.</summary>
    private sealed class Chip : ContentView
    {
        public View? Inner { get; set; }
    }

    /// <summary>
    /// A registered container holds Swift-described content: the node's child
    /// is reconciled into the registration's one slot - created, then PATCHED
    /// in place like any other view, the setter called only when the slot
    /// changes hands - and a child of a different type replaces it, calling
    /// the setter again.
    /// </summary>
    [Fact]
    public void ARegisteredContainerHoldsSwiftDescribedContent()
    {
        int placed = 0;
        StateUIControls.Add("Test.Chip",
            create: _ => new Chip(),
            content: (chip, inner) => { placed++; chip.Inner = inner; });

        var host = new Host();
        var chip = Assert.IsType<Chip>(host.Apply("""
            {"id":1,"type":"Test.Chip","children":[
              {"id":2,"type":"Label","props":{"text":"inside"}}]}
            """));

        var label = Assert.IsType<Label>(chip.Inner);
        Assert.Equal("inside", label.Text);
        Assert.Equal(1, placed);

        // A patch about the content patches the same control in place.
        host.Apply("""
            {"id":1,"type":"Test.Chip","children":[
              {"id":2,"type":"Label","props":{"text":"changed"}}]}
            """);

        Assert.Same(label, chip.Inner);
        Assert.Equal("changed", label.Text);
        Assert.Equal(1, placed);

        // A child of a different type is a different view, and the slot
        // changes hands.
        host.Apply("""
            {"id":1,"type":"Test.Chip","children":[
              {"id":2,"type":"Button","props":{"text":"instead"},"replace":true}]}
            """);

        Assert.IsType<Button>(chip.Inner);
        Assert.Equal(2, placed);
    }

    /// <summary>
    /// A declared property can be set in a VISUAL STATE: it joins the same
    /// table the library's own properties sit in, so the state's setter
    /// resolves it exactly as an animation walks it.
    /// </summary>
    /// <remarks>
    /// A Swift <c>Style&lt;RatingBar&gt;</c> needs nothing here at all - it is
    /// resolved on the Swift side, into the node's properties - so what is
    /// left to pin on this side is the one place a NAME still has to become a
    /// BindableProperty.
    /// </remarks>
    [Fact]
    public void ADeclaredPropertyCanBeSetInAVisualState()
    {
        StateUIControls.Add("Test.Meter",
            create: _ => new Gauge(),
            properties: new Dictionary<string, BindableProperty>
            {
                ["level"] = Gauge.LevelProperty,
            });

        var host = new Host();

        var gauge = (Gauge)host.Apply("""
            {"id":1,"type":"Test.Meter","children":[
              {"id":2,"type":"VisualState",
               "props":{"name":{"name":"Normal"},"group":{"name":"CommonStates"}},
               "children":[{"id":3,"type":"Setters","props":{"level":0.6,"opacity":0.5}}]}]}
            """);

        Assert.Equal(0.6, gauge.Level);
        Assert.Equal(0.5, gauge.Opacity);
    }
}
