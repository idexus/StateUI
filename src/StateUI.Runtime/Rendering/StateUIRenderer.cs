using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.Text.Json;
using Microsoft.Maui.Controls.Maps;
using Microsoft.Maui.Controls.Shapes;
using Microsoft.Maui.Layouts;
using StateUI.Runtime.Protocol;

// MAUI's shape, not System.IO's - the two are both called Path and both in
// scope, and only one of them can be drawn.
using Path = Microsoft.Maui.Controls.Shapes.Path;

// MAUI's map control, not the namespace-squatting Microsoft.Maui.Maps - that
// one holds MapType and MapSpan, and has no control in it. The maps namespace
// also declares a Polygon and a Polyline OF ITS OWN - lines drawn on the
// world - so the two shapes have to say they are the drawn kind.
using Map = Microsoft.Maui.Controls.Maps.Map;
using Polygon = Microsoft.Maui.Controls.Shapes.Polygon;
using Polyline = Microsoft.Maui.Controls.Shapes.Polyline;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Applies a Swift-described change to the visual tree.
/// </summary>
/// <remarks>
/// <para>
/// This is the half of the bridge that cannot live in Swift: MAUI controls are
/// managed objects, and the P/Invoke boundary only carries types representable
/// in C. Swift describes, C# materializes.
/// </para>
/// <para>
/// There is no translation table anywhere. A node's type IS the MAUI class and
/// each property key IS the MAUI property, so the code below is mostly
/// <c>label.FontSize = node.GetNumber(SwiftProp.FontSize)</c> - which is the
/// point: what a Swift author writes and what MAUI receives have the same
/// names. They travel as MEMBERS: the wire numbers each name once per session
/// and <see cref="SwiftWireDictionary"/> resolves it to a
/// <see cref="SwiftNodeType"/>, a <see cref="SwiftProp"/> or a
/// <see cref="SwiftEvent"/> as the announcement is read, so nothing here
/// compares a spelling. Only two things still need one - a control an
/// application registered, found in the registry by name, and a diagnostic that
/// has to say WHICH type it could not make sense of.
/// </para>
/// <para>
/// A message describes only what CHANGED. A node whose text is the same as last
/// time is not in it; a node that is there because a child of it changed carries
/// nothing but its identity. So the property code below reads as it means to -
/// assign what arrived, skip what did not - and far less arrives than a whole
/// tree.
/// </para>
/// <para>
/// Every element is matched by identity: Swift's id, which each control carries
/// in the attached <see cref="ElementProperty"/> - the ONE place this side
/// keeps what a control stands for. Same identity, same control - which is
/// what keeps focus, caret position and scroll offset across a render.
/// </para>
/// <para>
/// Adding a control means adding a case here and a struct on the Swift side.
/// Nothing in between needs to change.
/// </para>
/// </remarks>
public sealed class StateUIRenderer
{
    /// <summary>
    /// Where an event goes. The host wires this to the Swift side's dispatch,
    /// which finds the handler by id and runs it.
    /// </summary>
    private readonly Action<int, byte[]?> _dispatch;

    /// <summary>
    /// What the renderer knows about a control it made.
    /// </summary>
    /// <remarks>
    /// Attached to the control rather than kept in a table beside it, so the
    /// bookkeeping lives exactly as long as the control does: a control that
    /// leaves the tree takes it along and there is nothing to clean up. A control
    /// the renderer invented rather than read from a node - the stack wrapped
    /// around a ScrollView's several children, an error view - has none, which is
    /// also how those are told apart.
    /// </remarks>
    private sealed class RenderedElement
    {
        /// <summary>
        /// The identity, as the raw JSON text Swift sent. Compared against the
        /// next message's, which is how a control is matched to its node.
        /// </summary>
        public required string Key { get; init; }

        /// <summary>
        /// The MAUI class this was built for, as the member the dispatch
        /// switches on. A node of another type cannot reuse the control,
        /// whatever its identity says.
        /// </summary>
        public required SwiftNodeType Type { get; init; }

        /// <summary>
        /// The same, spelled - which is what tells two REGISTERED controls
        /// apart, both of them being <see cref="SwiftNodeType.None"/>, and what
        /// a diagnostic names a control by.
        /// </summary>
        public required string TypeName { get; init; }

        /// <summary>
        /// The handler ids this control reports with, kept because a message
        /// mentions them only when the set of handled events changes.
        /// </summary>
        public Dictionary<SwiftEvent, int>? Events { get; set; }

        /// <summary>
        /// The same, for the events an APPLICATION raises from a control of its
        /// own - by the names it raises them under. Replaced with
        /// <see cref="Events"/>, being the other half of one map.
        /// </summary>
        public Dictionary<string, int>? OwnEvents { get; set; }

        /// <summary>
        /// The properties this control is already reporting, so it is subscribed
        /// to each of them once - see <see cref="StateUIRenderer.Watch"/>.
        /// </summary>
        public HashSet<SwiftEvent>? Observed { get; set; }
    }

    /// <summary>
    /// Where <see cref="RenderedElement"/> hangs off the control it belongs to.
    /// </summary>
    private static readonly BindableProperty ElementProperty =
        BindableProperty.CreateAttached(
            "StateUIElement",
            typeof(RenderedElement),
            typeof(StateUIRenderer),
            defaultValue: null);

    /// <summary>
    /// The controls the AUTHOR named, so that an act can reach one by name.
    /// </summary>
    /// <remarks>
    /// <para>
    /// An ACT is the only thing that needs this. The tree describes what a
    /// view IS and the renderer walks to it from its parent; an act - focus, a
    /// scroll, a WebView's history, a map's region - is aimed at one view and
    /// arrives with nothing but the id it was written under. Animation is not
    /// a customer: a flight rides the tree message beside the property it
    /// moves, so it needs no id.
    /// </para>
    /// <para>
    /// Only ids somebody CHOSE go in here. A numeric one is the Swift renderer's
    /// own - what a <c>ControlState</c> aims with - and lives in
    /// <see cref="_tracked"/>, which is what keeps the two namespaces from ever
    /// colliding, exactly as they cannot on the tree's wire.
    /// </para>
    /// <para>
    /// Weak, because leaving the tree is what ends a view and there is no single
    /// place a control is dropped from - a removal, a replacement and a rebuilt
    /// page each do it. A stale entry therefore lasts until the control is
    /// collected, and an act aimed at one that is no longer shown does nothing
    /// and says so.
    /// </para>
    /// </remarks>
    private readonly Dictionary<string, WeakReference<VisualElement>> _named = [];

    /// <summary>
    /// The controls by the identity the Swift renderer assigned, so that an act
    /// can reach one by the number a <c>ControlState</c> captured.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The other half of <see cref="_named"/>: a <c>ControlState</c> has no
    /// name, the differ fills it with the element's own identity, and the act's
    /// argument arrives as a number where an author's id arrives as a string -
    /// see <c>Core/ControlState.swift</c>. Keyed by the number's text, weak for
    /// the reason <see cref="_named"/> is.
    /// </para>
    /// <para>
    /// Identities are never reused, so dead entries would only ever grow; the
    /// sweep in <see cref="Track"/> prunes them whenever the map doubles past
    /// its last swept size, which keeps the cost amortized to nothing.
    /// </para>
    /// </remarks>
    private readonly Dictionary<string, WeakReference<VisualElement>> _tracked = [];

    /// <summary>When <see cref="_tracked"/> is next swept for dead entries.</summary>
    private int _sweepTrackedAt = 64;

    /// <summary>When <see cref="_named"/> is next worth sweeping.</summary>
    private int _sweepNamedAt = 64;

    /// <summary>
    /// Set while the tree is being brought up to date, so that events MAUI
    /// raises as a side effect of assigning properties are ignored.
    /// </summary>
    /// <remarks>
    /// Assigning <c>Entry.Text</c> raises <c>TextChanged</c>. On a control being
    /// reused that handler is already attached, so without this the renderer
    /// would report the value it had just written as if the user had typed it -
    /// and the host would re-render from inside a render.
    /// </remarks>
    private bool _rendering;

    /// <summary>
    /// Suppresses reporting for as long as the returned scope is held, for a
    /// host that writes to controls outside <see cref="Render"/>.
    /// </summary>
    /// <remarks>
    /// <para>
    /// <see cref="StateUIWindow"/> is the one that needs it: the page
    /// arrangements are not views, so they are applied by hand rather than
    /// reconciled, and what the platform does to them - a flyout opened, a tab
    /// chosen, a page popped - is WATCHED. Without this, writing the property
    /// made MAUI raise PropertyChanged, the watcher reported the write back to
    /// Swift as though a reader had done it, and the render that followed ran
    /// INSIDE MAUI's own property setter.
    /// </para>
    /// <para>
    /// On Apple that was invisible - Swift set a value it already held. On
    /// Android it crashed the app: MAUI began a fragment transaction
    /// re-entrantly and Android threw <c>No view found for id 0xa ... for
    /// fragment</c>, which names nothing that leads back here. Measured on a
    /// device, opening a flyout; every report an arrangement makes is deferred
    /// behind this guard - see SwiftPages.Announce.
    /// </para>
    /// </remarks>
    internal Suppressed Applying() => new(this);

    /// <summary>
    /// Whether a message is being applied right now - so a caller that would
    /// ask Swift to render can wait until it is not.
    /// </summary>
    /// <remarks>
    /// A render asked for INSIDE an apply is a resync: the host still holds the
    /// old generation, so Swift describes the whole tree again - and a property
    /// that is being WALKED arrives as a plain value, which ends the walk. That
    /// is how a flight's first sample killed its own flight, measured on
    /// Catalyst: the first animation step reports before the message that
    /// started it has finished being applied. See <see cref="SwiftFlights"/>.
    /// </remarks>
    internal bool Busy => _rendering;

    /// <summary>
    /// Holds reporting off until it is disposed, and puts it back the way it
    /// found it.
    /// </summary>
    /// <remarks>
    /// Restored rather than cleared, because these nest: applying a window
    /// reconciles the views of every page under it, and each of those is a
    /// <see cref="Render"/> with a scope of its own.
    /// </remarks>
    internal readonly struct Suppressed : IDisposable
    {
        private readonly StateUIRenderer _renderer;
        private readonly bool _was;

        /// <summary>Suppresses reporting on a renderer.</summary>
        /// <param name="renderer">The renderer to hold quiet.</param>
        internal Suppressed(StateUIRenderer renderer)
        {
            _renderer = renderer;
            _was = renderer._rendering;
            renderer._rendering = true;
        }

        /// <summary>Puts reporting back the way it was.</summary>
        public void Dispose() => _renderer._rendering = _was;
    }

    /// <param name="dispatch">
    /// Called when an event fires, with the handler id from the tree and the
    /// payload's wire bytes - null for an event with nothing to say. The host
    /// decides what happens next - normally re-rendering.
    /// </param>
    /// <param name="report">
    /// Called with a sample of a walk in the air - the channel it is on and
    /// where the control has got to. A separate door from
    /// <paramref name="dispatch"/> on purpose: that one RESUMES the handler
    /// waiting on the flight, and a sample says nothing about being over.
    /// </param>
    public StateUIRenderer(Action<int, byte[]?> dispatch, Action<int, byte[]?> report)
    {
        _dispatch = dispatch;
        _report = report;

        // A flight answers on one of the negative completion ids every act
        // answers on, so it goes out the same door an event does - the Swift
        // side reads the sign and hands it to the handler waiting there. Its
        // progress goes out the other door, as often as the author asked.
        _flights = new SwiftFlights(
            (channel, whole) =>
                _dispatch(channel, SwiftWire.WriteReply([SwiftWireValue.Of(whole)])),
            (channel, sample) =>
                _report(channel, SwiftWire.WritePayload(sample)));
    }

    /// <summary>
    /// Where a walk's progress goes. The host wires this to the Swift side's
    /// report, which finds the state watching that channel and writes it.
    /// </summary>
    private readonly Action<int, byte[]?> _report;

    /// <summary>
    /// The properties being walked to rather than assigned - see
    /// <see cref="SwiftFlights"/>. Reachable so a test can hand it a ticker,
    /// which an application never needs to.
    /// </summary>
    internal SwiftFlights Flights => _flights;

    private readonly SwiftFlights _flights;

    /// <summary>
    /// Applies a message to <paramref name="existing"/> and returns the control
    /// to show.
    /// </summary>
    /// <remarks>
    /// The same control comes back when the message describes the one that is
    /// already there, a new one when it does not. Pass null - or anything this
    /// renderer did not build - and everything is built from scratch, which is
    /// what Swift sends when the two sides are out of step.
    /// </remarks>
    public View Render(View? existing, SwiftNode node)
    {
        // Restored rather than cleared: a window applying its node holds a
        // scope of its own around this, and clearing here would let the rest of
        // that apply report its own writes.
        using Suppressed suppressed = Applying();

        return Reconcile(existing, node);
    }

    /// <summary>
    /// Dispatches on the MAUI class name and applies the node to the right
    /// control.
    /// </summary>
    /// <remarks>
    /// A type this renderer does not know renders as a red marker rather than
    /// throwing, so a Swift side that has run ahead is visible without the rest
    /// of the interface disappearing with it.
    /// </remarks>
    private View Reconcile(View? existing, SwiftNode node)
    {
        // Lifted BEFORE the node is applied, started AFTER - the only order
        // there is, since the assignment that would snap has to be prevented
        // before it happens and the control it is about may not exist until it
        // does. See SwiftFlights.
        List<(SwiftTransition Transition, SwiftWireValue Target)> flying = SwiftFlights.Take(node);
        View view = Made(existing, node);

        _flights.Apply(view, node, flying);

        return view;
    }

    /// <summary>
    /// Puts every property the element has stopped describing back to MAUI's
    /// own default.
    /// </summary>
    /// <remarks>
    /// What makes a modifier written conditionally cost ONE property. Without
    /// it the renderer assigns only what arrives, so a value that has gone away
    /// has nothing to overwrite it and stays on the control - which is why
    /// Swift used to send the whole element again, taking every descendant's
    /// identity, handlers and state with it.
    /// </remarks>
    /// <param name="target">The control the node was applied to.</param>
    /// <param name="node">The node, whose <c>Cleared</c> list this is about.</param>
    private static void Clear(BindableObject target, SwiftNode node)
    {
        if (node.Cleared is not { Count: > 0 } cleared)
        {
            return;
        }

        foreach (SwiftKey key in cleared)
        {
            if (SwiftStyles.Property(node.Type, node.TypeName, key) is BindableProperty property)
            {
                target.ClearValue(property);
            }
            else
            {
                // Swift keeps the list of keys nothing here can put back and
                // sends the whole element again for those, so arriving here is
                // the two lists having drifted apart. Said out loud rather than
                // left as a value standing on a control the tree no longer
                // describes - the failure a reader would otherwise hunt for.
                StateUISession.Report(
                    $"'{node.TypeName}' stopped describing " +
                    $"'{key.Name ?? SwiftTokenNames<SwiftProp>.Spelling(key.Prop)}' and " +
                    "nothing here knows what to put back, so the old value stands.\n\n" +
                    "Add the property to that control's arm in SwiftStyles, or name it in " +
                    "Prop.notCleared on the Swift side so the control is built again instead.");
            }
        }
    }

    /// <summary>The control this node is about, made or reused and applied.</summary>
    private View Made(View? existing, SwiftNode node)
    {
        return node.Type switch
        {
            SwiftNodeType.Label => ReconcileLabel(node, existing),
            SwiftNodeType.Button => ReconcileButton(node, existing),
            SwiftNodeType.Entry => ReconcileEntry(node, existing),
            SwiftNodeType.Image => ReconcileImage(node, existing),
            SwiftNodeType.ImageButton => ReconcileImageButton(node, existing),
            SwiftNodeType.Editor => ReconcileEditor(node, existing),
            SwiftNodeType.Picker => ReconcilePicker(node, existing),
            SwiftNodeType.DatePicker => ReconcileDatePicker(node, existing),
            SwiftNodeType.BoxView => ReconcileBoxView(node, existing),
            SwiftNodeType.Border => ReconcileBorder(node, existing),
            SwiftNodeType.TimePicker => ReconcileTimePicker(node, existing),
            SwiftNodeType.Switch => ReconcileSwitch(node, existing),
            SwiftNodeType.CheckBox => ReconcileCheckBox(node, existing),
            SwiftNodeType.RadioButton => ReconcileRadioButton(node, existing),
            SwiftNodeType.Slider => ReconcileSlider(node, existing),
            SwiftNodeType.Stepper => ReconcileStepper(node, existing),
            SwiftNodeType.SearchBar => ReconcileSearchBar(node, existing),
            SwiftNodeType.ActivityIndicator => ReconcileActivityIndicator(node, existing),
            SwiftNodeType.ProgressBar => ReconcileProgressBar(node, existing),
            SwiftNodeType.Grid => ReconcileGrid(node, existing),
            SwiftNodeType.VerticalStackLayout => ReconcileStack<VerticalStackLayout>(node, existing),
            SwiftNodeType.HorizontalStackLayout => ReconcileStack<HorizontalStackLayout>(node, existing),
            SwiftNodeType.AbsoluteLayout => ReconcileAbsoluteLayout(node, existing),
            SwiftNodeType.FlexLayout => ReconcileFlexLayout(node, existing),
            SwiftNodeType.ScrollView => ReconcileScrollView(node, existing),
            SwiftNodeType.WebView => ReconcileWebView(node, existing),
            SwiftNodeType.Map => ReconcileMap(node, existing),
            SwiftNodeType.TitleBar => ReconcileTitleBar(node, existing),
            SwiftNodeType.RefreshView => ReconcileRefreshView(node, existing),
            SwiftNodeType.SwipeView => ReconcileSwipeView(node, existing),
            SwiftNodeType.Rectangle => ReconcileRectangle(node, existing),
            SwiftNodeType.RoundRectangle => ReconcileRoundRectangle(node, existing),
            SwiftNodeType.Ellipse => ReconcileEllipse(node, existing),
            SwiftNodeType.Line => ReconcileLine(node, existing),
            SwiftNodeType.Path => ReconcilePath(node, existing),
            SwiftNodeType.Polygon => ReconcilePolygon(node, existing),
            SwiftNodeType.Polyline => ReconcilePolyline(node, existing),
            SwiftNodeType.GraphicsView => ReconcileGraphicsView(node, existing),
            SwiftNodeType.CarouselView => ReconcileCarouselView(node, existing),
            SwiftNodeType.IndicatorView => ReconcileIndicatorView(node, existing),
            _ => ReconcileRegistered(node, existing),
        };
    }

    // ---- Identity ----------------------------------------------------------

    /// <summary>
    /// The existing control when the node describes it, null when it has to be
    /// built.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A <see cref="BindableObject"/> rather than a View, for the reason
    /// <see cref="Track{T}"/> takes one: a SwipeItem is a MenuItem, and it is
    /// matched by identity exactly as a control is.
    /// </para>
    /// <para>
    /// The SPELLING is compared as well when the type has no member, and only
    /// then: every control an application registered reads as
    /// <see cref="SwiftNodeType.None"/>, so the member alone would let a
    /// <c>Gallery.TrafficLight</c> be reused as the <c>Gallery.Badge</c> that
    /// took its place at the same identity.
    /// </para>
    /// </remarks>
    private static T? Reuse<T>(T? existing, SwiftNode node) where T : BindableObject
    {
        if (node.Replace || existing?.GetValue(ElementProperty) is not RenderedElement element)
        {
            return null;
        }

        if (element.Key != node.Key || element.Type != node.Type)
        {
            return null;
        }

        return element.Type != SwiftNodeType.None || element.TypeName == node.TypeName
            ? existing
            : null;
    }

    /// <summary>
    /// Records what the control now stands for, and returns the control.
    /// </summary>
    /// <remarks>
    /// Takes a <see cref="BindableObject"/> rather than a <see cref="View"/>
    /// because not everything a message describes is one: a Window, a Page, a
    /// ToolbarItem and a MenuFlyoutItem are Elements, and every one of them
    /// reports events and so needs the handler ids that go with them. What is
    /// only true of a view - the StyleId it carries, the properties worth
    /// observing - is asked for rather than assumed.
    /// </remarks>
    internal T Track<T>(T view, SwiftNode node) where T : BindableObject
    {
        // Here because everything the renderer applies passes through here -
        // a control, a page, a window, a toolbar item - and every one of them
        // can stop describing a property. A cleared key and an arriving one
        // are never the same key, so this may run before or after the values
        // land; pages call this first, controls last.
        Clear(view, node);

        if (view.GetValue(ElementProperty) is not RenderedElement element || element.Key != node.Key)
        {
            element = new RenderedElement
            {
                Key = node.Key,
                Type = node.Type,
                TypeName = node.TypeName,
            };

            view.SetValue(ElementProperty, element);
        }

        // Both halves of one map, replaced together: a message that names the
        // events names all of them, whoever declared them.
        if (node.Events is not null)
        {
            element.Events = node.Events;
            element.OwnEvents = node.OwnEvents;
        }

        // An id somebody chose is one an act can ask for later - see _named.
        if (node.Name is string name && view is VisualElement addressable)
        {
            _named[name] = new WeakReference<VisualElement>(addressable);
            Sweep(_named, ref _sweepNamedAt);
        }

        // And an identity the renderer assigned is what a HANDLE aims with -
        // see _tracked. Only the numeric ones: a named element's acts arrive
        // through the name.
        if (node.Name is null && view is VisualElement identified)
        {
            _tracked[node.Identity] = new WeakReference<VisualElement>(identified);
            Sweep(_tracked, ref _sweepTrackedAt);
        }

        if (view is View control)
        {
            Observe(control, element);
            ApplyGestures(control, node, element);
        }

        return view;
    }

    /// <summary>
    /// The control an author named, and the MAUI class it was built for.
    /// </summary>
    /// <remarks>
    /// The type comes back with it because what can be done to a control depends
    /// on it: <see cref="SwiftStyles.Property"/> resolves a property name per
    /// target type, and an animation needs the <see cref="BindableProperty"/>
    /// exactly as a <see cref="Setter"/> does.
    /// </remarks>
    /// <param name="name">The id the author wrote with <c>.id()</c>.</param>
    /// <returns>Null when nothing by that name is being shown.</returns>
    internal (VisualElement View, string Type)? Named(string name)
    {
        if (!_named.TryGetValue(name, out WeakReference<VisualElement>? held))
        {
            return null;
        }

        if (!held.TryGetTarget(out VisualElement? view))
        {
            // Collected, so the view is gone for good and the entry with it.
            _named.Remove(name);
            return null;
        }

        return view.GetValue(ElementProperty) is RenderedElement element
            ? (view, element.TypeName)
            : null;
    }

    /// <summary>
    /// The control behind an identity the Swift renderer assigned - what an act
    /// aimed with a <c>ControlState</c> resolves through, the way
    /// <see cref="Named"/> resolves a name. See <c>Core/ControlState.swift</c>.
    /// </summary>
    /// <param name="identity">The identity's text, as the number crossed.</param>
    /// <returns>Null when nothing of that identity is being shown.</returns>
    internal (VisualElement View, string Type)? Tracked(string identity)
    {
        if (!_tracked.TryGetValue(identity, out WeakReference<VisualElement>? held))
        {
            return null;
        }

        if (!held.TryGetTarget(out VisualElement? view))
        {
            // Collected, so the view is gone for good and the entry with it.
            _tracked.Remove(identity);
            return null;
        }

        return view.GetValue(ElementProperty) is RenderedElement element
            ? (view, element.TypeName)
            : null;
    }

    /// <summary>
    /// Prunes a weak map's dead entries once it has doubled past the last
    /// swept size. <see cref="_tracked"/> needs it because identities are
    /// never reused, and <see cref="_named"/> for the same reason one level
    /// up: an app generating names writes each once and never looks most of
    /// them up, so without this either map would only ever grow.
    /// </summary>
    private static void Sweep(
        Dictionary<string, WeakReference<VisualElement>> map,
        ref int threshold)
    {
        if (map.Count < threshold)
        {
            return;
        }

        List<string> dead = [];
        foreach ((string key, WeakReference<VisualElement> held) in map)
        {
            if (!held.TryGetTarget(out _))
            {
                dead.Add(key);
            }
        }

        foreach (string key in dead)
        {
            map.Remove(key);
        }

        threshold = Math.Max(64, map.Count * 2);
    }

    /// <summary>
    /// Gives a view the gesture recognizers the tree asked for.
    /// </summary>
    /// <remarks>
    /// <para>
    /// MAUI declares <see cref="View.GestureRecognizers"/> on View, so anything
    /// can carry one - which is what a tappable row IS in MAUI: not a button,
    /// but a view with a TapGestureRecognizer on it.
    /// </para>
    /// <para>
    /// Added once and kept, like every other subscription here, and only when
    /// the tree carries a handler for it. The handler id is read off the VIEW
    /// when the tap arrives, never captured while wiring, so a re-render can
    /// change what a tap does without anything being rebuilt.
    /// </para>
    /// </remarks>
    private void ApplyGestures(View view, SwiftNode node, RenderedElement element)
    {
        Dictionary<SwiftEvent, int>? events = element.Events;

        // No early return on an empty event map: a view that can be DRAGGED says
        // so with a property, whether or not it wants to hear about it.
        bool Handles(SwiftEvent name) => events?.ContainsKey(name) == true;

        if (Handles(SwiftEvent.Tapped))
        {
            TapGestureRecognizer tap = Recognizer(view, () =>
            {
                var recognizer = new TapGestureRecognizer();
                recognizer.Tapped += (_, _) => Raise(view, SwiftEvent.Tapped);
                return recognizer;
            });

            if (node.GetInt(SwiftProp.NumberOfTapsRequired) is int taps) { tap.NumberOfTapsRequired = taps; }
        }

        if (Handles(SwiftEvent.Swiped))
        {
            ApplySwipe(view, node);
        }

        if (Handles(SwiftEvent.PanUpdated))
        {
            PanGestureRecognizer pan = Recognizer(view, () =>
            {
                var recognizer = new PanGestureRecognizer();

                // One per view, made where the recognizer is: a pan is measured
                // from where it began, and on Android that has to be worked out
                // rather than taken as read. See PanFrame.
                var frame = new PanFrame();

                // Status, then the totals, in the order MAUI declares them -
                // see Types/Gestures.swift for the one place that format is
                // read.
                recognizer.PanUpdated += (_, e) =>
                {
                    (double totalX, double totalY) = frame.Totals(e, view.TranslationX, view.TranslationY);

                    Raise(view, SwiftEvent.PanUpdated,
                        SwiftWireValue.OfMember((int)Member(e.StatusType)),
                        SwiftWireValue.Of(totalX),
                        SwiftWireValue.Of(totalY));
                };

                return recognizer;
            });

            if (node.GetInt(SwiftProp.PanTouchCount) is int touches) { pan.TouchPoints = touches; }
        }

        if (Handles(SwiftEvent.PinchUpdated))
        {
            Recognizer(view, () =>
            {
                var recognizer = new PinchGestureRecognizer();

                recognizer.PinchUpdated += (_, e) => Raise(view, SwiftEvent.PinchUpdated,
                    SwiftWireValue.OfMember((int)Member(e.Status)),
                    SwiftWireValue.Of(e.Scale),
                    SwiftWireValue.Of(e.ScaleOrigin.X, e.ScaleOrigin.Y));

                return recognizer;
            });
        }

        // One recognizer answers all five, so any of them is reason to attach
        // it - named out rather than matched on a prefix, which is what a
        // vocabulary of members buys.
        if (Handles(SwiftEvent.PointerEntered) || Handles(SwiftEvent.PointerExited)
            || Handles(SwiftEvent.PointerMoved) || Handles(SwiftEvent.PointerPressed)
            || Handles(SwiftEvent.PointerReleased))
        {
            Recognizer(view, () =>
            {
                var recognizer = new PointerGestureRecognizer();

                recognizer.PointerEntered += (_, _) => Raise(view, SwiftEvent.PointerEntered);
                recognizer.PointerExited += (_, _) => Raise(view, SwiftEvent.PointerExited);
                recognizer.PointerMoved += (_, e) => Raise(view, SwiftEvent.PointerMoved, At(e, view));
                recognizer.PointerPressed += (_, e) => Raise(view, SwiftEvent.PointerPressed, At(e, view));
                recognizer.PointerReleased += (_, e) => Raise(view, SwiftEvent.PointerReleased, At(e, view));

                return recognizer;
            });
        }

        if (node.GetBool(SwiftProp.CanDrag) is bool canDrag)
        {
            DragGestureRecognizer drag = Recognizer(view, () =>
            {
                var recognizer = new DragGestureRecognizer();

                // What travels is decided before the drag, not during it: MAUI
                // wants the data package filled here and now, and this side
                // could not be asked in time.
                recognizer.DragStarting += (sender, e) =>
                {
                    if (KeyOf(view) is not null && sender is DragGestureRecognizer source)
                    {
                        e.Data.Text = source.GetValue(DragTextProperty) as string;
                    }

                    Raise(view, SwiftEvent.DragStarting);
                };

                recognizer.DropCompleted += (_, _) => Raise(view, SwiftEvent.DropCompleted);

                return recognizer;
            });

            drag.CanDrag = canDrag;
            drag.SetValue(DragTextProperty, node.GetString(SwiftProp.DragText) ?? drag.GetValue(DragTextProperty));
        }

        if (node.GetBool(SwiftProp.AllowDrop) is bool allowDrop)
        {
            DropGestureRecognizer drop = Recognizer(view, () =>
            {
                var recognizer = new DropGestureRecognizer();

                recognizer.DragOver += (_, _) => Raise(view, SwiftEvent.DragOver);
                recognizer.DragLeave += (_, _) => Raise(view, SwiftEvent.DragLeave);

                // Reading a data package is asynchronous - it may be coming
                // from another application - so the await happens HERE, on the
                // C# side, and the Swift side hears about the drop through the
                // ordinary event dispatch once there is something to tell it.
                // The same rule as every act; see Core/Command.swift.
                recognizer.Drop += async (_, e) =>
                    Raise(view, SwiftEvent.Drop, await e.Data.GetTextAsync() ?? "");

                return recognizer;
            });

            drop.AllowDrop = allowDrop;
        }
    }

    /// <summary>The four directions a swipe can go. MAUI: SwipeDirection.</summary>
    private static readonly SwipeDirection[] SwipeWays =
        [SwipeDirection.Left, SwipeDirection.Right, SwipeDirection.Up, SwipeDirection.Down];

    /// <summary>Every direction - what the Swift side listens for unless told otherwise.</summary>
    private const SwipeDirection EverySwipeWay =
        SwipeDirection.Left | SwipeDirection.Right | SwipeDirection.Up | SwipeDirection.Down;

    /// <summary>
    /// A swipe recognizer for each direction the tree listens for.
    /// </summary>
    /// <remarks>
    /// <para>
    /// One recognizer per direction rather than one carrying the whole mask, and
    /// the reason is what MAUI reports. On iOS and Mac Catalyst its gesture
    /// manager builds a single <c>UISwipeGestureRecognizer</c> out of
    /// <see cref="SwipeGestureRecognizer.Direction"/> and then calls back with
    /// THAT value - <c>result.AddTarget(() =&gt; action(direction))</c> - so the
    /// event names the directions the view is LISTENING for, never the one the
    /// finger actually went. A view listening for every direction reports
    /// <c>"Right, Left, Up, Down"</c> for every swipe. That is not a direction,
    /// the Swift side refuses to parse it, and the handler never runs: a swipe
    /// that does nothing at all on Apple while working on Android, which works
    /// the direction out from the fling and is not affected.
    /// </para>
    /// <para>
    /// Splitting the mask is what MAUI's own documentation does in XAML for the
    /// same reason - four <c>SwipeGestureRecognizer</c>s, one Direction each.
    /// Every platform then names a single direction, because a single direction
    /// is all the recognizer that fired ever knew. It is also why the direction
    /// raised here is the recognizer's own rather than the event's: it is single
    /// by construction, on every platform, whatever the event args carry.
    /// </para>
    /// <para>
    /// The set is reconciled rather than added to, so narrowing the directions
    /// takes the others away. An absent <c>swipeDirection</c> means the property
    /// did not change, the rule everywhere else - what is already there stays,
    /// and only a view carrying none at all falls back to every direction.
    /// </para>
    /// </remarks>
    private void ApplySwipe(View view, SwiftNode node)
    {
        SwipeDirection wanted = node.GetSwipeDirection(SwiftProp.SwipeDirection)
            ?? Listening(view)
            ?? EverySwipeWay;

        // Read before the loop, so a direction added by a later patch joins with
        // the threshold its siblings already carry - otherwise it would be the
        // one direction that wanted a longer finger, for no reason a reader
        // could see.
        uint? threshold = node.GetNumber(SwiftProp.SwipeThreshold) is double given
            ? (uint)given
            : view.GestureRecognizers.OfType<SwipeGestureRecognizer>().FirstOrDefault()?.Threshold;

        foreach (SwipeDirection way in SwipeWays)
        {
            SwipeGestureRecognizer? carried = view.GestureRecognizers
                .OfType<SwipeGestureRecognizer>()
                .FirstOrDefault(each => each.Direction == way);

            if (!wanted.HasFlag(way))
            {
                if (carried is not null) { view.GestureRecognizers.Remove(carried); }
                continue;
            }

            if (carried is null)
            {
                carried = new SwipeGestureRecognizer { Direction = way };

                // `way` is this turn's own value, and the recognizer's Direction
                // besides - the event args are deliberately not read. See above.
                // The bit is translated rather than cast, like every other
                // member: that OUR four bits and MAUI's happen to agree is a
                // coincidence this side must not spend.
                carried.Swiped += (_, _) =>
                    Raise(view, SwiftEvent.Swiped, SwiftWireValue.OfMember((int)Member(way)));

                view.GestureRecognizers.Add(carried);
            }

            if (threshold is uint distance) { carried.Threshold = distance; }
        }
    }

    /// <summary>Which directions a view already listens for, or null if none.</summary>
    private static SwipeDirection? Listening(View view)
    {
        SwipeDirection carried = 0;

        foreach (SwipeGestureRecognizer each in view.GestureRecognizers.OfType<SwipeGestureRecognizer>())
        {
            carried |= each.Direction;
        }

        return carried == 0 ? null : carried;
    }

    /// <summary>
    /// The recognizer of a kind a view already carries, or a new one.
    /// </summary>
    /// <remarks>
    /// One per kind per view. MAUI allows several of the same kind, but a second
    /// one here would mean two reports for one gesture - and the tree describes
    /// what a view DOES, not how many recognizers it took. A swipe is the one
    /// exception and does not come through here: it needs one recognizer per
    /// direction, for the reason <see cref="ApplySwipe"/> gives.
    /// </remarks>
    private static T Recognizer<T>(View view, Func<T> build) where T : class, IGestureRecognizer
    {
        if (view.GestureRecognizers.OfType<T>().FirstOrDefault() is T existing)
        {
            return existing;
        }

        T recognizer = build();
        view.GestureRecognizers.Add(recognizer);

        return recognizer;
    }

    /// <summary>What a drag carries, kept on the recognizer that starts it.</summary>
    private static readonly BindableProperty DragTextProperty = BindableProperty.CreateAttached(
        "SwiftDragText", typeof(string), typeof(StateUIRenderer), null);

    /// <summary>
    /// Where a pointer is, in the view's own coordinates - one pair, or
    /// nothing when the platform did not say, which the Swift side reads as
    /// no point rather than inventing one.
    /// </summary>
    private static SwiftWireValue[] At(PointerEventArgs e, View view) =>
        e.GetPosition(view) is Point point
            ? [SwiftWireValue.Of(point.X, point.Y)]
            : [];

    // ---- Properties that report themselves ---------------------------------

    /// <summary>
    /// Wires up the properties the Swift side has asked to hear about.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Most of what a control has to say it says through an event, and an event
    /// hands over the new value already typed - which is why the controls above
    /// use them. Some properties have no event at all, and some are changed by
    /// MAUI itself rather than by the user: the size a layout settled on, the
    /// focus the platform moved. Those are what this is for.
    /// </para>
    /// <para>
    /// <see cref="BindableObject.PropertyChanged"/> is the general mechanism -
    /// one subscription, filtered by name - so any bindable property can be
    /// reported without MAUI having thought to give it an event, and without
    /// reflection anywhere: the name comes from the BindableProperty and the
    /// value from a typed getter.
    /// </para>
    /// <para>
    /// Nothing is subscribed until the tree asks for it, because
    /// <c>PropertyChanged</c> on Width and Height fires on every measure and a
    /// subscription per control would be a real cost for nothing.
    /// </para>
    /// </remarks>
    private void Observe<T>(T view, RenderedElement element) where T : View
    {
        // Loaded and Unloaded are real MAUI events rather than watched
        // properties, so they are subscribed directly - once, under the same
        // guard Watch uses, and only when the tree carries a handler. The pair
        // fires again on every attach: a page that leaves the screen - a tab
        // switched away from, a page pushed over - unloads its views and
        // loading them again is what coming back means, which is exactly what
        // lets a handler run something for as long as the view shows.
        if (element.Events?.ContainsKey(SwiftEvent.Loaded) == true
            && (element.Observed ??= []).Add(SwiftEvent.Loaded))
        {
            view.Loaded += (_, _) => Raise(view, SwiftEvent.Loaded);
        }

        if (element.Events?.ContainsKey(SwiftEvent.Unloaded) == true
            && (element.Observed ??= []).Add(SwiftEvent.Unloaded))
        {
            view.Unloaded += (_, _) => Raise(view, SwiftEvent.Unloaded);
        }

        Watch(view, SwiftEvent.IsFocusedChanged, VisualElement.IsFocusedProperty,
            () => SwiftWireValue.Of(view.IsFocused));

        Watch(view, SwiftEvent.WidthChanged, VisualElement.WidthProperty,
            () => SwiftWireValue.Of(view.Width));

        Watch(view, SwiftEvent.HeightChanged, VisualElement.HeightProperty,
            () => SwiftWireValue.Of(view.Height));

        if (view is ScrollView scroll)
        {
            Watch(scroll, SwiftEvent.ScrollXChanged, ScrollView.ScrollXProperty,
                () => SwiftWireValue.Of(scroll.ScrollX));

            Watch(scroll, SwiftEvent.ScrollYChanged, ScrollView.ScrollYProperty,
                () => SwiftWireValue.Of(scroll.ScrollY));
        }

        // The platform decides both after every navigation, and MAUI gives
        // neither an event - so a Back button's enablement follows the
        // property, the way a binding follows IsRefreshing below.
        if (view is WebView web)
        {
            Watch(web, SwiftEvent.CanGoBackChanged, WebView.CanGoBackProperty,
                () => SwiftWireValue.Of(web.CanGoBack));

            Watch(web, SwiftEvent.CanGoForwardChanged, WebView.CanGoForwardProperty,
                () => SwiftWireValue.Of(web.CanGoForward));
        }

        // A pull sets IsRefreshing, and so does a pull the platform gave up on.
        // MAUI's Refreshing event says the first happened and nothing says the
        // second did, so the property itself is what a binding follows.
        if (view is RefreshView refresh)
        {
            Watch(refresh, SwiftEvent.IsRefreshingChanged, RefreshView.IsRefreshingProperty,
                () => SwiftWireValue.Of(refresh.IsRefreshing));
        }

        // The frame, on ANY view that asked - `.onFrameChanged` is a View-tier
        // modifier, and a FrameReader is one caller among many. Not through
        // `Watch`, because one report carries every coordinate space and has
        // to dedupe the burst a single layout pass raises.
        WatchFrame(view, element);

        // And which state it is in, for the same reason and under the same
        // guard - a style's setters change instantly, where a handler can take
        // as long as an animation does.
        WatchVisualState(view, element);
    }

    /// <summary>
    /// Reports a property that has no event of its own, when the tree asked to
    /// hear about it.
    /// </summary>
    /// <remarks>
    /// A property the platform writes as readily as this side does - a width, a
    /// scroll offset, a WebView's CanGoBack - is heard by subscribing to
    /// <c>PropertyChanged</c>, once per control and per name, and only where
    /// the tree carries a handler. The element is read off the control rather
    /// than passed in, so the control is the whole of what a caller hands over.
    /// </remarks>
    private void Watch(
        BindableObject control,
        SwiftEvent name,
        BindableProperty property,
        Func<SwiftWireValue> read)
    {
        // Nobody is listening, or this control is listening already.
        if (control.GetValue(ElementProperty) is not RenderedElement element
            || element.Events?.ContainsKey(name) != true)
        {
            return;
        }

        if (!(element.Observed ??= []).Add(name))
        {
            return;
        }

        control.PropertyChanged += (sender, e) =>
        {
            if (e.PropertyName == property.PropertyName)
            {
                Raise(sender, name, read());
            }
        };
    }

    /// <summary>
    /// A date as its three numbers - year, month, day - or nothing when the
    /// picker holds none, which the Swift side reads as no date rather than
    /// inventing one.
    /// </summary>
    private static SwiftWireValue[] Day(DateTime? value) =>
        value is DateTime date ? [SwiftWireValue.Of(date.Year, date.Month, date.Day)] : [];

    /// <summary>
    /// And a time of day as its three - hour, minute, second. A TimeSpan can
    /// hold whole days; a time of day cannot, so only the day's part crosses.
    /// </summary>
    private static SwiftWireValue[] Clock(TimeSpan? value) =>
        value is TimeSpan time ? [SwiftWireValue.Of(time.Hours, time.Minutes, time.Seconds)] : [];

    /// <summary>
    /// The identity a control was built with, or null when the renderer did not
    /// build it - a wrapper it invented, or a control from somewhere else.
    /// </summary>
    internal static string? KeyOf(BindableObject view)
    {
        return (view.GetValue(ElementProperty) as RenderedElement)?.Key;
    }

    /// <summary>
    /// The handler ids an object is carrying - what
    /// <see cref="Raise(object?, SwiftEvent, byte[])"/> quotes back when one of
    /// its events fires.
    /// </summary>
    internal static IReadOnlyDictionary<SwiftEvent, int>? EventsOf(BindableObject control)
    {
        return (control.GetValue(ElementProperty) as RenderedElement)?.Events;
    }

    /// <summary>
    /// Reports an event to the host with the handler id the control holds.
    /// </summary>
    /// <remarks>
    /// Controls subscribe once, when they are created. The id comes from the
    /// control's own event map, which a message updates only when the set of
    /// handled events changes - Swift keeps a handler id for as long as the
    /// element handles that event, so a control nobody has said anything about
    /// goes on reporting the right thing.
    /// </remarks>
    internal void Raise(object? sender, SwiftEvent name, byte[]? payload = null)
    {
        if (_rendering)
        {
            return;
        }

        if (sender is BindableObject control
            && control.GetValue(ElementProperty) is RenderedElement element
            && element.Events?.TryGetValue(name, out int id) == true)
        {
            _dispatch(id, payload);
        }
    }

    /// <summary>
    /// The same, for an event an APPLICATION raises from a control of its own -
    /// what the <see cref="StateUIRaise"/> a registration is handed comes
    /// through.
    /// </summary>
    /// <remarks>
    /// By NAME, because an application's vocabulary is open and has no members
    /// to be found under - so it is hashed once per event fired rather than
    /// once per property of every render. Its own half of the map first, then
    /// the library's: a registration free to call its event whatever it likes
    /// is free to call it <c>clicked</c>, and a name the library also has
    /// arrives under the member, whoever declared it.
    /// </remarks>
    /// <param name="sender">The control whose event fired.</param>
    /// <param name="name">The event's name, as the Swift side listens for it.</param>
    /// <param name="payload">One typed value per interesting fact, in a fixed order.</param>
    internal void Raise(object? sender, string name, params SwiftWireValue[] payload)
    {
        if (_rendering)
        {
            return;
        }

        if (sender is not BindableObject control
            || control.GetValue(ElementProperty) is not RenderedElement element)
        {
            return;
        }

        if (element.OwnEvents?.TryGetValue(name, out int own) == true)
        {
            _dispatch(own, SwiftWire.WritePayload(payload));
            return;
        }

        if (SwiftTokenNames<SwiftEvent>.Parse(name) is SwiftEvent raised
            && raised != SwiftEvent.None
            && element.Events?.TryGetValue(raised, out int id) == true)
        {
            _dispatch(id, SwiftWire.WritePayload(payload));
        }
    }

    /// <summary>
    /// Reports an event whose sender is not a control, with the handler id read
    /// from the node by whoever holds it.
    /// </summary>
    /// <remarks>
    /// The application is the one thing this is for: it is not a
    /// <see cref="BindableObject"/>, so there is nowhere to hang a
    /// <c>RenderedElement</c> and <see cref="Raise(object?, SwiftEvent, byte[])"/>
    /// has nothing to look the id up on. The <c>_rendering</c> guard is the same
    /// one and matters for the same reason - a report made from inside a message
    /// is a resync.
    /// </remarks>
    /// <param name="handler">The id the application's node carries.</param>
    internal void Announce(int handler)
    {
        if (_rendering)
        {
            return;
        }

        _dispatch(handler, null);
    }

    /// <summary>The event carried one text - an Entry's new value, a query.</summary>
    internal void Raise(object? sender, SwiftEvent name, string payload) =>
        Raise(sender, name, SwiftWire.WritePayload(SwiftWireValue.Of(payload)));

    /// <summary>
    /// The event carried one QUANTITY - a slider's value, an index, a
    /// position. A member of a vocabulary is not one: see
    /// <see cref="SwiftWireValue.OfMember"/>.
    /// </summary>
    internal void Raise(object? sender, SwiftEvent name, double payload) =>
        Raise(sender, name, SwiftWire.WritePayload(SwiftWireValue.Of(payload)));

    /// <summary>The event carried one true-or-false - a toggle, a focus.</summary>
    internal void Raise(object? sender, SwiftEvent name, bool payload) =>
        Raise(sender, name, SwiftWire.WritePayload(SwiftWireValue.Of(payload)));

    /// <summary>
    /// The event carried typed values - one per property of its EventArgs, in
    /// the order MAUI declares them. None crosses no bytes at all.
    /// </summary>
    internal void Raise(object? sender, SwiftEvent name, params SwiftWireValue[] payload) =>
        Raise(sender, name, SwiftWire.WritePayload(payload));

    /// <summary>
    /// Subscribes a window's lifecycle events, once, when the window is made.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The same subscribe-once rule every control follows: the handler id is
    /// read off the window when the event fires, so a render can change the
    /// handlers without rewiring anything - and a window whose tree says
    /// nothing about its lifetime reports nothing,
    /// <see cref="Raise(object?, SwiftEvent, byte[])"/> finding no id to quote.
    /// </para>
    /// <para>
    /// The names are MAUI's <see cref="Window"/> events, which are the
    /// application's whole cross-platform lifecycle: <c>Application.OnStart</c>,
    /// <c>OnSleep</c> and <c>OnResume</c> are the same moments - created,
    /// stopped, resumed - declared as protected virtuals on the app's own App
    /// subclass, which this library cannot reach, so they are listened for
    /// here.
    /// </para>
    /// <para>
    /// TWO THINGS LEAVE THIS METHOD AND THEY ARE NOT THE SAME. The six RAISES
    /// keep their <c>sender</c> and are therefore per window: <c>onActivated</c>
    /// and its siblings on a Swift <c>Window</c> are about THAT window, always.
    /// The four <see cref="StateUIEnvironment.WindowPhase"/> pushes below do
    /// not - domain 7 carries a phase and no address - so the
    /// <c>WindowInfo</c> an <c>@Environment</c> resolves is the APPLICATION's
    /// phase, moved by whichever window reported last. That is what MAUI's own
    /// <c>OnStart</c>/<c>OnSleep</c>/<c>OnResume</c> are too, and it is
    /// documented as such on the Swift side; a view that needs ONE window's
    /// phase takes it from that window's handlers, which carry their sender.
    /// </para>
    /// </remarks>
    internal void WireWindow(Window window)
    {
        window.Created += (sender, _) => Raise(sender, SwiftEvent.Created);
        window.Activated += (sender, _) => Raise(sender, SwiftEvent.Activated);
        window.Deactivated += (sender, _) => Raise(sender, SwiftEvent.Deactivated);
        window.Stopped += (sender, _) => Raise(sender, SwiftEvent.Stopped);
        window.Resumed += (sender, _) => Raise(sender, SwiftEvent.Resumed);
        window.Destroying += (sender, _) => Raise(sender, SwiftEvent.Destroying);

        // And the same moments as STATE, for the WindowInfo provider - the
        // events answer a handler, the phase answers a view that only wants
        // to know where things stand. Resumed reports deactivated: the window
        // is visible again but not yet active, and the platforms that mean
        // more raise Activated right after. Created and Destroying move no
        // phase - one precedes the first render, the other ends the process.
        window.Activated += (_, _) => StateUIEnvironment.WindowPhase(SwiftWindowPhase.Activated);
        window.Deactivated += (_, _) => StateUIEnvironment.WindowPhase(SwiftWindowPhase.Deactivated);
        window.Stopped += (_, _) => StateUIEnvironment.WindowPhase(SwiftWindowPhase.Stopped);
        window.Resumed += (_, _) => StateUIEnvironment.WindowPhase(SwiftWindowPhase.Deactivated);

        // And the one provider the platform raises nothing for: coming back is
        // where the locale is looked at again, the reader having had the whole
        // time in the background to move a zone or turn the clock over. See
        // StateUIEnvironment.CameBack.
        window.Resumed += (_, _) => StateUIEnvironment.CameBack();
    }

    // ---- Controls ----------------------------------------------------------

    /// <summary>A Label: MAUI's read-only text.</summary>
    private Label ReconcileLabel(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Label label)
        {
            label = new Label();
        }

        if (node.GetString(SwiftProp.Text) is string text) { label.Text = text; }
        node.SetColor(SwiftProp.TextColor, label, Label.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double characterSpacing) { label.CharacterSpacing = characterSpacing; }
        if (node.GetTextTransform(SwiftProp.TextTransform) is TextTransform labelCase) { label.TextTransform = labelCase; }
        if (node.GetTextAlignment(SwiftProp.HorizontalTextAlignment) is TextAlignment horizontal) { label.HorizontalTextAlignment = horizontal; }
        if (node.GetTextAlignment(SwiftProp.VerticalTextAlignment) is TextAlignment vertical) { label.VerticalTextAlignment = vertical; }
        if (node.GetLineBreakMode(SwiftProp.LineBreakMode) is LineBreakMode lineBreakMode) { label.LineBreakMode = lineBreakMode; }
        if (node.GetNumber(SwiftProp.LineHeight) is double lineHeight) { label.LineHeight = lineHeight; }
        if (node.GetInt(SwiftProp.MaxLines) is int maxLines) { label.MaxLines = maxLines; }
        if (node.GetTextDecorations(SwiftProp.TextDecorations) is TextDecorations decorations) { label.TextDecorations = decorations; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { label.Padding = padding; }

        ApplyFont(node, label);
        ApplyView(node, label);

        // Read by TYPE, the way a page's TitleView is: a Label has no children
        // of its own, and FormattedText is a sub-object rather than a value.
        foreach (SwiftNode child in node.Children ?? [])
        {
            if (child.Type == SwiftNodeType.FormattedString)
            {
                ApplyFormattedString(label, child);
            }
        }

        return Track(label, node);
    }

    /// <summary>
    /// The runs of a Label's FormattedText.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The spans are kept BY IDENTITY, through the same helper the menus use, for
    /// the reason every kept list has: a field that is not there did not change,
    /// so a patch about one run carries that run and nothing else. Rebuilding the
    /// collection from a patch would drop every run the message did not repeat.
    /// </para>
    /// <para>
    /// The FormattedString itself is made once and kept. Assigning a new one on
    /// every render would work and would throw away the spans with it, which is
    /// the same mistake one level up.
    /// </para>
    /// </remarks>
    private void ApplyFormattedString(Label label, SwiftNode node)
    {
        FormattedString formatted = label.FormattedText ?? new FormattedString();
        label.FormattedText = formatted;

        ApplyList(formatted.Spans, node, ApplySpan);
    }

    /// <summary>
    /// One run of text inside a Label. MAUI: Span.
    /// </summary>
    /// <remarks>
    /// Not a view, so there is no <c>ApplyView</c> here and no gestures: a Span
    /// carries text and font properties and nothing else. It is Tracked all the
    /// same, which is what gives it the identity the list above matches on.
    /// </remarks>
    private Span? ApplySpan(SwiftNode node, Span? existing)
    {
        Span span = Reuse(existing, node) ?? new Span();

        if (node.GetString(SwiftProp.Text) is string text) { span.Text = text; }
        node.SetColor(SwiftProp.TextColor, span, Span.TextColorProperty);
        node.SetColor(SwiftProp.BackgroundColor, span, Span.BackgroundColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double spacing) { span.CharacterSpacing = spacing; }
        if (node.GetTextTransform(SwiftProp.TextTransform) is TextTransform spanCase) { span.TextTransform = spanCase; }
        if (node.GetNumber(SwiftProp.LineHeight) is double lineHeight) { span.LineHeight = lineHeight; }
        if (node.GetTextDecorations(SwiftProp.TextDecorations) is TextDecorations decorations)
        {
            span.TextDecorations = decorations;
        }

        ApplyFont(node, span);

        return Track(span, node);
    }

    /// <summary>
    /// A Button. Its three events are subscribed where the control is CREATED,
    /// once - the handler id is read from the control when the event fires.
    /// </summary>
    private Button ReconcileButton(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Button button)
        {
            button = new Button();

            // Subscribed once, for the life of the control - see Raise.
            button.Clicked += (sender, _) => Raise(sender, SwiftEvent.Clicked);
            button.Pressed += (sender, _) => Raise(sender, SwiftEvent.Pressed);
            button.Released += (sender, _) => Raise(sender, SwiftEvent.Released);
        }

        if (node.GetString(SwiftProp.Text) is string text) { button.Text = text; }
        node.SetColor(SwiftProp.TextColor, button, Button.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double characterSpacing) { button.CharacterSpacing = characterSpacing; }
        if (node.GetTextTransform(SwiftProp.TextTransform) is TextTransform buttonCase) { button.TextTransform = buttonCase; }
        node.SetColor(SwiftProp.BorderColor, button, Button.BorderColorProperty);
        if (node.GetNumber(SwiftProp.BorderWidth) is double borderWidth) { button.BorderWidth = borderWidth; }
        if (node.GetInt(SwiftProp.CornerRadius) is int cornerRadius) { button.CornerRadius = cornerRadius; }
        if (node.GetLineBreakMode(SwiftProp.LineBreakMode) is LineBreakMode lineBreakMode) { button.LineBreakMode = lineBreakMode; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { button.Padding = padding; }

        node.SetImageSource(SwiftProp.ImageSource, button, Button.ImageSourceProperty);

        if (node.GetButtonContentLayout(SwiftProp.ContentLayout) is Button.ButtonContentLayout layout)
        {
            button.ContentLayout = layout;
        }

        ApplyFont(node, button);
        ApplyView(node, button);

        return Track(button, node);
    }

    /// <summary>
    /// An Entry. Assigning <c>Text</c> raises <c>TextChanged</c>, which the
    /// <c>_rendering</c> guard swallows - otherwise Swift would hear its own
    /// value back on every render.
    /// </summary>
    private Entry ReconcileEntry(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Entry entry)
        {
            entry = new Entry();

            entry.TextChanged += (sender, e) => Raise(sender, SwiftEvent.TextChanged, e.NewTextValue ?? "");
            entry.Completed += (sender, _) => Raise(sender, SwiftEvent.Completed);
        }

        // Text arrives only when it actually changed, so an Entry the user is
        // typing in is left alone - which is what keeps the caret where it is.
        if (node.GetString(SwiftProp.Text) is string text) { entry.Text = text; }
        node.SetColor(SwiftProp.TextColor, entry, Entry.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double characterSpacing) { entry.CharacterSpacing = characterSpacing; }
        if (node.GetTextTransform(SwiftProp.TextTransform) is TextTransform entryCase) { entry.TextTransform = entryCase; }
        if (node.GetString(SwiftProp.Placeholder) is string placeholder) { entry.Placeholder = placeholder; }
        node.SetColor(SwiftProp.PlaceholderColor, entry, Entry.PlaceholderColorProperty);
        if (node.GetBool(SwiftProp.IsPassword) is bool isPassword) { entry.IsPassword = isPassword; }
        if (node.GetBool(SwiftProp.IsReadOnly) is bool isReadOnly) { entry.IsReadOnly = isReadOnly; }
        if (node.GetKeyboard(SwiftProp.Keyboard) is Keyboard keyboard) { entry.Keyboard = keyboard; }
        if (node.GetInt(SwiftProp.MaxLength) is int maxLength) { entry.MaxLength = maxLength; }
        if (node.GetReturnType(SwiftProp.ReturnType) is ReturnType returnType) { entry.ReturnType = returnType; }
        if (node.GetClearButtonVisibility(SwiftProp.ClearButtonVisibility) is ClearButtonVisibility clearButton) { entry.ClearButtonVisibility = clearButton; }
        if (node.GetTextAlignment(SwiftProp.HorizontalTextAlignment) is TextAlignment horizontal) { entry.HorizontalTextAlignment = horizontal; }
        if (node.GetTextAlignment(SwiftProp.VerticalTextAlignment) is TextAlignment vertical) { entry.VerticalTextAlignment = vertical; }

        ApplyFont(node, entry);
        ApplyView(node, entry);

        return Track(entry, node);
    }

    /// <summary>
    /// An Image. Its source may be one file or one per theme, which is why it
    /// goes through <see cref="SwiftValues.SetImageSource"/> rather than being
    /// assigned.
    /// </summary>
    private Image ReconcileImage(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Image image)
        {
            image = new Image();
        }

        // A file in Resources/Images, by the name MAUI gives it once built - or
        // one per theme, which MAUI follows by itself.
        node.SetImageSource(SwiftProp.Source, image, Image.SourceProperty);
        if (node.GetAspect(SwiftProp.Aspect) is Aspect aspect) { image.Aspect = aspect; }
        if (node.GetBool(SwiftProp.IsOpaque) is bool isOpaque) { image.IsOpaque = isOpaque; }

        ApplyView(node, image);

        return Track(image, node);
    }

    /// <summary>
    /// An ImageButton: a Button whose caption is a picture.
    /// </summary>
    /// <remarks>
    /// Its three events are subscribed where the control is CREATED, once, the
    /// same as a Button's - the handler id is read from the control when the
    /// event fires.
    /// </remarks>
    private ImageButton ReconcileImageButton(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not ImageButton button)
        {
            button = new ImageButton();

            button.Clicked += (sender, _) => Raise(sender, SwiftEvent.Clicked);
            button.Pressed += (sender, _) => Raise(sender, SwiftEvent.Pressed);
            button.Released += (sender, _) => Raise(sender, SwiftEvent.Released);
        }

        node.SetImageSource(SwiftProp.Source, button, ImageButton.SourceProperty);
        if (node.GetAspect(SwiftProp.Aspect) is Aspect aspect) { button.Aspect = aspect; }
        if (node.GetBool(SwiftProp.IsOpaque) is bool isOpaque) { button.IsOpaque = isOpaque; }
        node.SetColor(SwiftProp.BorderColor, button, ImageButton.BorderColorProperty);
        if (node.GetNumber(SwiftProp.BorderWidth) is double borderWidth) { button.BorderWidth = borderWidth; }
        if (node.GetInt(SwiftProp.CornerRadius) is int cornerRadius) { button.CornerRadius = cornerRadius; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { button.Padding = padding; }

        ApplyView(node, button);

        return Track(button, node);
    }

    /// <summary>An Editor: an Entry with room, and the same guard on Text.</summary>
    private Editor ReconcileEditor(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Editor editor)
        {
            editor = new Editor();

            editor.TextChanged += (sender, e) => Raise(sender, SwiftEvent.TextChanged, e.NewTextValue ?? "");
            editor.Completed += (sender, _) => Raise(sender, SwiftEvent.Completed);
        }

        if (node.GetString(SwiftProp.Text) is string text) { editor.Text = text; }
        node.SetColor(SwiftProp.TextColor, editor, Editor.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double spacing) { editor.CharacterSpacing = spacing; }
        if (node.GetTextTransform(SwiftProp.TextTransform) is TextTransform editorCase) { editor.TextTransform = editorCase; }
        if (node.GetString(SwiftProp.Placeholder) is string placeholder) { editor.Placeholder = placeholder; }
        node.SetColor(SwiftProp.PlaceholderColor, editor, Editor.PlaceholderColorProperty);
        if (node.GetBool(SwiftProp.IsReadOnly) is bool isReadOnly) { editor.IsReadOnly = isReadOnly; }
        if (node.GetInt(SwiftProp.MaxLength) is int maxLength) { editor.MaxLength = maxLength; }
        if (node.GetKeyboard(SwiftProp.Keyboard) is Keyboard keyboard) { editor.Keyboard = keyboard; }
        if (node.GetEditorAutoSize(SwiftProp.AutoSize) is EditorAutoSizeOption autoSize) { editor.AutoSize = autoSize; }
        if (node.GetTextAlignment(SwiftProp.HorizontalTextAlignment) is TextAlignment horizontal) { editor.HorizontalTextAlignment = horizontal; }
        if (node.GetTextAlignment(SwiftProp.VerticalTextAlignment) is TextAlignment vertical) { editor.VerticalTextAlignment = vertical; }

        ApplyFont(node, editor);
        ApplyView(node, editor);

        return Track(editor, node);
    }

    /// <summary>A Picker. The list goes in before the chosen index.</summary>
    private Picker ReconcilePicker(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Picker picker)
        {
            picker = new Picker();

            picker.SelectedIndexChanged += (sender, _) =>
                Raise(sender, SwiftEvent.SelectedIndexChanged, (double)picker.SelectedIndex);
        }

        // The list before the choice: an index means nothing until there is
        // something to count.
        if (node.GetStrings(SwiftProp.ItemsSource) is string[] items) { picker.ItemsSource = items; }
        if (node.GetInt(SwiftProp.SelectedIndex) is int selected) { picker.SelectedIndex = selected; }
        if (node.GetString(SwiftProp.Title) is string title) { picker.Title = title; }
        node.SetColor(SwiftProp.TitleColor, picker, Picker.TitleColorProperty);
        node.SetColor(SwiftProp.TextColor, picker, Picker.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double spacing) { picker.CharacterSpacing = spacing; }
        if (node.GetTextAlignment(SwiftProp.HorizontalTextAlignment) is TextAlignment horizontal) { picker.HorizontalTextAlignment = horizontal; }
        if (node.GetTextAlignment(SwiftProp.VerticalTextAlignment) is TextAlignment vertical) { picker.VerticalTextAlignment = vertical; }

        ApplyFont(node, picker);
        ApplyView(node, picker);

        return Track(picker, node);
    }

    /// <summary>
    /// A DatePicker. The range goes in before the date, since MAUI clamps a
    /// date into it as it is set.
    /// </summary>
    private DatePicker ReconcileDatePicker(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not DatePicker picker)
        {
            picker = new DatePicker();

            picker.DateSelected += (sender, _) => Raise(sender, SwiftEvent.DateSelected, Day(picker.Date));
        }

        // The range before the date, for the same reason a Slider takes its
        // minimum first: MAUI clamps what is outside it.
        if (node.GetDate(SwiftProp.MinimumDate) is DateTime minimum) { picker.MinimumDate = minimum; }
        if (node.GetDate(SwiftProp.MaximumDate) is DateTime maximum) { picker.MaximumDate = maximum; }
        if (node.GetDate(SwiftProp.Date) is DateTime date) { picker.Date = date; }
        if (node.GetString(SwiftProp.Format) is string format) { picker.Format = format; }
        node.SetColor(SwiftProp.TextColor, picker, DatePicker.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double spacing) { picker.CharacterSpacing = spacing; }

        ApplyFont(node, picker);
        ApplyView(node, picker);

        return Track(picker, node);
    }

    /// <summary>A BoxView: a rectangle of colour.</summary>
    /// <summary>
    /// Reports a view's frame - in its parent and in the window, one payload -
    /// whenever it settles somewhere new, when the tree asked to hear.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The payload is one list of eight numbers - x, y, width, height,
    /// windowX, windowY, safeX, safeY - every coordinate space in one report
    /// so the choice of space never has to cross the boundary.
    /// </para>
    /// <para>
    /// One layout pass writes X, Y, Width, Height and Frame each, so the
    /// report is deduplicated against the last payload sent - the burst
    /// collapses to one Raise. Loaded reports too: reparenting moves the
    /// window origin without touching the view's own frame, and an attach is
    /// when that becomes visible.
    /// </para>
    /// </remarks>
    private void WatchFrame(VisualElement view, RenderedElement element)
    {
        if (element.Events?.ContainsKey(SwiftEvent.FrameChanged) != true
            || !(element.Observed ??= []).Add(SwiftEvent.FrameChanged))
        {
            return;
        }

        double[]? reported = null;

        // The ancestors being listened to, so leaving the window - or moving
        // to another parent - lets go of every one of them.
        List<(VisualElement Holder, PropertyChangedEventHandler Handler)> ancestors = [];

        void Report()
        {
            // The window and safe-area origins depend on the ANCESTORS -
            // their frames, and any scroll among them - so a view that asked
            // about its frame is listening to the whole chain, attached here
            // on the first report and again on every attach. Scrolling a page
            // under a `.global` handler is a real change to the answer, and
            // it arrives without the view's own frame moving an inch.
            if (ancestors.Count == 0)
            {
                AttachAncestors();
            }

            var frame = view.Frame;
            var (windowX, windowY) = WindowOrigin(view);
            var (safeLeft, safeTop) = SafeAreaOrigin(view);

            double[] payload =
            [
                frame.X, frame.Y, frame.Width, frame.Height,
                frame.X + windowX, frame.Y + windowY,
                frame.X + windowX - safeLeft, frame.Y + windowY - safeTop,
            ];

            if (reported is not null && payload.AsSpan().SequenceEqual(reported))
            {
                return;
            }

            reported = payload;
            Raise(view, SwiftEvent.FrameChanged, SwiftWireValue.Of(payload));
        }

        void AttachAncestors()
        {
            for (Element? step = view.Parent; step is VisualElement parent; step = parent.Parent)
            {
                PropertyChangedEventHandler moved = (_, e) =>
                {
                    if (e.PropertyName is nameof(VisualElement.X) or nameof(VisualElement.Y)
                        or nameof(VisualElement.Width) or nameof(VisualElement.Height)
                        or nameof(VisualElement.Frame)
                        or nameof(ScrollView.ScrollX) or nameof(ScrollView.ScrollY))
                    {
                        Report();
                    }
                };

                parent.PropertyChanged += moved;
                ancestors.Add((parent, moved));
            }
        }

        void DetachAncestors()
        {
            foreach (var (holder, handler) in ancestors)
            {
                holder.PropertyChanged -= handler;
            }

            ancestors.Clear();
        }

        view.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(VisualElement.X) or nameof(VisualElement.Y)
                or nameof(VisualElement.Width) or nameof(VisualElement.Height)
                or nameof(VisualElement.Frame))
            {
                Report();
            }
        };

        // An attach is when the chain above is real - and a REATTACH is when
        // it may be a different chain, so the old subscriptions go first.
        view.Loaded += (_, _) =>
        {
            DetachAncestors();
            AttachAncestors();
            Report();
        };

        view.Unloaded += (_, _) => DetachAncestors();
    }

    /// <summary>
    /// Where a view's parent sits in the window: every ancestor's frame
    /// offset added up, scroll positions subtracted on the way through.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The walk ends where the parent stops being a VisualElement, which is
    /// the page's window - so the answer is window coordinates, wherever the
    /// window itself is on the desktop. A ScrollView's content keeps its own
    /// coordinates while the platform scrolls it, ScrollX/ScrollY carrying
    /// the offset - subtracting them is what turns content coordinates into
    /// viewport ones. Translation, rotation and scale are transforms, which
    /// MAUI keeps off Frame entirely; this reports layout, as the Swift side
    /// documents.
    /// </para>
    /// <para>
    /// THE WALK STOPS AT THE VIEW'S OWN PAGE, and the platform is asked where
    /// that page sits: a native container the frames know nothing about puts
    /// it below the bars, while its own Frame stays at zero - measured on an
    /// iPhone 15 Pro, ContentPage.Frame at 0,0 with its platform view sitting
    /// at 0,97.7 in the window, and the same on a CPH2363, 91dp of status bar
    /// and toolbar in no Frame anywhere. The answer REPLACES the MAUI-side
    /// placement of the page - only of it, so everything beneath still
    /// reports layout, transforms staying invisible as documented.
    /// </para>
    /// <para>
    /// The page rather than the OUTERMOST element, which is the difference
    /// between a right answer and one a whole bar short: a page inside a
    /// NavigationPage inside a FlyoutPage has ancestors of its own, and those
    /// span the window, so their platform views answer zero and the bar
    /// under which THIS page was parked goes unaccounted. Measured on an
    /// iPhone 15 Pro: a panel whose top edge is 240.3 points down the screen
    /// (721 of 2556 pixels at 3x) reported window 142 - short by the 97.7 of
    /// chrome - and 240 once the walk stopped at its page.
    /// </para>
    /// </remarks>
    private static (double X, double Y) WindowOrigin(VisualElement view)
    {
        double x = 0, y = 0;
        VisualElement root = view;

        for (Element? step = view.Parent; step is VisualElement parent; step = parent.Parent)
        {
            x += parent.Frame.X;
            y += parent.Frame.Y;

            if (parent is ScrollView scroll)
            {
                x -= scroll.ScrollX;
                y -= scroll.ScrollY;
            }

            root = parent;

            // The view's own PAGE is where the MAUI walk stops and the
            // platform answers: everything above the page is arrangement the
            // page's platform placement already carries.
            if (parent is Page)
            {
                break;
            }
        }

#if IOS || MACCATALYST
        if (root != view
            && root.Handler?.PlatformView is UIKit.UIView platform
            && platform.Window is not null)
        {
            var origin = platform.ConvertPointToView(CoreGraphics.CGPoint.Empty, platform.Window);
            x += origin.X.Value - root.Frame.X;
            y += origin.Y.Value - root.Frame.Y;
        }
#elif ANDROID
        if (root != view
            && root.Handler?.PlatformView is Android.Views.View platform
            && platform.IsAttachedToWindow
            && platform.Context is Android.Content.Context context)
        {
            var location = new int[2];
            platform.GetLocationInWindow(location);
            x += Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, location[0]) - root.Frame.X;
            y += Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, location[1]) - root.Frame.Y;
        }
#elif WINDOWS
        // The same question WinUI's way: transform this element's own origin
        // into the coordinate space of the window's root visual, which is what
        // TransformToVisual(null) answers. XAML works in the effective pixels
        // MAUI calls units here, so nothing has to be scaled.
        //
        // Without it a report is out by whatever chrome the page sits inside -
        // measured, the Measuring a frame sample saying
        // `window 1330, 110` for a panel whose corner sat at 1396, 244.
        if (root != view
            && root.Handler?.PlatformView is Microsoft.UI.Xaml.FrameworkElement platform
            && platform.XamlRoot is not null)
        {
            Windows.Foundation.Point origin = platform
                .TransformToVisual(null)
                .TransformPoint(new Windows.Foundation.Point(0, 0));

            x += origin.X - root.Frame.X;
            y += origin.Y - root.Frame.Y;
        }
#endif

        return (x, y);
    }

    /// <summary>
    /// Where content can safely sit, as a window-coordinate origin: the
    /// outermost element's place in the window plus whatever insets ITS
    /// platform view still carries.
    /// </summary>
    /// <remarks>
    /// The WINDOW's own insets are the wrong ruler: a page under a bar is
    /// parked BELOW it, and the bar sits inside the window's safe area - so a
    /// view driven to the very top of the visible content still read 40 on an
    /// iPhone and 58 on Catalyst (measured), and zero was
    /// unreachable. And the ruler is the view's own PAGE, not the outermost
    /// ancestor: the arrangement's root spans the whole window and its insets
    /// carry only the status bar - measured on an iPhone 15 Pro, a panel at
    /// window 142 read safe 83 (142 - 59) through the outermost view, where
    /// the page's own view sits below the navigation bar too and answers 44,
    /// zero landing exactly on the visible content top (pixel-probed: the
    /// bar's last row at 97.5, and 142 - 97.5 is what the label shows).
    /// The platform computes the residual per view - a UIView not under any
    /// bar carries zero SafeAreaInsets - so the page is asked for its insets
    /// on top of where it sits, and a view at the top of its page's content
    /// reads zero everywhere. Android arranges the content inside the bars,
    /// so the page's origin alone IS the safe origin - measured on an
    /// emulator, a panel at window 146 reads safe 42, and scrolling it under
    /// the toolbar takes the reading negative; Windows has nothing to
    /// be safe from and a headless test has no platform, so there the answer
    /// stays zero and <c>.safeArea</c> agrees with <c>.global</c>.
    /// </remarks>
    private static (double Left, double Top) SafeAreaOrigin(VisualElement view)
    {
#if IOS || MACCATALYST || ANDROID || WINDOWS
        VisualElement root = view;

        for (Element? step = view.Parent; step is VisualElement parent; step = parent.Parent)
        {
            root = parent;

            if (parent is Page)
            {
                break;
            }
        }
#endif
#if IOS || MACCATALYST
        if (root.Handler?.PlatformView is UIKit.UIView platform && platform.Window is not null)
        {
            var origin = platform.ConvertPointToView(CoreGraphics.CGPoint.Empty, platform.Window);
            var insets = platform.SafeAreaInsets;
            return (origin.X.Value + insets.Left.Value, origin.Y.Value + insets.Top.Value);
        }
#elif ANDROID
        if (root.Handler?.PlatformView is Android.Views.View platform
            && platform.IsAttachedToWindow
            && platform.Context is Android.Content.Context context)
        {
            var location = new int[2];
            platform.GetLocationInWindow(location);
            return (Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, location[0]),
                    Microsoft.Maui.Platform.ContextExtensions.FromPixels(context, location[1]));
        }
#elif WINDOWS
        // Android's answer for Android's reason: a page is arranged BELOW the
        // chrome around it rather than under it, so where the page's own root
        // sits IS where content can safely start, and a view at the top of a
        // page reads zero. There is no inset to add on top - a desktop window
        // has no notch and no status bar.
        if (root.Handler?.PlatformView is Microsoft.UI.Xaml.FrameworkElement platform
            && platform.XamlRoot is not null)
        {
            Windows.Foundation.Point origin = platform
                .TransformToVisual(null)
                .TransformPoint(new Windows.Foundation.Point(0, 0));

            return (origin.X, origin.Y);
        }
#else
        _ = view;
#endif
        return (0, 0);
    }

    private BoxView ReconcileBoxView(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not BoxView box)
        {
            box = new BoxView();
        }

        node.SetColor(SwiftProp.Color, box, BoxView.ColorProperty);
        if (node.GetCornerRadius(SwiftProp.CornerRadius) is CornerRadius radius) { box.CornerRadius = radius; }

        ApplyView(node, box);

        return Track(box, node);
    }

    /// <summary>A Border, and the single view it holds.</summary>
    private Border ReconcileBorder(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Border border)
        {
            border = new Border();
        }

        // A Border's stroke is a Brush, so it takes a gradient as readily as a
        // colour - and SetBrush is what tells the two apart.
        node.SetBrush(SwiftProp.Stroke, border, Border.StrokeProperty);
        if (node.GetNumber(SwiftProp.StrokeThickness) is double thickness) { border.StrokeThickness = thickness; }
        if (node.GetStrokeShape(SwiftProp.StrokeShape) is IShape shape) { border.StrokeShape = shape; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { border.Padding = padding; }

        // The rest of the stroke, which MAUI declares on Border separately from
        // the identical set on Shape - two classes sharing only IStroke, so
        // these are Border's own properties and not the shape arm's.
        if (node.GetDoubleCollection(SwiftProp.StrokeDashArray) is DoubleCollection dashes) { border.StrokeDashArray = dashes; }
        if (node.GetNumber(SwiftProp.StrokeDashOffset) is double dashOffset) { border.StrokeDashOffset = dashOffset; }
        if (node.GetPenLineCap(SwiftProp.StrokeLineCap) is PenLineCap cap) { border.StrokeLineCap = cap; }
        if (node.GetPenLineJoin(SwiftProp.StrokeLineJoin) is PenLineJoin join) { border.StrokeLineJoin = join; }
        if (node.GetNumber(SwiftProp.StrokeMiterLimit) is double miter) { border.StrokeMiterLimit = miter; }

        ApplyView(node, border);
        Track(border, node);

        // A Border holds one view, which is MAUI's own shape and what the Swift
        // side tells an author: put a layout in it for more than one thing. So
        // the first is the content and the rest are the author's mistake - not
        // a ScrollView, which wraps because a scroller full of rows is the
        // ordinary way to write one. An arranged message with nothing laid says
        // the view LEFT.
        if (Laid(node) is { Count: > 0 } children)
        {
            border.Content = Reconcile(border.Content, children[0]);
        }
        else if (node.Arranged)
        {
            border.Content = null;
        }

        return border;
    }

    // ---- Shapes ------------------------------------------------------------
    //
    // MAUI declares Fill, Stroke and the rest once, on Shape, and every shape
    // inherits them - so they are applied by one method here, exactly as the
    // View tier is. What each Reconcile below carries is only what that one
    // shape has of its own.

    /// <summary>
    /// The properties MAUI declares on <see cref="Shape"/>, which every shape
    /// has.
    /// </summary>
    private static void ApplyShape(SwiftNode node, Shape shape)
    {
        node.SetBrush(SwiftProp.Fill, shape, Shape.FillProperty);
        node.SetBrush(SwiftProp.Stroke, shape, Shape.StrokeProperty);

        if (node.GetNumber(SwiftProp.StrokeThickness) is double thickness) { shape.StrokeThickness = thickness; }
        if (node.GetDoubleCollection(SwiftProp.StrokeDashArray) is DoubleCollection dashes) { shape.StrokeDashArray = dashes; }
        if (node.GetNumber(SwiftProp.StrokeDashOffset) is double dashOffset) { shape.StrokeDashOffset = dashOffset; }
        if (node.GetPenLineCap(SwiftProp.StrokeLineCap) is PenLineCap cap) { shape.StrokeLineCap = cap; }
        if (node.GetPenLineJoin(SwiftProp.StrokeLineJoin) is PenLineJoin join) { shape.StrokeLineJoin = join; }
        if (node.GetNumber(SwiftProp.StrokeMiterLimit) is double miter) { shape.StrokeMiterLimit = miter; }
        if (node.GetStretch(SwiftProp.Aspect) is Stretch aspect) { shape.Aspect = aspect; }
    }

    /// <summary>A rectangle, with corners it may round itself.</summary>
    private Rectangle ReconcileRectangle(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Rectangle rectangle)
        {
            rectangle = new Rectangle();
        }

        if (node.GetNumber(SwiftProp.RadiusX) is double radiusX) { rectangle.RadiusX = radiusX; }
        if (node.GetNumber(SwiftProp.RadiusY) is double radiusY) { rectangle.RadiusY = radiusY; }

        ApplyShape(node, rectangle);
        ApplyView(node, rectangle);

        return Track(rectangle, node);
    }

    /// <summary>The same, with each corner named separately.</summary>
    private RoundRectangle ReconcileRoundRectangle(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not RoundRectangle rectangle)
        {
            rectangle = new RoundRectangle();
        }

        if (node.GetCornerRadius(SwiftProp.CornerRadius) is CornerRadius radius) { rectangle.CornerRadius = radius; }

        ApplyShape(node, rectangle);
        ApplyView(node, rectangle);

        return Track(rectangle, node);
    }

    /// <summary>An oval filling the room it is given.</summary>
    private Ellipse ReconcileEllipse(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Ellipse ellipse)
        {
            ellipse = new Ellipse();
        }

        ApplyShape(node, ellipse);
        ApplyView(node, ellipse);

        return Track(ellipse, node);
    }

    /// <summary>A straight line between two points.</summary>
    private Line ReconcileLine(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Line line)
        {
            line = new Line();
        }

        if (node.GetNumber(SwiftProp.X1) is double x1) { line.X1 = x1; }
        if (node.GetNumber(SwiftProp.Y1) is double y1) { line.Y1 = y1; }
        if (node.GetNumber(SwiftProp.X2) is double x2) { line.X2 = x2; }
        if (node.GetNumber(SwiftProp.Y2) is double y2) { line.Y2 = y2; }

        ApplyShape(node, line);
        ApplyView(node, line);

        return Track(line, node);
    }

    /// <summary>An outline written in SVG path syntax.</summary>
    private Path ReconcilePath(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Path path)
        {
            path = new Path();
        }

        if (node.GetGeometry(SwiftProp.Data) is Geometry data) { path.Data = data; }

        ApplyShape(node, path);
        ApplyView(node, path);

        return Track(path, node);
    }

    /// <summary>A closed outline through a list of points.</summary>
    private Polygon ReconcilePolygon(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Polygon polygon)
        {
            polygon = new Polygon();
        }

        if (node.GetPoints(SwiftProp.Points) is PointCollection points) { polygon.Points = points; }
        if (node.GetFillRule(SwiftProp.FillRule) is FillRule rule) { polygon.FillRule = rule; }

        ApplyShape(node, polygon);
        ApplyView(node, polygon);

        return Track(polygon, node);
    }

    /// <summary>The same list, left open.</summary>
    private Polyline ReconcilePolyline(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Polyline polyline)
        {
            polyline = new Polyline();
        }

        if (node.GetPoints(SwiftProp.Points) is PointCollection points) { polyline.Points = points; }
        if (node.GetFillRule(SwiftProp.FillRule) is FillRule rule) { polyline.FillRule = rule; }

        ApplyShape(node, polyline);
        ApplyView(node, polyline);

        return Track(polyline, node);
    }

    /// <summary>
    /// A canvas, and the instructions the Swift side sent for drawing on it.
    /// </summary>
    /// <remarks>
    /// The drawable is replaced rather than changed - a drawing is a value, and
    /// the message only carries one when it differs - and the view is told to
    /// redraw, which nothing else would do for it.
    /// </remarks>
    private GraphicsView ReconcileGraphicsView(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not GraphicsView graphics)
        {
            graphics = new GraphicsView();

            // Subscribed where the view is made, once, and reading the handler
            // id off the view when the touch arrives - the rule every event
            // here follows.
            graphics.StartInteraction += (_, e) => Raise(graphics, SwiftEvent.StartInteraction, At(e));
            graphics.DragInteraction += (_, e) => Raise(graphics, SwiftEvent.DragInteraction, At(e));
            graphics.EndInteraction += (_, e) => Raise(graphics, SwiftEvent.EndInteraction, At(e));
        }

        if (node.GetDrawable(SwiftProp.Drawable) is IDrawable drawable)
        {
            graphics.Drawable = drawable;
            graphics.Invalidate();
        }

        ApplyView(node, graphics);

        return Track(graphics, node);
    }

    /// <summary>
    /// Where a touch was, in the canvas's own coordinates - the ones the drawing
    /// instructions use.
    /// </summary>
    /// <remarks>
    /// MAUI reports every finger; this carries the first, which is what a
    /// drawing surface acts on. A report with none is left empty, and the Swift
    /// side drops a payload it cannot read rather than inventing a point.
    /// </remarks>
    private static SwiftWireValue[] At(TouchEventArgs e) =>
        e.Touches is [PointF point, ..] ? [SwiftWireValue.Of(point.X, point.Y)] : [];

    /// <summary>
    /// A template that shows the view it is handed, rather than building one.
    /// </summary>
    /// <remarks>
    /// What replaces a MAUI DataTemplate here: the Swift side already described
    /// every row, every heading and every footer, so the template's whole job is
    /// to put the view it was given on screen.
    /// </remarks>
    private static DataTemplate Shown()
    {
        return new DataTemplate(() =>
        {
            var holder = new ContentView();
            holder.SetBinding(ContentView.ContentProperty, static (View item) => item);
            return holder;
        });
    }

    /// <summary>
    /// Whether an arranged message no longer names this identity - how a slot
    /// wrapper's leaving is recognized, there being no removal list to name
    /// it in.
    /// </summary>
    private static bool Absent(SwiftNode node, string key) =>
        node.Children?.Any(child => child.Key == key) != true;

    /// <summary>
    /// The one view a slot wrapper holds - a group's header or footer, a
    /// list's furniture, a title bar's three. A wrapper that arrives without
    /// its child keeps the view already there: an unchanged slot need not be
    /// repeated, the rule every patch follows.
    /// </summary>
    private View? Slot(View? existing, SwiftNode node)
    {
        return node.Children is [SwiftNode content, ..] ? Reconcile(existing, content) : existing;
    }

    /// <summary>
    /// The furniture an items view carries - an EmptyView, read from the
    /// wrapper node among the children.
    /// </summary>
    /// <remarks>
    /// Read BEFORE the items, because the slot count is what tells them apart
    /// from the whole child list. A slot that leaves arrives as a removal
    /// naming the wrapper node, and the properties do not remember where a
    /// view came from - which wrapper fills which slot is kept per control in
    /// <see cref="_furniture"/>.
    /// </remarks>
    private void ApplyFurniture(ItemsView view, SwiftNode node)
    {
        Dictionary<SwiftNodeType, string> filled = _furniture.GetOrCreateValue(view);

        // A slot that LEFT is recognized by its absence from an arranged
        // list: the wrapper is simply no longer among the children. The map
        // is what remembers which wrapper filled which slot - the properties
        // do not say where a view came from.
        if (node.Arranged)
        {
            foreach ((SwiftNodeType slot, string wrapper) in filled.Where(entry => Absent(node, entry.Value)).ToList())
            {
                switch (slot)
                {
                    case SwiftNodeType.EmptyView: view.EmptyView = null; break;
                }

                filled.Remove(slot);
            }
        }

        foreach (SwiftNode child in node.Children ?? [])
        {
            switch (child.Type)
            {
                case SwiftNodeType.EmptyView:
                    view.EmptyView = Slot(view.EmptyView as View, child);
                    filled[SwiftNodeType.EmptyView] = child.Key;
                    break;
            }
        }
    }

    /// <summary>
    /// The items view's node with its furniture taken out, so the items are
    /// what is left.
    /// </summary>
    private static SwiftNode Unfurnished(SwiftNode node)
    {
        return new SwiftNode
        {
            Id = node.Id,
            Type = node.Type,
            TypeName = node.TypeName,
            Arranged = node.Arranged,
            Children = node.Children
                ?.Where(child => child.Type != SwiftNodeType.EmptyView)
                .ToList(),
        };
    }

    /// <summary>
    /// Which wrapper node fills which furniture slot of an items view - a
    /// carousel's empty view. A removal names the NODE, and
    /// the properties do not remember where a view came from - this is the
    /// way back. Weak for the reason <c>_named</c> is: there is no one place
    /// a control is dropped.
    /// </summary>
    private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<ItemsView, Dictionary<SwiftNodeType, string>> _furniture = new();

    /// <summary>A carousel: one item at a time, swiped through.</summary>
    private CarouselView ReconcileCarouselView(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not CarouselView carousel)
        {
            carousel = new CarouselView
            {
                ItemTemplate = Shown(),
                ItemsSource = new ObservableCollection<View>(),
            };

            // The position, not the item: MAUI's CurrentItemChanged carries the
            // item, which on this side is a view the Swift code already has.
            carousel.PositionChanged += (_, e) => Raise(
                carousel, SwiftEvent.PositionChanged, (double)e.CurrentPosition);
        }

        if (node.GetBool(SwiftProp.Loop) is bool loop) { carousel.Loop = loop; }
        if (node.GetBool(SwiftProp.IsSwipeEnabled) is bool swipe) { carousel.IsSwipeEnabled = swipe; }
        if (node.GetBool(SwiftProp.IsBounceEnabled) is bool bounce) { carousel.IsBounceEnabled = bounce; }
        if (node.GetBool(SwiftProp.IsScrollAnimated) is bool animated) { carousel.IsScrollAnimated = animated; }
        if (node.GetThickness(SwiftProp.PeekAreaInsets) is Thickness peek) { carousel.PeekAreaInsets = peek; }
        if (node.GetScrollBarVisibility(SwiftProp.VerticalScrollBarVisibility) is ScrollBarVisibility vertical) { carousel.VerticalScrollBarVisibility = vertical; }
        if (node.GetScrollBarVisibility(SwiftProp.HorizontalScrollBarVisibility) is ScrollBarVisibility horizontal) { carousel.HorizontalScrollBarVisibility = horizontal; }

        // A carousel shows one item at a time, so MAUI types its layout as a
        // LinearItemsLayout: a grid is not one of the choices, and one that
        // arrives anyway is left alone rather than thrown at MAUI.
        if (node.GetItemsLayout(SwiftProp.ItemsLayout) is LinearItemsLayout linear) { carousel.ItemsLayout = linear; }

        ApplyView(node, carousel);
        Track(carousel, node);

        // The carousel's one piece of furniture is its EmptyView - it has no
        // header or footer to hang - and it travels the way a list's does.
        ApplyFurniture(carousel, node);

        if (carousel.ItemsSource is IList<View> items)
        {
            ApplyChildren(items, Unfurnished(node));
        }

        // After the items: a position points at one of them.
        if (node.GetInt(SwiftProp.Position) is int position) { carousel.Position = position; }

        return carousel;
    }

    /// <summary>The dots under a carousel.</summary>
    private IndicatorView ReconcileIndicatorView(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not IndicatorView indicator)
        {
            indicator = new IndicatorView();
        }

        // Dots described as views: MAUI's IndicatorTemplate, run in Swift -
        // the items ARE the views, so the template's whole job is to show
        // what it is handed, and MAUI derives Count from them. Installed only
        // when dots arrive: a count-form indicator keeps MAUI's own dots and
        // the two colours that paint them. FILLED BEFORE it is assigned - the
        // reverse drew nothing on Mac Catalyst, the platform building its
        // indicators from what the source held at that moment.
        if (node.Children is { Count: > 0 } && indicator.ItemsSource is not IList<View>)
        {
            var made = new ObservableCollection<View>();
            ApplyChildren(made, node);

            indicator.IndicatorTemplate = Shown();
            indicator.ItemsSource = made;
        }
        else if (indicator.ItemsSource is IList<View> dots)
        {
            ApplyChildren(dots, node);
        }

        if (node.GetInt(SwiftProp.Count) is int count) { indicator.Count = count; }
        if (node.GetInt(SwiftProp.Position) is int position) { indicator.Position = position; }
        node.SetColor(SwiftProp.IndicatorColor, indicator, IndicatorView.IndicatorColorProperty);
        node.SetColor(SwiftProp.SelectedIndicatorColor, indicator, IndicatorView.SelectedIndicatorColorProperty);
        if (node.GetNumber(SwiftProp.IndicatorSize) is double size) { indicator.IndicatorSize = size; }
        if (node.GetInt(SwiftProp.MaximumVisible) is int maximum) { indicator.MaximumVisible = maximum; }
        if (node.GetIndicatorShape(SwiftProp.IndicatorsShape) is IndicatorShape shape) { indicator.IndicatorsShape = shape; }
        if (node.GetBool(SwiftProp.HideSingle) is bool hide) { indicator.HideSingle = hide; }

        ApplyView(node, indicator);

        return Track(indicator, node);
    }

    /// <summary>
    /// A TimePicker. Its time is a <c>TimeSpan</c> - a length since midnight -
    /// which is what the three integers Swift sends describe.
    /// </summary>
    private TimePicker ReconcileTimePicker(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not TimePicker picker)
        {
            picker = new TimePicker();

            picker.TimeSelected += (sender, e) => Raise(sender, SwiftEvent.TimeSelected, Clock(e.NewTime));
        }

        if (node.GetTime(SwiftProp.Time) is TimeSpan time) { picker.Time = time; }
        if (node.GetString(SwiftProp.Format) is string format) { picker.Format = format; }
        node.SetColor(SwiftProp.TextColor, picker, TimePicker.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double spacing) { picker.CharacterSpacing = spacing; }

        ApplyFont(node, picker);
        ApplyView(node, picker);

        return Track(picker, node);
    }

    /// <summary>A Switch.</summary>
    private Switch ReconcileSwitch(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Switch control)
        {
            control = new Switch();

            // MAUI's ToggledEventArgs.Value, as the payload every event carries.
            control.Toggled += (sender, e) => Raise(sender, SwiftEvent.Toggled, e.Value);
        }

        if (node.GetBool(SwiftProp.IsToggled) is bool isToggled) { control.IsToggled = isToggled; }
        node.SetColor(SwiftProp.OnColor, control, Switch.OnColorProperty);
        node.SetColor(SwiftProp.ThumbColor, control, Switch.ThumbColorProperty);

        ApplyView(node, control);

        return Track(control, node);
    }

    /// <summary>A CheckBox.</summary>
    private CheckBox ReconcileCheckBox(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not CheckBox box)
        {
            box = new CheckBox();

            // MAUI's CheckedChangedEventArgs.Value, as the payload every event
            // carries.
            box.CheckedChanged += (sender, e) => Raise(sender, SwiftEvent.CheckedChanged, e.Value);
        }

        if (node.GetBool(SwiftProp.IsChecked) is bool isChecked) { box.IsChecked = isChecked; }
        node.SetColor(SwiftProp.Color, box, CheckBox.ColorProperty);

        ApplyView(node, box);

        return Track(box, node);
    }

    /// <summary>
    /// A RadioButton. Picking one clears its neighbours, and MAUI reports both -
    /// so the false arrives on the button that lost, with the id that button was
    /// given.
    /// </summary>
    private RadioButton ReconcileRadioButton(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not RadioButton button)
        {
            button = new RadioButton();

            button.CheckedChanged += (sender, e) => Raise(sender, SwiftEvent.CheckedChanged, e.Value);
        }

        // The group before the state: MAUI clears the others in the group as a
        // button becomes checked, and it can only do that once it knows which
        // group this is.
        // A NAME, riding the session's dictionary - a group is written by an
        // author and repeats across a tree, which is what a name is here.
        if (node.GetName(SwiftProp.GroupName) is string group) { button.GroupName = group; }
        if (node.GetString(SwiftProp.Content) is string content) { button.Content = content; }
        if (node.GetBool(SwiftProp.IsChecked) is bool isChecked) { button.IsChecked = isChecked; }
        node.SetColor(SwiftProp.TextColor, button, RadioButton.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double spacing) { button.CharacterSpacing = spacing; }
        if (node.GetTextTransform(SwiftProp.TextTransform) is TextTransform buttonCase) { button.TextTransform = buttonCase; }
        node.SetColor(SwiftProp.BorderColor, button, RadioButton.BorderColorProperty);
        if (node.GetNumber(SwiftProp.BorderWidth) is double borderWidth) { button.BorderWidth = borderWidth; }
        if (node.GetInt(SwiftProp.CornerRadius) is int cornerRadius) { button.CornerRadius = cornerRadius; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { button.Padding = padding; }

        ApplyFont(node, button);
        ApplyView(node, button);

        return Track(button, node);
    }

    /// <summary>
    /// A Slider. Maximum, then Minimum, then Value - MAUI clamps as it goes, so
    /// the range has to be right before the value arrives.
    /// </summary>
    private Slider ReconcileSlider(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Slider slider)
        {
            slider = new Slider();

            // The value crosses as its own bits - nothing is formatted, so
            // no locale can creep in anywhere.
            slider.ValueChanged += (sender, e) =>
                Raise(sender, SwiftEvent.ValueChanged, e.NewValue);

            slider.DragStarted += (sender, _) => Raise(sender, SwiftEvent.DragStarted);
            slider.DragCompleted += (sender, _) => Raise(sender, SwiftEvent.DragCompleted);
        }

        // Maximum, then Minimum, then Value: MAUI clamps a value into the range
        // as it is set, so the range has to be right before the value goes in.
        if (node.GetNumber(SwiftProp.Maximum) is double maximum) { slider.Maximum = maximum; }
        if (node.GetNumber(SwiftProp.Minimum) is double minimum) { slider.Minimum = minimum; }
        if (node.GetNumber(SwiftProp.Value) is double value) { slider.Value = value; }

        node.SetColor(SwiftProp.MinimumTrackColor, slider, Slider.MinimumTrackColorProperty);
        node.SetColor(SwiftProp.MaximumTrackColor, slider, Slider.MaximumTrackColorProperty);
        node.SetColor(SwiftProp.ThumbColor, slider, Slider.ThumbColorProperty);
        node.SetImageSource(SwiftProp.ThumbImageSource, slider, Slider.ThumbImageSourceProperty);

        ApplyView(node, slider);

        return Track(slider, node);
    }

    /// <summary>
    /// A Stepper. The range goes in before the value, for the reason a Slider's
    /// does: MAUI clamps what is outside it.
    /// </summary>
    private Stepper ReconcileStepper(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Stepper stepper)
        {
            stepper = new Stepper();

            // The value crosses as its own bits, like the Slider's.
            stepper.ValueChanged += (sender, e) => Raise(sender, SwiftEvent.ValueChanged, e.NewValue);
        }

        if (node.GetNumber(SwiftProp.Maximum) is double maximum) { stepper.Maximum = maximum; }
        if (node.GetNumber(SwiftProp.Minimum) is double minimum) { stepper.Minimum = minimum; }
        if (node.GetNumber(SwiftProp.Increment) is double increment) { stepper.Increment = increment; }
        if (node.GetNumber(SwiftProp.Value) is double value) { stepper.Value = value; }

        ApplyView(node, stepper);

        return Track(stepper, node);
    }

    /// <summary>
    /// A SearchBar. Assigning <c>Text</c> raises <c>TextChanged</c>, which the
    /// <c>_rendering</c> guard swallows - the same story as an Entry's.
    /// </summary>
    private SearchBar ReconcileSearchBar(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not SearchBar search)
        {
            search = new SearchBar();

            search.TextChanged += (sender, e) => Raise(sender, SwiftEvent.TextChanged, e.NewTextValue);
            search.SearchButtonPressed += (sender, _) => Raise(sender, SwiftEvent.SearchButtonPressed);
        }

        if (node.GetString(SwiftProp.Text) is string text) { search.Text = text; }
        node.SetColor(SwiftProp.TextColor, search, SearchBar.TextColorProperty);
        if (node.GetNumber(SwiftProp.CharacterSpacing) is double characterSpacing) { search.CharacterSpacing = characterSpacing; }
        if (node.GetTextTransform(SwiftProp.TextTransform) is TextTransform searchCase) { search.TextTransform = searchCase; }
        if (node.GetString(SwiftProp.Placeholder) is string placeholder) { search.Placeholder = placeholder; }
        node.SetColor(SwiftProp.PlaceholderColor, search, SearchBar.PlaceholderColorProperty);
        if (node.GetBool(SwiftProp.IsReadOnly) is bool isReadOnly) { search.IsReadOnly = isReadOnly; }
        if (node.GetInt(SwiftProp.MaxLength) is int maxLength) { search.MaxLength = maxLength; }
        if (node.GetKeyboard(SwiftProp.Keyboard) is Keyboard keyboard) { search.Keyboard = keyboard; }
        if (node.GetReturnType(SwiftProp.ReturnType) is ReturnType returnType) { search.ReturnType = returnType; }
        node.SetColor(SwiftProp.CancelButtonColor, search, SearchBar.CancelButtonColorProperty);
        node.SetColor(SwiftProp.SearchIconColor, search, SearchBar.SearchIconColorProperty);
        if (node.GetTextAlignment(SwiftProp.HorizontalTextAlignment) is TextAlignment horizontal) { search.HorizontalTextAlignment = horizontal; }
        if (node.GetTextAlignment(SwiftProp.VerticalTextAlignment) is TextAlignment vertical) { search.VerticalTextAlignment = vertical; }

        ApplyFont(node, search);
        ApplyView(node, search);

        return Track(search, node);
    }

    /// <summary>An ActivityIndicator: the spinner, and whether it spins.</summary>
    private ActivityIndicator ReconcileActivityIndicator(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not ActivityIndicator indicator)
        {
            indicator = new ActivityIndicator();
        }

        if (node.GetBool(SwiftProp.IsRunning) is bool isRunning) { indicator.IsRunning = isRunning; }
        node.SetColor(SwiftProp.Color, indicator, ActivityIndicator.ColorProperty);

        ApplyView(node, indicator);

        return Track(indicator, node);
    }

    /// <summary>A ProgressBar: how far along, from 0 to 1.</summary>
    private ProgressBar ReconcileProgressBar(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not ProgressBar bar)
        {
            bar = new ProgressBar();
        }

        if (node.GetNumber(SwiftProp.Progress) is double progress) { bar.Progress = progress; }
        node.SetColor(SwiftProp.ProgressColor, bar, ProgressBar.ProgressColorProperty);

        ApplyView(node, bar);

        return Track(bar, node);
    }

    /// <summary>
    /// A Grid. Where each child sits is an attached property on the child, read
    /// in <see cref="ApplyView"/>.
    /// </summary>
    /// <summary>
    /// The properties every layout has, whichever layout it is.
    /// </summary>
    /// <remarks>
    /// The Layout tier's counterpart to <see cref="ApplyView"/>: a modifier
    /// declared on LayoutProperties on the Swift side lands here once, for the
    /// stacks, the Grid, the AbsoluteLayout and the FlexLayout alike.
    /// </remarks>
    private static void ApplyLayout(SwiftNode node, Layout layout)
    {
        if (node.GetSafeAreaEdges(SwiftProp.SafeAreaEdges) is SafeAreaEdges safeArea) { layout.SafeAreaEdges = safeArea; }
        if (node.GetBool(SwiftProp.IsClippedToBounds) is bool clipped) { layout.IsClippedToBounds = clipped; }
        if (node.GetBool(SwiftProp.CascadeInputTransparent) is bool cascade) { layout.CascadeInputTransparent = cascade; }
    }

    private Grid ReconcileGrid(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not Grid grid)
        {
            grid = new Grid();
        }

        if (node.GetRowDefinitions(SwiftProp.RowDefinitions) is RowDefinitionCollection rows) { grid.RowDefinitions = rows; }
        if (node.GetColumnDefinitions(SwiftProp.ColumnDefinitions) is ColumnDefinitionCollection columns) { grid.ColumnDefinitions = columns; }
        if (node.GetNumber(SwiftProp.RowSpacing) is double rowSpacing) { grid.RowSpacing = rowSpacing; }
        if (node.GetNumber(SwiftProp.ColumnSpacing) is double columnSpacing) { grid.ColumnSpacing = columnSpacing; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { grid.Padding = padding; }
        ApplyLayout(node, grid);

        ApplyView(node, grid);
        Track(grid, node);
        ApplyChildren(grid.Children, node);

        return grid;
    }

    /// <summary>
    /// A vertical or horizontal stack. One method for both: the difference is
    /// the MAUI type, and nothing else about them differs.
    /// </summary>
    private T ReconcileStack<T>(SwiftNode node, View? existing) where T : StackBase, new()
    {
        if (Reuse(existing, node) is not T stack)
        {
            stack = new T();
        }

        if (node.GetNumber(SwiftProp.Spacing) is double spacing) { stack.Spacing = spacing; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { stack.Padding = padding; }
        ApplyLayout(node, stack);

        ApplyView(node, stack);
        Track(stack, node);
        ApplyChildren(stack.Children, node);

        return stack;
    }

    /// <summary>
    /// An AbsoluteLayout. Where each child sits is an attached property on the
    /// child, read in <see cref="ApplyView"/> - the layout itself has nothing of
    /// its own but a Padding.
    /// </summary>
    private AbsoluteLayout ReconcileAbsoluteLayout(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not AbsoluteLayout layout)
        {
            layout = new AbsoluteLayout();
        }

        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { layout.Padding = padding; }
        ApplyLayout(node, layout);

        ApplyView(node, layout);
        Track(layout, node);
        ApplyChildren(layout.Children, node);

        return layout;
    }

    /// <summary>
    /// A FlexLayout: CSS flexbox, which is what MAUI's is. What one child asks
    /// for is attached to the child and read in <see cref="ApplyView"/>.
    /// </summary>
    private FlexLayout ReconcileFlexLayout(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not FlexLayout layout)
        {
            layout = new FlexLayout();
        }

        if (node.GetFlexDirection(SwiftProp.Direction) is FlexDirection direction) { layout.Direction = direction; }
        if (node.GetFlexWrap(SwiftProp.Wrap) is FlexWrap wrap) { layout.Wrap = wrap; }
        if (node.GetFlexJustify(SwiftProp.JustifyContent) is FlexJustify justify) { layout.JustifyContent = justify; }
        if (node.GetFlexAlignItems(SwiftProp.AlignItems) is FlexAlignItems alignItems) { layout.AlignItems = alignItems; }
        if (node.GetFlexAlignContent(SwiftProp.AlignContent) is FlexAlignContent alignContent) { layout.AlignContent = alignContent; }
        if (node.GetFlexPosition(SwiftProp.Position) is FlexPosition position) { layout.Position = position; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { layout.Padding = padding; }
        ApplyLayout(node, layout);

        ApplyView(node, layout);
        Track(layout, node);
        ApplyChildren(layout.Children, node);

        return layout;
    }

    /// <summary>A ScrollView, and whatever has to go in its single Content.</summary>
    private ScrollView ReconcileScrollView(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not ScrollView scroll)
        {
            scroll = new ScrollView();

#if WINDOWS
            // A scroller CLIPS, and WINDOWS does not do it on its own.
            // Measured: a LazyList places its rows by arithmetic
            // inside an AbsoluteLayout taller than the scroller, and the rows
            // past the visible box were painted over whatever stood BELOW the
            // list - the sample's own caption and paragraph - with the layout
            // itself correct (scroller 207..507, caption at 517, rows 7 and 8
            // at 521 and 560).
            //
            // `IsClippedToBounds` does NOT do it: set on the ScrollView it
            // changed nothing there, measured. An explicit Clip does, and it
            // has to be re-stated on every resize because the geometry is a
            // rectangle in the view's own coordinates. Subscribed where the
            // control is CREATED, once, the way every other event here is.
            //
            // WINDOWS ONLY, and that is the whole point of the guard.
            // MEASURED on the other platforms: an Apple scroller scrolls
            // by moving its own BOUNDS, so a
            // clip rectangle written in the view's coordinates stays anchored
            // to the content's origin and everything past the first screenful
            // is masked away for ever. The gallery showed three cards of
            // fourteen on an iPhone and eight in a 900pt window, each being
            // what fitted when the clip was written. UIScrollView and
            // Android's ScrollView both clip to their bounds by themselves, so
            // there is nothing to add there - only Windows needs this.
            scroll.SizeChanged += (sender, _) =>
            {
                if (sender is not ScrollView resized) { return; }

                resized.Clip = resized.Width > 0 && resized.Height > 0
                    ? new RectangleGeometry(new Rect(0, 0, resized.Width, resized.Height))
                    : null;
            };
#endif
        }

        if (node.GetScrollOrientation(SwiftProp.Orientation) is ScrollOrientation orientation) { scroll.Orientation = orientation; }
        if (node.GetThickness(SwiftProp.Padding) is Thickness padding) { scroll.Padding = padding; }

        // ScrollView declares its own pair; ItemsView declares another, which
        // is what a CarouselView carries.
        if (node.GetScrollBarVisibility(SwiftProp.VerticalScrollBarVisibility) is ScrollBarVisibility down)
        {
            scroll.VerticalScrollBarVisibility = down;
        }

        if (node.GetScrollBarVisibility(SwiftProp.HorizontalScrollBarVisibility) is ScrollBarVisibility across)
        {
            scroll.HorizontalScrollBarVisibility = across;
        }

        ApplyView(node, scroll);
        Track(scroll, node);
        ApplyScrollContent(scroll, node);

        return scroll;
    }

    /// <summary>
    /// A ScrollView holds a single view, so its children need somewhere to go.
    /// </summary>
    /// <remarks>
    /// One child sits in Content directly. Several are wrapped in a stack rather
    /// than all but the first being dropped - and once wrapped it stays wrapped,
    /// so a list that grows and shrinks does not move its controls in and out of
    /// a wrapper that keeps appearing and disappearing. The wrapper stands for no
    /// node, which is how it is told from a stack the Swift side asked for.
    /// </remarks>
    private void ApplyScrollContent(ScrollView scroll, SwiftNode node)
    {
        if (node.Children is null)
        {
            return;
        }

        VerticalStackLayout? wrapper = scroll.Content is VerticalStackLayout stack
            && stack.GetValue(ElementProperty) is null
                ? stack
                : null;

        int count = node.Arranged
            ? Laid(node).Count
            : wrapper is not null ? wrapper.Children.Count : scroll.Content is null ? 0 : 1;

        if (wrapper is null && count <= 1)
        {
            if (count == 0)
            {
                scroll.Content = null;
            }
            else if (Laid(node) is { Count: > 0 } only)
            {
                scroll.Content = Reconcile(scroll.Content, only[0]);
            }

            return;
        }

        if (wrapper is null)
        {
            wrapper = new VerticalStackLayout();

            // The control that was in Content moves into the wrapper rather than
            // being rebuilt inside it.
            if (scroll.Content is View content)
            {
                wrapper.Children.Add(content);
            }
        }

        ApplyChildren(wrapper.Children, node);
        scroll.Content = wrapper;
    }

    /// <summary>
    /// A Map, and the pins on it. The platform's own map draws it - MapKit on
    /// Apple, Google Maps on Android - so the application registers the
    /// handler itself with <c>UseMauiMaps()</c>, and Android needs an API key
    /// in its manifest besides. Where it looks is an ACT on the view's id,
    /// <c>MoveToRegion</c> being a method in MAUI too.
    /// </summary>
    /// <remarks>
    /// The pins are kept by identity through <see cref="ApplyList{T}"/>, for
    /// the reason every list is: a pin rebuilt from a patch would arrive
    /// without the handler ids the patch did not repeat. A Map's children are
    /// all pins - bar the context-menu slot, which <see cref="ApplyView"/>
    /// reads by type and <c>ApplyPin</c> leaves alone.
    /// </remarks>
    private View ReconcileMap(SwiftNode node, View? existing)
    {
        // A control MAUI cannot make here draws the marker rather than taking
        // the page down with it - see CanBeMade, which is written for this one
        // case and says why.
        if (!CanBeMade(Application.Current?.Handler?.MauiContext?.Handlers, typeof(Map)))
        {
            return ReconcileUnknown(node, existing, "needs MAUI's Maps handlers, "
                + "which this platform has none of");
        }

        if (Reuse(existing, node) is not Map map)
        {
            map = new Map();

            map.MapClicked += (sender, e) => Raise(sender, SwiftEvent.MapClicked,
                SwiftWireValue.Of(e.Location.Latitude, e.Location.Longitude));
        }

        // Arrives once - a field that is not there did not change - and lands
        // through MoveToRegion, MAUI having no region property to assign.
        // While the platform's map is still connecting MAUI keeps it and
        // applies it at the right moment, which is exactly what an .onLoaded
        // act arrives too late for - measured on Mac Catalyst, where the
        // platform's own opening region overwrote it.
        if (node.GetMapSpan(SwiftProp.Region) is Microsoft.Maui.Maps.MapSpan region) { map.MoveToRegion(region); }

        if (node.GetMapType(SwiftProp.MapType) is Microsoft.Maui.Maps.MapType mapType) { map.MapType = mapType; }
        if (node.GetBool(SwiftProp.IsScrollEnabled) is bool isScrollEnabled) { map.IsScrollEnabled = isScrollEnabled; }
        if (node.GetBool(SwiftProp.IsZoomEnabled) is bool isZoomEnabled) { map.IsZoomEnabled = isZoomEnabled; }
        if (node.GetBool(SwiftProp.IsTrafficEnabled) is bool isTrafficEnabled) { map.IsTrafficEnabled = isTrafficEnabled; }
        if (node.GetBool(SwiftProp.IsShowingUser) is bool isShowingUser) { map.IsShowingUser = isShowingUser; }

        ApplyView(node, map);
        Track(map, node);
        ApplyList(map.Pins, node, ApplyPin);

        return map;
    }

    /// <summary>
    /// One marker on a map, kept by identity so its handlers survive a patch.
    /// </summary>
    private Pin? ApplyPin(SwiftNode node, Pin? existing)
    {
        // The context-menu slot travels among the children and is not a pin -
        // ApplyView already gave it to the control.
        if (node.Type != SwiftNodeType.Pin)
        {
            return null;
        }

        if (Reuse(existing, node) is not Pin pin)
        {
            pin = new Pin();

            // Subscribed once, where the pin is created; the handler id is
            // read off the pin when the event fires, never captured here.
            pin.MarkerClicked += (sender, _) => Raise(sender, SwiftEvent.MarkerClicked);
            pin.InfoWindowClicked += (sender, _) => Raise(sender, SwiftEvent.InfoWindowClicked);
        }

        if (node.GetString(SwiftProp.Label) is string label) { pin.Label = label; }
        if (node.GetString(SwiftProp.Address) is string address) { pin.Address = address; }
        if (node.GetLocation(SwiftProp.Location) is Location location) { pin.Location = location; }

        return Track(pin, node);
    }

    /// <summary>
    /// A WebView. Its source is a URL or HTML written in place - see
    /// <see cref="SwiftValues.GetWebViewSource"/> - and CanGoBack and
    /// CanGoForward are reported through the property watch, MAUI giving
    /// neither an event.
    /// </summary>
    /// <remarks>
    /// GoBack, GoForward, Reload and EvaluateJavaScriptAsync are ACTS on the
    /// view's id, performed by the session - a description has no control to
    /// call a method on. The navigation events are subscribed where the
    /// control is created, once; the url travels LAST in each payload because
    /// a url may contain commas, and the Swift side joins the tail back up -
    /// the same rule drawString follows.
    /// </remarks>
    private WebView ReconcileWebView(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not WebView web)
        {
            web = new WebView();

            web.Navigating += (sender, e) => Raise(sender, SwiftEvent.Navigating,
                SwiftWireValue.OfMember((int)Member(e.NavigationEvent)),
                SwiftWireValue.Of(e.Url ?? ""));
            web.Navigated += (sender, e) => Raise(sender, SwiftEvent.Navigated,
                SwiftWireValue.OfMember((int)Member(e.Result)),
                SwiftWireValue.OfMember((int)Member(e.NavigationEvent)),
                SwiftWireValue.Of(e.Url ?? ""));
            web.ProcessTerminated += (sender, _) => Raise(sender, SwiftEvent.ProcessTerminated);
        }

        // Assigned only when the message carries it - a source that did not
        // change must not navigate the view again.
        if (node.GetWebViewSource(SwiftProp.Source) is WebViewSource source) { web.Source = source; }

        ApplyView(node, web);

        return Track(web, node);
    }

    /// <summary>
    /// The window's own chrome, in place of the system title bar - desktop
    /// only, <c>WindowHandler.MapTitleBar</c> having a body on Mac Catalyst
    /// and Windows and nowhere else.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Its children are the three slots MAUI declares as properties -
    /// LeadingContent, Content, TrailingContent - each a wrapper node read by
    /// TYPE, the way a page's TitleView is: a patch about one slot arrives as
    /// one child, and taking positions would hand the middle a button.
    /// </para>
    /// <para>
    /// Every slot view is registered as a passthrough element: a view in a
    /// slot is there to be USED, and without the registration a click on it
    /// would drag the window instead - which reads as a broken button, not as
    /// a configuration. The rest of the bar keeps dragging.
    /// </para>
    /// </remarks>
    private TitleBar ReconcileTitleBar(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not TitleBar bar)
        {
            bar = new TitleBar();
        }

        if (node.GetString(SwiftProp.Title) is string title) { bar.Title = title; }
        if (node.GetString(SwiftProp.Subtitle) is string subtitle) { bar.Subtitle = subtitle; }
        node.SetImageSource(SwiftProp.Icon, bar, TitleBar.IconProperty);
        node.SetColor(SwiftProp.ForegroundColor, bar, TitleBar.ForegroundColorProperty);

        ApplyView(node, bar);
        Track(bar, node);

        // A slot that LEAVES is recognized by its absence from an arranged
        // list, and it is recognized BY TYPE: a slot type fills a bar at most
        // once, while a wrapper's KEY is positional identity that shifts when
        // a sibling slot appears or leaves - matched by key, a leading slot
        // emptying beside a surviving trailing one nulled the trailing slot
        // and left the leading view standing in the chrome.
        HashSet<SwiftNodeType> filled = _titleBarSlots.GetOrCreateValue(bar);

        if (node.Arranged)
        {
            foreach (SwiftNodeType slot in filled.Where(slot =>
                node.Children?.Any(child => child.Type == slot) != true).ToList())
            {
                switch (slot)
                {
                    case SwiftNodeType.LeadingContent: bar.LeadingContent = null; break;
                    case SwiftNodeType.Content: bar.Content = null; break;
                    case SwiftNodeType.TrailingContent: bar.TrailingContent = null; break;
                }

                filled.Remove(slot);
            }
        }

        foreach (SwiftNode child in node.Children ?? [])
        {
            switch (child.Type)
            {
                case SwiftNodeType.LeadingContent:
                    bar.LeadingContent = Slot(bar.LeadingContent as View, child);
                    filled.Add(SwiftNodeType.LeadingContent);
                    break;

                case SwiftNodeType.Content:
                    bar.Content = Slot(bar.Content as View, child);
                    filled.Add(SwiftNodeType.Content);
                    break;

                case SwiftNodeType.TrailingContent:
                    bar.TrailingContent = Slot(bar.TrailingContent as View, child);
                    filled.Add(SwiftNodeType.TrailingContent);
                    break;
            }
        }

        bar.PassthroughElements.Clear();

        foreach (IView? slot in new[] { bar.LeadingContent, bar.Content, bar.TrailingContent })
        {
            if (slot is not null)
            {
                bar.PassthroughElements.Add(slot);
            }
        }

        return bar;
    }

    /// <summary>
    /// Which slot types fill a title bar. A slot's leaving is its type's
    /// absence from an arranged list, and the bar's properties do not
    /// remember whether a view came from the tree - this is the way back.
    /// Weak for the reason <c>_named</c> is: there is no one place a bar is
    /// dropped.
    /// </summary>
    private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<TitleBar, HashSet<SwiftNodeType>> _titleBarSlots = new();

    /// <summary>
    /// A RefreshView, and the single view it refreshes.
    /// </summary>
    /// <remarks>
    /// <c>IsRefreshing</c> is the one property here that is written from both
    /// sides: the pull sets it, and only the handler clears it. Which is why the
    /// Swift side can ask to hear about it - see <see cref="Observe"/> - and why
    /// assigning it during a render does not report itself, the <c>_rendering</c>
    /// guard being the same one an Entry's Text relies on.
    /// </remarks>
    private RefreshView ReconcileRefreshView(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not RefreshView refresh)
        {
            refresh = new RefreshView();

            refresh.Refreshing += (sender, _) => Raise(sender, SwiftEvent.Refreshing);
        }

        if (node.GetBool(SwiftProp.IsRefreshing) is bool isRefreshing) { refresh.IsRefreshing = isRefreshing; }
        node.SetColor(SwiftProp.RefreshColor, refresh, RefreshView.RefreshColorProperty);
        if (node.GetBool(SwiftProp.IsRefreshEnabled) is bool enabled) { refresh.IsRefreshEnabled = enabled; }

        ApplyView(node, refresh);
        Track(refresh, node);

        // MAUI's RefreshView holds one view, the way a Border does.
        if (Laid(node) is { Count: > 0 } children)
        {
            refresh.Content = Reconcile(refresh.Content, children[0]);
        }
        else if (node.Arranged)
        {
            refresh.Content = null;
        }

        return refresh;
    }

    /// <summary>
    /// A SwipeView: the view itself, and the items each side reveals.
    /// </summary>
    /// <remarks>
    /// Its children are read by TYPE rather than by position, the way a page's
    /// are: a <c>SwipeItems</c> node is one of the four collections, and anything
    /// else is the content. A patch carries only what changed, so a message about
    /// one item arrives as a single child and taking <c>children[0]</c> as the
    /// content would hand the view a set of buttons.
    /// </remarks>
    private SwipeView ReconcileSwipeView(SwiftNode node, View? existing)
    {
        if (Reuse(existing, node) is not SwipeView swipe)
        {
            swipe = new SwipeView();
        }

        if (node.GetNumber(SwiftProp.Threshold) is double threshold) { swipe.Threshold = threshold; }

        ApplyView(node, swipe);
        Track(swipe, node);

        bool held = false;

        foreach (SwiftNode child in node.Children ?? [])
        {
            if (child.Type == SwiftNodeType.SwipeItems)
            {
                ApplySwipeItems(swipe, child);
            }
            else if (!IsSlot(child))
            {
                swipe.Content = Reconcile(swipe.Content, child);
                held = true;
            }
        }

        // An arranged message that no longer carries a content child says the
        // view LEFT - the single-content rule a Border follows.
        if (node.Arranged && !held)
        {
            swipe.Content = null;
        }

        return swipe;
    }

    /// <summary>
    /// One of a SwipeView's four collections, and the items in it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The side is the one thing on the wire here that is not a MAUI property
    /// name: XAML says which collection this is by the element it sits inside,
    /// <c>&lt;SwipeView.LeftItems&gt;</c>, and there is no node inside a property
    /// on this side.
    /// </para>
    /// <para>
    /// And it arrives only with a full node - a field that is not there did not
    /// change, which is the rule the whole format reads by, so a patch about one
    /// item carries no side at all. After the first message the collection is
    /// therefore found the way everything else is: by identity.
    /// </para>
    /// </remarks>
    private void ApplySwipeItems(SwipeView swipe, SwiftNode node)
    {
        SwipeItems? items = node.GetSwipeSide(SwiftProp.Side) is SwiftSwipeSide side
            ? Collection(swipe, side)
            : Held(swipe, node.Key);

        if (items is null)
        {
            return;
        }

        if (node.GetSwipeMode(SwiftProp.Mode) is SwipeMode mode) { items.Mode = mode; }
        if (node.GetSwipeBehaviorOnInvoked(SwiftProp.SwipeBehaviorOnInvoked) is SwipeBehaviorOnInvoked behavior)
        {
            items.SwipeBehaviorOnInvoked = behavior;
        }

        Track(items, node);
        ApplyList(items, node, (child, match) => ApplySwipeItem(child, match as SwipeItem));
    }

    /// <summary>The collection a side names, made if it is not there yet.</summary>
    /// <remarks>
    /// MAUI has four PROPERTIES rather than an enum, so there is nothing to
    /// translate onto and the mirror itself is what the side arrives as - see
    /// <see cref="SwiftValues.GetSwipeSide"/>. It is a MEMBER and not a string:
    /// reading it as one answers null for every message and takes the
    /// <see cref="Held"/> branch instead, which is a wrong collection rather
    /// than a failure.
    /// </remarks>
    private static SwipeItems? Collection(SwipeView swipe, SwiftSwipeSide side)
    {
        return side switch
        {
            SwiftSwipeSide.Left => swipe.LeftItems ??= [],
            SwiftSwipeSide.Right => swipe.RightItems ??= [],
            SwiftSwipeSide.Top => swipe.TopItems ??= [],
            SwiftSwipeSide.Bottom => swipe.BottomItems ??= [],
            _ => null,
        };
    }

    /// <summary>
    /// The collection already carrying an identity, whichever side it ended up
    /// on - which is how a patch that does not say finds the right one.
    /// </summary>
    private static SwipeItems? Held(SwipeView swipe, string key)
    {
        SwipeItems?[] sides = [swipe.LeftItems, swipe.RightItems, swipe.TopItems, swipe.BottomItems];

        foreach (SwipeItems? items in sides)
        {
            if (items is not null && KeyOf(items) == key)
            {
                return items;
            }
        }

        return null;
    }

    /// <summary>One button in a page's navigation bar.</summary>
    internal ToolbarItem ApplyToolbarItem(SwiftNode node, ToolbarItem? existing)
    {
        if (Reuse(existing, node) is not ToolbarItem item)
        {
            item = new ToolbarItem();
            item.Clicked += (sender, _) => Raise(sender, SwiftEvent.Clicked);
        }

        if (node.GetString(SwiftProp.Text) is string text) { item.Text = text; }
        node.SetImageSource(SwiftProp.IconImageSource, item, MenuItem.IconImageSourceProperty);
        if (node.GetToolbarItemOrder(SwiftProp.Order) is ToolbarItemOrder order) { item.Order = order; }
        if (node.GetInt(SwiftProp.Priority) is int priority) { item.Priority = priority; }
        if (node.GetBool(SwiftProp.IsDestructive) is bool destructive) { item.IsDestructive = destructive; }
        if (node.GetBool(SwiftProp.IsEnabled) is bool enabled) { item.IsEnabled = enabled; }

        return Track(item, node);
    }

    /// <summary>One menu on the menu bar, and the entries in it.</summary>
    internal MenuBarItem ApplyMenuBarItem(SwiftNode node, MenuBarItem? existing)
    {
        if (Reuse(existing, node) is not MenuBarItem menu)
        {
            menu = new MenuBarItem();
        }

        if (node.GetString(SwiftProp.Text) is string text) { menu.Text = text; }
        if (node.GetBool(SwiftProp.IsEnabled) is bool enabled) { menu.IsEnabled = enabled; }

        Track(menu, node);
        ApplyList(menu, node, ApplyMenuEntry);

        return menu;
    }

    /// <summary>
    /// One entry in a menu: an item, a submenu, or a line between them.
    /// </summary>
    /// <remarks>
    /// A separator and a submenu are both MenuFlyoutItems in MAUI, which is what
    /// lets one list hold all three - and what makes the node's TYPE the only
    /// thing that says which is which.
    /// </remarks>
    internal IMenuElement? ApplyMenuEntry(SwiftNode node, IMenuElement? existing)
    {
        switch (node.Type)
        {
            case SwiftNodeType.MenuFlyoutSeparator:
                return Track(Reuse(existing as MenuFlyoutSeparator, node) ?? new MenuFlyoutSeparator(), node);

            case SwiftNodeType.MenuFlyoutSubItem:
            {
                if (Reuse(existing as MenuFlyoutSubItem, node) is not MenuFlyoutSubItem submenu)
                {
                    submenu = new MenuFlyoutSubItem();
                }

                if (node.GetString(SwiftProp.Text) is string caption) { submenu.Text = caption; }
                if (node.GetBool(SwiftProp.IsEnabled) is bool open) { submenu.IsEnabled = open; }

                Track(submenu, node);
                ApplyList(submenu, node, ApplyMenuEntry);

                return submenu;
            }

            case SwiftNodeType.MenuFlyoutItem:
            {
                if (Reuse(existing as MenuFlyoutItem, node) is not MenuFlyoutItem item)
                {
                    item = new MenuFlyoutItem();
                    item.Clicked += (sender, _) => Raise(sender, SwiftEvent.Clicked);
                }

                if (node.GetString(SwiftProp.Text) is string text) { item.Text = text; }
                node.SetImageSource(SwiftProp.IconImageSource, item, MenuItem.IconImageSourceProperty);
                if (node.GetBool(SwiftProp.IsDestructive) is bool destructive) { item.IsDestructive = destructive; }
                if (node.GetBool(SwiftProp.IsEnabled) is bool enabled) { item.IsEnabled = enabled; }

                return Track(item, node);
            }

            default:
                return existing;
        }
    }

    /// <summary>One SwipeItem: a caption, a picture, a colour and something to run.</summary>
    private SwipeItem ApplySwipeItem(SwiftNode node, SwipeItem? existing)
    {
        if (Reuse(existing, node) is not SwipeItem item)
        {
            item = new SwipeItem();

            item.Invoked += (sender, _) => Raise(sender, SwiftEvent.Invoked);
        }

        if (node.GetString(SwiftProp.Text) is string text) { item.Text = text; }
        node.SetImageSource(SwiftProp.IconImageSource, item, MenuItem.IconImageSourceProperty);
        node.SetColor(SwiftProp.BackgroundColor, item, SwipeItem.BackgroundColorProperty);
        if (node.GetBool(SwiftProp.IsDestructive) is bool isDestructive) { item.IsDestructive = isDestructive; }
        if (node.GetBool(SwiftProp.IsEnabled) is bool isEnabled) { item.IsEnabled = isEnabled; }
        if (node.GetBool(SwiftProp.IsVisible) is bool isVisible) { item.IsVisible = isVisible; }

        return Track(item, node);
    }

    /// <summary>
    /// Brings a layout's children in line with the message: the view-typed
    /// face of <see cref="ApplyList{T}"/>, which is the one child mechanism
    /// everything with children goes through.
    /// </summary>
    /// <remarks>
    /// The apply step is <see cref="Reconcile"/>, with the slot wrappers
    /// skipped: a context menu travels among the children and belongs to the
    /// view rather than the layout - <see cref="ApplyView"/> reads it by
    /// type, and skipping it here is what keeps it out of every arrangement.
    /// </remarks>
    /// <param name="children">the control's children, as MAUI holds them</param>
    /// <param name="node">the message about them</param>
    private void ApplyChildren<TChild>(IList<TChild> children, SwiftNode node)
        where TChild : class
    {
        ApplyList(children, node, (child, match) =>
            IsSlot(child) ? null : (TChild)(object)Reconcile(match as View, child));
    }

    /// <summary>
    /// Asks the platform to work the pivot out again, once the view has been
    /// laid out.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The point a rotation turns ABOUT is the platform's, and it is the
    /// ANCHOR multiplied by the view's FRAME - which a control that has only
    /// just been made does not have, so an anchor written at creation is
    /// multiplied by nothing. Measured on Android: pivot (-1.5, -3) for a hand
    /// 6 by 288 pixels, from a frame of -1. It is worked out when the anchor is
    /// mapped and NOT when the rotation is, so a view built with both an anchor
    /// and an angle turns about the wrong point for the rest of its life -
    /// the gallery's clock, whose hands swung around their own tops and stayed
    /// there, tick after tick.
    /// </para>
    /// <para>
    /// Two things about the timing, both measured. The cross-platform
    /// <c>SizeChanged</c> is too EARLY - the platform view is still 0 by 0 when
    /// it fires - so the work is posted for the turn after, by which time the
    /// frame is real. And the anchor is written rather than mapped:
    /// <c>Handler.UpdateValue</c> leaves the pivot as it was, while the
    /// property change reaches the platform. It is written as a change and back
    /// because a bindable property ignores a value it already holds.
    /// </para>
    /// </remarks>
    /// <param name="view">the view that said where its pivot is</param>
    private static void AskForThePivotAgain(VisualElement view)
    {
        void Sized(object? sender, EventArgs e)
        {
            view.SizeChanged -= Sized;

            view.Dispatcher.Dispatch(() =>
            {
                (double x, double y) = (view.AnchorX, view.AnchorY);
                (view.AnchorX, view.AnchorY) = (x == 0 ? 1 : 0, y == 0 ? 1 : 0);
                (view.AnchorX, view.AnchorY) = (x, y);
            });
        }

        view.SizeChanged += Sized;
    }

    /// <summary>
    /// Brings a kept list - a layout's children, a menu's entries, a map's
    /// pins, a list's rows or its groups - in line with the message. The ONE
    /// child mechanism: every Apply with children goes through here.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The message speaks two shapes, and <see cref="SwiftNode.Arranged"/>
    /// says which. A sparse message names only the children whose content
    /// changed, each matched to its item by identity - nothing else in the
    /// list is touched, which is what makes a thousand-row list cost one
    /// message when one row changes. An arranged message carries the COMPLETE
    /// list in order, unchanged children as bare stubs, and arrives exactly
    /// when something was added, removed or moved: the list itself is the
    /// order, its length the count, and absence from it the removal.
    /// </para>
    /// <para>
    /// The identity lives on the item itself, in the attached
    /// <see cref="ElementProperty"/> - the one place this renderer keeps what
    /// an item stands for. An item in the list without one stands for nothing
    /// the Swift side described, so an arranged message removes it.
    /// </para>
    /// <para>
    /// <paramref name="apply"/> patches or makes one item from its node, and
    /// answers null for a node that is not one of the items - a slot wrapper,
    /// read by type elsewhere - which then takes no part in the arrangement.
    /// </para>
    /// </remarks>
    /// <param name="items">the list as MAUI holds it</param>
    /// <param name="node">the message about it</param>
    /// <param name="apply">patches or makes one item from one child node</param>
    /// <param name="keyOf">
    /// The identity an item carries, for a list whose items are not bindable
    /// objects - a grouped list's groups. Everything else reads the attached
    /// element.
    /// </param>
    internal void ApplyList<T>(
        IList<T> items,
        SwiftNode node,
        Func<SwiftNode, T?, T?> apply,
        Func<T, string?>? keyOf = null)
        where T : class
    {
        if (node.Children is null)
        {
            return;
        }

        keyOf ??= item => item is BindableObject bindable ? KeyOf(bindable) : null;

        var byKey = new Dictionary<string, T>(items.Count);

        foreach (T item in items)
        {
            if (keyOf(item) is string key)
            {
                byKey.TryAdd(key, item);
            }
        }

        List<T>? target = node.Arranged ? new(node.Children.Count) : null;

        foreach (SwiftNode child in node.Children)
        {
            byKey.TryGetValue(child.Key, out T? match);

            if (apply(child, match) is not T item)
            {
                continue;
            }

            if (target is not null)
            {
                target.Add(item);
            }
            else if (match is null)
            {
                // A sparse message about an identity this side has nothing
                // for. A new child always arrives in an ARRANGED list, so this
                // is drift - C# lost the tree the patch was computed against.
                // Refusing turns it into the whole-tree resync the session
                // already has, which is a recovery rather than a control
                // quietly taken in at the wrong end.
                //
                // Its own exception type, and that is the load-bearing part:
                // an InvalidDataException here reads as malformed bytes, and
                // the session answers those by giving up on the interface
                // instead of asking for it again. See SwiftTreeDriftException.
                throw new SwiftTreeDriftException(
                    $"a patch names child '{child.Key}' that '{node.Key}' does not have");
            }
            else if (!ReferenceEquals(item, match))
            {
                // A replace keeps its place: the new control stands exactly
                // where the one it supersedes stood.
                int at = IndexOf(items, match);
                items.RemoveAt(at);
                items.Insert(at, item);
            }
        }

        if (target is not null)
        {
            Align(items, target);
        }
    }

    /// <summary>
    /// Moves a kept list into the target order, touching only what moved.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Anything in the list and not in the target leaves: a child the
    /// arranged message no longer names, and any item that never carried an
    /// identity at all - an item without the attached element is nothing the
    /// Swift side described, so no description can give it a place.
    /// </para>
    /// <para>
    /// Of what remains, the longest run already in relative order stays
    /// exactly where it is - the longest increasing subsequence of the
    /// survivors' current positions, because a greedy walk from the front
    /// moves the many to spare the few - and each remaining item is inserted
    /// once, directly before the item that follows it in the target. An
    /// insertion at the top is one Insert, a rotation one move, and the rows
    /// between never leave their parent.
    /// </para>
    /// </remarks>
    private static void Align<T>(IList<T> items, List<T> target) where T : class
    {
        var wanted = new HashSet<T>(target, (IEqualityComparer<T>)ReferenceEqualityComparer.Instance);

        for (int index = items.Count - 1; index >= 0; index--)
        {
            if (!wanted.Contains(items[index]))
            {
                items.RemoveAt(index);
            }
        }

        var survivors = new Dictionary<T, int>(
            items.Count, (IEqualityComparer<T>)ReferenceEqualityComparer.Instance);

        for (int index = 0; index < items.Count; index++)
        {
            survivors[items[index]] = index;
        }

        HashSet<T> settled = Unmoved(target, survivors);
        T? anchor = null;

        for (int index = target.Count - 1; index >= 0; index--)
        {
            T item = target[index];

            if (settled.Contains(item))
            {
                anchor = item;
                continue;
            }

            if (survivors.ContainsKey(item))
            {
                items.RemoveAt(IndexOf(items, item));
            }

            items.Insert(anchor is null ? items.Count : IndexOf(items, anchor), item);
            anchor = item;
        }
    }

    /// <summary>
    /// The items that can stay put: the longest run of survivors whose current
    /// order already agrees with the target's.
    /// </summary>
    /// <param name="target">the order wanted, newcomers included</param>
    /// <param name="survivors">each surviving item's current position</param>
    private static HashSet<T> Unmoved<T>(List<T> target, Dictionary<T, int> survivors)
        where T : class
    {
        // The survivors' current positions, read in target order - the classic
        // longest-increasing-subsequence arrangement.
        var sequence = new List<(T Item, int Position)>(survivors.Count);

        foreach (T item in target)
        {
            if (survivors.TryGetValue(item, out int position))
            {
                sequence.Add((item, position));
            }
        }

        // Patience: tails[k] indexes the entry with the smallest position that
        // ends a rising run of length k+1, and `previous` chains each entry to
        // the one before it in its run.
        var tails = new List<int>();
        var previous = new int[sequence.Count];

        for (int index = 0; index < sequence.Count; index++)
        {
            int position = sequence[index].Position;
            int low = 0;
            int high = tails.Count;

            while (low < high)
            {
                int middle = (low + high) / 2;

                if (sequence[tails[middle]].Position < position)
                {
                    low = middle + 1;
                }
                else
                {
                    high = middle;
                }
            }

            previous[index] = low > 0 ? tails[low - 1] : -1;

            if (low == tails.Count)
            {
                tails.Add(index);
            }
            else
            {
                tails[low] = index;
            }
        }

        var kept = new HashSet<T>((IEqualityComparer<T>)ReferenceEqualityComparer.Instance);

        for (int index = tails.Count > 0 ? tails[^1] : -1; index >= 0; index = previous[index])
        {
            kept.Add(sequence[index].Item);
        }

        return kept;
    }

    /// <summary>Where an item stands in a list, by reference.</summary>
    private static int IndexOf<T>(IList<T> items, T item) where T : class
    {
        for (int index = 0; index < items.Count; index++)
        {
            if (ReferenceEquals(items[index], item))
            {
                return index;
            }
        }

        return -1;
    }

    // ---- Shared properties -------------------------------------------------
    //
    // The tiers MAUI declares these on, in the order the Swift protocols mirror
    // them: VisualElement, then View, then the font interface Label, Button and
    // Entry share.

    /// <summary>
    /// Everything a view has because it is a view: its style, the VisualElement
    /// properties, the View ones, where it sits in a Grid, and its gestures.
    /// </summary>
    /// <remarks>
    /// One method for all of them, which is what the protocol tiers on the Swift
    /// side buy: a modifier declared on VisualElement lands here for every
    /// control, and the per-control tests do not have to repeat it.
    /// </remarks>
    private void ApplyView(SwiftNode node, View view)
    {
        // No style is read here, and there is nothing to read: a style is
        // resolved on the Swift side, into the properties below. What arrives is
        // a control with every value already on it - its own written over its
        // style's - so nothing on this side has to know what a style is, and a
        // keyed one is not a resource anybody has to look up.

        // VisualElement
        if (node.GetBool(SwiftProp.IsVisible) is bool isVisible) { view.IsVisible = isVisible; }
        if (node.GetBool(SwiftProp.IsEnabled) is bool isEnabled) { view.IsEnabled = isEnabled; }
        if (node.GetBool(SwiftProp.InputTransparent) is bool inputTransparent) { view.InputTransparent = inputTransparent; }
        if (node.GetFlowDirection(SwiftProp.FlowDirection) is FlowDirection flowDirection) { view.FlowDirection = flowDirection; }
        if (node.GetNumber(SwiftProp.Opacity) is double opacity) { view.Opacity = opacity; }
        node.SetColor(SwiftProp.BackgroundColor, view, VisualElement.BackgroundColorProperty);
        node.SetBrush(SwiftProp.Background, view, VisualElement.BackgroundProperty);
        if (node.GetNumber(SwiftProp.WidthRequest) is double widthRequest) { view.WidthRequest = widthRequest; }
        if (node.GetNumber(SwiftProp.HeightRequest) is double heightRequest) { view.HeightRequest = heightRequest; }
        if (node.GetNumber(SwiftProp.MinimumWidthRequest) is double minimumWidth) { view.MinimumWidthRequest = minimumWidth; }
        if (node.GetNumber(SwiftProp.MinimumHeightRequest) is double minimumHeight) { view.MinimumHeightRequest = minimumHeight; }
        if (node.GetNumber(SwiftProp.MaximumWidthRequest) is double maximumWidth) { view.MaximumWidthRequest = maximumWidth; }
        if (node.GetNumber(SwiftProp.MaximumHeightRequest) is double maximumHeight) { view.MaximumHeightRequest = maximumHeight; }
        if (node.GetNumber(SwiftProp.Rotation) is double rotation) { view.Rotation = rotation; }
        if (node.GetNumber(SwiftProp.RotationX) is double rotationX) { view.RotationX = rotationX; }
        if (node.GetNumber(SwiftProp.RotationY) is double rotationY) { view.RotationY = rotationY; }
        if (node.GetNumber(SwiftProp.Scale) is double scale) { view.Scale = scale; }
        if (node.GetNumber(SwiftProp.ScaleX) is double scaleX) { view.ScaleX = scaleX; }
        if (node.GetNumber(SwiftProp.ScaleY) is double scaleY) { view.ScaleY = scaleY; }
        if (node.GetNumber(SwiftProp.TranslationX) is double translationX) { view.TranslationX = translationX; }
        if (node.GetNumber(SwiftProp.TranslationY) is double translationY) { view.TranslationY = translationY; }
        bool anchored = false;
        if (node.GetNumber(SwiftProp.AnchorX) is double anchorX) { view.AnchorX = anchorX; anchored = true; }
        if (node.GetNumber(SwiftProp.AnchorY) is double anchorY) { view.AnchorY = anchorY; anchored = true; }
        if (node.GetInt(SwiftProp.ZIndex) is int zIndex) { view.ZIndex = zIndex; }

        if (anchored && (view.Width < 0 || view.Height < 0))
        {
            AskForThePivotAgain(view);
        }

        // View
        if (node.GetThickness(SwiftProp.Margin) is Thickness margin) { view.Margin = margin; }
        if (node.GetLayoutOptions(SwiftProp.HorizontalOptions) is LayoutOptions horizontal) { view.HorizontalOptions = horizontal; }
        if (node.GetLayoutOptions(SwiftProp.VerticalOptions) is LayoutOptions vertical) { view.VerticalOptions = vertical; }

        // Where a view sits in a Grid. Attached properties: declared by Grid,
        // written on the child, and harmless on a view that is not in one.
        if (node.GetInt(SwiftProp.GridRow) is int row) { Grid.SetRow(view, row); }
        if (node.GetInt(SwiftProp.GridColumn) is int column) { Grid.SetColumn(view, column); }
        if (node.GetInt(SwiftProp.GridRowSpan) is int rowSpan) { Grid.SetRowSpan(view, rowSpan); }
        if (node.GetInt(SwiftProp.GridColumnSpan) is int columnSpan) { Grid.SetColumnSpan(view, columnSpan); }

        // The same, for the two layouts that ask a child where it goes: an
        // AbsoluteLayout reads a rectangle and the flags that say how to read it,
        // a FlexLayout reads what the child wants of the room there is.
        if (node.GetRect(SwiftProp.AbsoluteLayoutBounds) is Rect bounds) { AbsoluteLayout.SetLayoutBounds(view, bounds); }
        if (node.GetAbsoluteLayoutFlags(SwiftProp.AbsoluteLayoutFlags) is AbsoluteLayoutFlags flags) { AbsoluteLayout.SetLayoutFlags(view, flags); }

        if (node.GetInt(SwiftProp.FlexLayoutOrder) is int order) { FlexLayout.SetOrder(view, order); }
        if (node.GetNumber(SwiftProp.FlexLayoutGrow) is double grow) { FlexLayout.SetGrow(view, (float)grow); }
        if (node.GetNumber(SwiftProp.FlexLayoutShrink) is double shrink) { FlexLayout.SetShrink(view, (float)shrink); }
        if (node.GetFlexAlignSelf(SwiftProp.FlexLayoutAlignSelf) is FlexAlignSelf alignSelf) { FlexLayout.SetAlignSelf(view, alignSelf); }
        if (node.GetFlexBasis(SwiftProp.FlexLayoutBasis) is FlexBasis basis) { FlexLayout.SetBasis(view, basis); }

        // A menu on the view itself. Read by TYPE here rather than by whatever
        // handles this control's children, because it can arrive on ANY view -
        // see IsSlot, which is what keeps it out of every arrangement. One
        // written under an `if` that turned false is recognized the way every
        // slot's leaving is: its wrapper is absent from an arranged list.
        foreach (SwiftNode child in node.Children ?? [])
        {
            if (child.Type == SwiftNodeType.ContextFlyout)
            {
                ApplyContextFlyout(view, child);
            }
        }

        if (node.Arranged
            && FlyoutBase.GetContextFlyout(view) is MenuFlyout flyout
            && KeyOf(flyout) is string flyoutKey
            && Absent(node, flyoutKey))
        {
            FlyoutBase.SetContextFlyout(view, null);
        }

        ApplyVisualStates(view, node);
    }

    /// <summary>
    /// The states the view itself declares - what a style says, said about one
    /// control. MAUI: <see cref="VisualStateManager.VisualStateGroupsProperty"/>
    /// set on the control rather than through a Setter.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The states ride as slot children, so this is the second modifier that
    /// writes a child rather than a property, and every arrangement leaves them
    /// alone for the reason a context menu is left alone.
    /// </para>
    /// <para>
    /// They are also the first children that are DATA rather than views, and
    /// data has to be whole before it can be built: a group list is assigned in
    /// one go, and a patch names only the state whose setters changed. So the
    /// described states are kept here, per control, and an arrival is merged
    /// into them - the kept set being what a group list is built from. The map
    /// is weak for the reason every map here is: there is no one place a
    /// control is dropped.
    /// </para>
    /// <para>
    /// And it is assigned only when something about the states actually
    /// changed. Setting the property again puts the manager back into the
    /// resting state, so a view that merely moved among its siblings - which
    /// sends every child as a stub - would lose its PointerOver for as long as
    /// it took the mouse to move again.
    /// </para>
    /// </remarks>
    private void ApplyVisualStates(View view, SwiftNode node)
    {
        List<SwiftNode> arriving = (node.Children ?? [])
            .Where(child => child.Type == SwiftNodeType.VisualState)
            .ToList();

        bool held = _states.TryGetValue(view, out Described? described);

        // Nothing said about them, and nothing held: the ordinary view.
        if (arriving.Count == 0 && !held)
        {
            return;
        }

        described ??= new Described();

        List<SwiftNode> was = described.States;
        List<SwiftNode> now = was;

        // Only an arranged message can say that a state has LEFT, absence from
        // the complete list being how every slot's leaving is recognized - so a
        // patch about something else is left to change nothing but the
        // announcing below.
        if (arriving.Count > 0 || node.Arranged)
        {
            if (node.Arranged)
            {
                Dictionary<string, SwiftNode> byKey = was.ToDictionary(state => state.Key);

                now = arriving
                    .Select(child => Merged(byKey.GetValueOrDefault(child.Key), child))
                    .ToList();
            }
            else
            {
                now = [.. was];

                foreach (SwiftNode child in arriving)
                {
                    int at = now.FindIndex(state => state.Key == child.Key);

                    if (at < 0)
                    {
                        now.Add(Merged(null, child));
                    }
                    else
                    {
                        now[at] = Merged(now[at], child);
                    }
                }
            }
        }

        bool announcing = Announces(view, node);
        bool moved = !was.Select(state => state.Key).SequenceEqual(now.Select(state => state.Key));
        bool said = arriving.Any(child => child.Props is not null || child.Children is not null);
        bool listening = announcing != described.Announcing;

        described.States = now;
        described.Announcing = announcing;
        _states.AddOrUpdate(view, described);

        if (!moved && !said && !listening)
        {
            return;
        }

        VisualStateManager.SetVisualStateGroups(
            view,
            now.Count == 0
                ? []
                : Announcing(
                    SwiftStyles.BuildStates(node.Type, node.TypeName, now), announcing));
    }

    /// <summary>
    /// Whether the tree asked to hear which state this control is in.
    /// </summary>
    /// <remarks>
    /// The node on a first render and the attached element afterwards: an event
    /// map is sent only when the SET of handled events changes, and the element
    /// is not attached until <see cref="Track"/> runs, which is after this.
    /// </remarks>
    private static bool Announces(View view, SwiftNode node) =>
        node.Events?.ContainsKey(SwiftEvent.VisualStateChanged)
            ?? (view.GetValue(ElementProperty) as RenderedElement)?
                .Events?.ContainsKey(SwiftEvent.VisualStateChanged)
            ?? false;

    /// <summary>
    /// The same states, each made to say its own name as it is entered.
    /// </summary>
    /// <remarks>
    /// A VisualStateGroup announces what it entered in no other way -
    /// <c>CurrentState</c> has no change event - so the announcement IS a
    /// setter, on a property of this renderer's own, and the property being
    /// written is what <see cref="WatchVisualState"/> hears.
    /// </remarks>
    private static VisualStateGroupList Announcing(VisualStateGroupList groups, bool announcing)
    {
        if (!announcing)
        {
            return groups;
        }

        foreach (VisualStateGroup group in groups)
        {
            foreach (VisualState state in group.States)
            {
                state.Setters.Add(new Setter { Property = StateProperty, Value = state.Name });
            }
        }

        return groups;
    }

    /// <summary>
    /// Written by a state as it is entered, and read for nothing else.
    /// </summary>
    private static readonly BindableProperty StateProperty = BindableProperty.CreateAttached(
        "SwiftVisualState",
        typeof(string),
        typeof(StateUIRenderer),
        defaultValue: null);

    /// <summary>
    /// Reports which state a control has entered, when the tree asked to hear.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Not through <see cref="Watch"/>, for the reason the frame is not: LEAVING
    /// a state puts the announcing property back before the next state sets it,
    /// so the raw property changes twice per transition and once with nothing in
    /// it. What crosses is the state actually entered, and only when it differs
    /// from the last one reported.
    /// </para>
    /// <para>
    /// And the report is DEFERRED one dispatcher turn, coalesced with an armed
    /// flag. Two reasons, and the first is load-bearing: a control enters
    /// Disabled because the renderer assigned <c>IsEnabled</c>, INSIDE a render,
    /// where <see cref="Raise(object?, SwiftEvent, byte[])"/> answers nothing - the
    /// guard that stops the renderer reporting its own writes. Reporting from
    /// there anyway would start a handler inside a render, which is the
    /// re-entrancy that crashed
    /// Android from MAUI's own property setter once already. A turn later the
    /// render is over and the report is an ordinary one. The second reason is
    /// the burst: leaving and entering are two writes and one transition.
    /// </para>
    /// <para>
    /// The states themselves are what carry the announcement - see
    /// <see cref="Announcing"/> - so a control that declares none reports
    /// nothing, which is what the modifier's doc comment says.
    /// </para>
    /// </remarks>
    private void WatchVisualState(View view, RenderedElement element)
    {
        if (element.Events?.ContainsKey(SwiftEvent.VisualStateChanged) != true
            || !(element.Observed ??= []).Add(SwiftEvent.VisualStateChanged))
        {
            return;
        }

        string? reported = null;
        bool armed = false;

        view.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName != StateProperty.PropertyName || armed)
            {
                return;
            }

            armed = true;

            view.Dispatcher.Dispatch(() =>
            {
                armed = false;

                // What it is in NOW: a transition writes the property twice, and
                // the state it settled in is the answer to both.
                if (view.GetValue(StateProperty) is not string entered || entered == reported)
                {
                    return;
                }

                reported = entered;

                Raise(view, SwiftEvent.VisualStateChanged, entered);
            });
        };
    }

    /// <summary>
    /// The states a view described for itself, and whether it was asked to say
    /// which one it is in.
    /// </summary>
    private sealed class Described
    {
        /// <summary>Complete described states, in the order they were written.</summary>
        public List<SwiftNode> States { get; set; } = [];

        /// <summary>Whether each of them carries the announcing setter.</summary>
        public bool Announcing { get; set; }
    }

    /// <summary>
    /// A described state with an arrival written into it - the complete node a
    /// group list is built from.
    /// </summary>
    /// <remarks>
    /// A patch carries only what changed, at both levels: the state's own name
    /// and group ride once and never again, and its setters arrive one at a
    /// time. A <c>replace</c> at either level is what says a value has GONE, and
    /// carries the complete node with it - so that half starts over rather than
    /// being overlaid.
    /// </remarks>
    private static SwiftNode Merged(SwiftNode? kept, SwiftNode arriving)
    {
        SwiftNode? setters = (arriving.Children ?? []).FirstOrDefault(child => child.Type == SwiftNodeType.Setters);
        SwiftNode? had = (kept?.Children ?? []).FirstOrDefault(child => child.Type == SwiftNodeType.Setters);

        bool fresh = kept is null || arriving.Replace;
        bool freshSetters = had is null || setters?.Replace == true;

        return new SwiftNode
        {
            Id = arriving.Id,
            Type = arriving.Type,
            TypeName = arriving.TypeName,
            Props = fresh ? Overlaid(null, arriving.Props) : Overlaid(kept!.Props, arriving.Props),
            OwnProps = fresh
                ? Overlaid(null, arriving.OwnProps)
                : Overlaid(kept!.OwnProps, arriving.OwnProps),
            Children = setters is null && had is null
                ? null
                : [new SwiftNode
                {
                    Id = had?.Id ?? setters!.Id,
                    Type = SwiftNodeType.Setters,
                    Props = setters is null
                        ? had!.Props
                        : freshSetters ? setters.Props : Overlaid(had!.Props, setters.Props),
                    OwnProps = setters is null
                        ? had!.OwnProps
                        : freshSetters ? setters.OwnProps : Overlaid(had!.OwnProps, setters.OwnProps),
                }],
        };
    }

    /// <summary>
    /// What was there, with what arrived written over it - null when neither
    /// side ever spoke, so that a bag's presence goes on meaning "this was
    /// said about".
    /// </summary>
    private static Dictionary<TKey, SwiftWireValue>? Overlaid<TKey>(
        Dictionary<TKey, SwiftWireValue>? was,
        Dictionary<TKey, SwiftWireValue>? arrived)
        where TKey : notnull
    {
        if (was is null && arrived is null)
        {
            return null;
        }

        var result = new Dictionary<TKey, SwiftWireValue>(was ?? []);

        foreach (KeyValuePair<TKey, SwiftWireValue> pair in arrived ?? [])
        {
            result[pair.Key] = pair.Value;
        }

        return result;
    }

    /// <summary>
    /// A child that hangs off a view rather than being one of its children.
    /// </summary>
    /// <remarks>
    /// A <c>ContextFlyout</c> is written with a View-tier modifier, so it can
    /// arrive under a Label, a Grid or a Border alike - and everywhere it does,
    /// whatever arranges that control's children has to leave it alone. Swift
    /// appends it after the view's own children for the same reason a group's
    /// header and footer are appended: the rest keep the positions the differ
    /// gave them. A <c>VisualState</c> is the same story: written on any control,
    /// and never one of the things it lays out.
    /// </remarks>
    private static bool IsSlot(SwiftNode node) => node.Type is SwiftNodeType.ContextFlyout or SwiftNodeType.VisualState;

    /// <summary>The children a control lays out: the slots left out.</summary>
    private static List<SwiftNode> Laid(SwiftNode node) =>
        (node.Children ?? []).Where(child => !IsSlot(child)).ToList();

    /// <summary>The menu a view opens when it is right-clicked or held down.</summary>
    /// <remarks>
    /// <para>
    /// MAUI's <see cref="FlyoutBase.SetContextFlyout"/>, filled with the same
    /// entries a menu bar takes - which is why <see cref="ApplyMenuEntry"/> is
    /// shared rather than written again.
    /// </para>
    /// <para>
    /// The flyout is kept between renders and its entries are matched by
    /// identity, for the reason every kept list has: a patch about one entry
    /// carries that entry alone, and a menu rebuilt from it would arrive without
    /// the handler ids the message did not repeat.
    /// </para>
    /// </remarks>
    private void ApplyContextFlyout(View view, SwiftNode node)
    {
        if (Reuse(FlyoutBase.GetContextFlyout(view) as MenuFlyout, node) is not MenuFlyout flyout)
        {
            flyout = [];
            FlyoutBase.SetContextFlyout(view, flyout);
        }

        Track(flyout, node);
        ApplyList(flyout, node, ApplyMenuEntry);
    }

    /// <summary>
    /// The font properties MAUI shares through IFontElement.
    /// </summary>
    /// <remarks>
    /// <para>
    /// One overload per control rather than one method taking the interface:
    /// every control that has these declares them itself, they have no common
    /// base class, and <c>IFontElement</c> declares them GET-ONLY - so the
    /// interface they share cannot be assigned through.
    /// </para>
    /// <para>
    /// The family is a NAME and not text - it names a font an author registered
    /// and repeats on every control wearing it, so it rides the session's
    /// dictionary. <see cref="SwiftNode.GetString(string)"/> answers null for one, which
    /// is a font silently not applied on ten controls at once.
    /// </para>
    /// </remarks>
    private static void ApplyFont(SwiftNode node, Label label)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { label.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { label.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { label.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { label.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for one run of a formatted Label.</summary>
    private static void ApplyFont(SwiftNode node, Span span)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { span.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { span.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { span.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { span.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for a Button.</summary>
    private static void ApplyFont(SwiftNode node, Button button)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { button.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { button.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { button.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { button.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for an Entry.</summary>
    private static void ApplyFont(SwiftNode node, Entry entry)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { entry.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { entry.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { entry.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { entry.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for an Editor.</summary>
    private static void ApplyFont(SwiftNode node, Editor editor)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { editor.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { editor.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { editor.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { editor.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for a Picker.</summary>
    private static void ApplyFont(SwiftNode node, Picker picker)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { picker.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { picker.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { picker.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { picker.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for a DatePicker.</summary>
    private static void ApplyFont(SwiftNode node, DatePicker picker)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { picker.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { picker.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { picker.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { picker.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for a TimePicker.</summary>
    private static void ApplyFont(SwiftNode node, TimePicker picker)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { picker.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { picker.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { picker.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { picker.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for a RadioButton.</summary>
    private static void ApplyFont(SwiftNode node, RadioButton button)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { button.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { button.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { button.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { button.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>The font properties, for a SearchBar.</summary>
    private static void ApplyFont(SwiftNode node, SearchBar search)
    {
        if (node.GetNumber(SwiftProp.FontSize) is double size) { search.FontSize = size; }
        if (node.GetName(SwiftProp.FontFamily) is string family) { search.FontFamily = family; }
        if (node.GetFontAttributes(SwiftProp.FontAttributes) is FontAttributes attributes) { search.FontAttributes = attributes; }
        if (node.GetBool(SwiftProp.FontAutoScalingEnabled) is bool scaling) { search.FontAutoScalingEnabled = scaling; }
    }

    /// <summary>
    /// Placeholder for an unrecognized node type.
    /// </summary>
    /// <remarks>
    /// Rendering a visible marker rather than throwing: an unknown control is
    /// almost always a renderer that has not caught up with the Swift side, and
    /// seeing which type is missing beats an exception that hides the rest of
    /// the interface. The marker records the unknown type as its own, so it can
    /// never be mistaken later for the Label it is made of.
    /// </remarks>
    private Label ReconcileUnknown(SwiftNode node, View? existing, string? why = null)
    {
        if (Reuse(existing, node) is not Label label)
        {
            label = new Label();
        }

        label.Text = why is null
            ? $"[StateUI: unknown node type '{node.TypeName}']"
            : $"[StateUI: '{node.TypeName}' {why}]";
        label.TextColor = Colors.Firebrick;
        label.FontAttributes = FontAttributes.Italic;

        return Track(label, node);
    }

    /// <summary>
    /// Whether MAUI can make a control of this type on the platform running.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Only <c>Map</c> has to be asked, and it has to be asked badly. Its
    /// handlers are an application's own opt-in - <c>UseMauiMaps</c> - and on
    /// Windows there are none to register at all, that call throwing from
    /// inside registration. A Map built with no handler behind it does not fail
    /// where this renderer can see it: the platform throws
    /// <c>HandlerNotFoundException</c> later, while it realizes the page, so
    /// the whole page's content is lost and it comes up blank. Measured on
    /// Windows, where the Map sample drew its title and nothing
    /// else - no marker, no crash, no word anywhere.
    /// </para>
    /// <para>
    /// Asking the registry first turns that into the marker this renderer
    /// already shows for a type it does not know, which says the same thing one
    /// step further on: here is a control that cannot be made here. The rest of
    /// the page then draws, which is the whole point of the marker.
    /// </para>
    /// </remarks>
    /// <param name="handlers">MAUI's own registry, or null before there is one.</param>
    /// <param name="control">The MAUI class the node stands for.</param>
    /// <returns>
    /// True when the control can be made - and true when there is no registry
    /// to ask, since no answer is not the same as no, and drawing the marker
    /// over a control that works would be the worse mistake. A handler that is
    /// unregistered when a page is built is never registered later.
    /// </returns>
    internal static bool CanBeMade(IMauiHandlersFactory? handlers, Type control) =>
        handlers is null || handlers.GetHandlerType(control) is not null;

    /// <summary>
    /// The delegate a registered control's <c>create</c> wires its events
    /// through - this renderer's <see cref="Raise(object?, SwiftEvent, byte[])"/>
    /// family, made once and shared by every registration.
    /// </summary>
    private StateUIRaise? _registeredRaise;

    /// <summary>
    /// A control the APPLICATION registered - see <see cref="StateUIControls"/>.
    /// The same shape every built-in case follows: reuse by identity, create
    /// once (which is where the registration wires its events), apply the
    /// registration's own properties, then the shared tier, then Track. A
    /// type nobody registered draws the unknown-control marker, exactly as
    /// before there was a registry.
    /// </summary>
    private View ReconcileRegistered(SwiftNode node, View? existing)
    {
        if (StateUIControls.Find(node.TypeName) is not { } registration)
        {
            return ReconcileUnknown(node, existing);
        }

        View? view = Reuse(existing, node);

        if (view is null)
        {
            _registeredRaise ??= (sender, eventName, payload) => Raise(sender, eventName, payload);
            view = registration.Create(_registeredRaise);
        }

        // The DECLARED properties first, generically - the same value
        // conversion a style's setter takes - then whatever the imperative
        // applier wants on top. By NAME, which is the only form an
        // application's own property has: SwiftKey.Own finds it in the bag it
        // arrived in.
        if (registration.Properties is not null && (node.Props is not null || node.OwnProps is not null))
        {
            foreach ((string name, BindableProperty property) in registration.Properties)
            {
                SwiftKey key = SwiftKey.Own(name);

                if (SwiftStyles.Value(property, node, key) is object value)
                {
                    view.SetValue(property, value);
                }
            }
        }

        registration.Apply?.Invoke(view, node);
        ApplyView(node, view);
        Track(view, node);

        // The registration's one content slot, the Border shape: the child is
        // reconciled by identity - created, patched, kept - and the setter is
        // called only when the slot CHANGES HANDS, so an apply that merely
        // patched the same view never re-attaches it. What the slot holds now
        // is this renderer's to remember: the registration has a setter, not
        // a property the renderer could read back.
        if (registration.Content is not null && node.Children is not null)
        {
            _registeredContent.TryGetValue(view, out View? had);
            View? inner = Laid(node) is { Count: > 0 } children
                ? Reconcile(had, children[0])
                : node.Arranged ? null : had;

            if (!ReferenceEquals(inner, had))
            {
                _registeredContent.Remove(view);

                if (inner is not null)
                {
                    _registeredContent.Add(view, inner);
                }

                registration.Content(view, inner);
            }
        }

        return view;
    }

    /// <summary>
    /// What each registered container's slot holds now - the previous view a
    /// patch about the content is reconciled against. Weak on the control, the
    /// reason every such map here is: there is no one place a control is
    /// dropped.
    /// </summary>
    private readonly System.Runtime.CompilerServices.ConditionalWeakTable<View, View> _registeredContent = new();

    /// <summary>
    /// The states each view described for itself, complete - see
    /// <see cref="ApplyVisualStates"/> for why a patch cannot be built from.
    /// </summary>
    private readonly System.Runtime.CompilerServices.ConditionalWeakTable<View, Described> _states = new();

    // ---- MAUI's members, translated onto ours -----------------------------
    //
    // What a payload REPORTS, going the way the tree comes: the mirrors in
    // Protocol/SwiftWireEnums.cs carry this repository's numbers, and a switch
    // naming the MAUI member literally is what puts one on the wire. Never a
    // cast. It is the same argument the tree's own values make - MAUI's
    // numbers are MAUI's business, and a release that renumbered one would
    // have every report here read as a different member with nothing failing -
    // and it holds even where the two lists agree today, as SwipeDirection's
    // four bits do. The default arm is for the member a newer MAUI adds: the
    // Swift side reads a number it has no case for as its own `.unknown`, so
    // both ends degrade to the same answer.

    /// <summary>How far along a gesture is, as this side's member.</summary>
    /// <remarks>
    /// MAUI's four are all named here, so the default is for a fifth a later
    /// release might add - and it sends a number NO case has on purpose, which
    /// the Swift reader refuses, leaving the handler alone. There is no
    /// "unknown" status to degrade to, and inventing one would have a handler
    /// act on a report nobody understood.
    /// </remarks>
    internal static SwiftGestureStatus Member(GestureStatus status) => status switch
    {
        GestureStatus.Started => SwiftGestureStatus.Started,
        GestureStatus.Running => SwiftGestureStatus.Running,
        GestureStatus.Completed => SwiftGestureStatus.Completed,
        GestureStatus.Canceled => SwiftGestureStatus.Canceled,
        _ => (SwiftGestureStatus)(-1),
    };

    /// <summary>
    /// Which way a swipe went, as this side's bit. ONE of them: the renderer
    /// attaches a recognizer per direction so that a single bit is all a report
    /// can carry - see <see cref="ApplySwipe"/> - so this is a member and not a
    /// set, and a `way` that is somehow neither is refused by the Swift reader
    /// rather than guessed at here.
    /// </summary>
    internal static SwiftSwipeDirection Member(SwipeDirection way) => way switch
    {
        SwipeDirection.Right => SwiftSwipeDirection.Right,
        SwipeDirection.Left => SwiftSwipeDirection.Left,
        SwipeDirection.Up => SwiftSwipeDirection.Up,
        SwipeDirection.Down => SwiftSwipeDirection.Down,
        _ => 0,
    };

    /// <summary>Why a navigation happened, as this side's member.</summary>
    internal static SwiftWebNavigationEvent Member(WebNavigationEvent why) => why switch
    {
        WebNavigationEvent.Back => SwiftWebNavigationEvent.Back,
        WebNavigationEvent.Forward => SwiftWebNavigationEvent.Forward,
        WebNavigationEvent.NewPage => SwiftWebNavigationEvent.NewPage,
        WebNavigationEvent.Refresh => SwiftWebNavigationEvent.Refresh,
        _ => SwiftWebNavigationEvent.Unknown,
    };

    /// <summary>How a navigation ended, as this side's member.</summary>
    internal static SwiftWebNavigationResult Member(WebNavigationResult outcome) => outcome switch
    {
        WebNavigationResult.Success => SwiftWebNavigationResult.Success,
        WebNavigationResult.Cancel => SwiftWebNavigationResult.Cancel,
        WebNavigationResult.Timeout => SwiftWebNavigationResult.Timeout,
        WebNavigationResult.Failure => SwiftWebNavigationResult.Failure,
        _ => SwiftWebNavigationResult.Unknown,
    };
}
