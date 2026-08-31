// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The control hierarchy, mirroring MAUI's.
//
// MAUI declares its properties once, high up, and every control inherits them:
// Opacity comes from VisualElement, Margin from View, Padding from Layout,
// FontSize from the IFontElement interface. The same split is repeated here as
// protocols, so a modifier is available on exactly the controls that have the
// property in MAUI - `.spacing()` on a stack, `.placeholder()` on an Entry, and
// nothing on a Label that a MAUI Label does not have.
//
// The hierarchy is TWO parallel halves, and the split is what makes "only what
// is allowed can be written" a compiler rule rather than a convention:
//
//     PropertyContainer            what holds property VALUES - controls and styles
//     ├── VisualElementProperties  opacity, isVisible, backgroundColor, size…
//     │   └── ViewProperties       margin, options, the attached properties
//     │       ├── LayoutProperties safeAreaEdges
//     │       │   └── StackBaseProperties  spacing
//     │       └── ShapeProperties  fill, stroke…
//     └── the mixins MAUI expresses as interfaces: TextStyleElement,
//         TextElement, FontElement, TextAlignmentElement, PaddingElement
//         (the ones only a few controls have get a file each: BorderElement,
//         BarElement, ImageElement, MenuItemElement)
//
//     Element                      anything that can describe itself as a tree
//     └── BindableObject           a PropertyContainer IN the tree - events live here
//         └── VisualElement        identity (.id), lifecycle, the read-only bindings
//             └── View             gestures, the context menu
//                 └── Layout       (wears LayoutProperties and PaddingElement)
//                     └── StackBase
//
// A control conforms on the ELEMENT side and inherits the property side
// through it; a `Style` conforms to the PROPERTY side alone - so a style
// offers exactly the setters its target can carry, and an event, a gesture or
// an `.id()` on one does not compile.
//
// Every modifier returns a MODIFIED COPY. Nothing mutates in place, so a view is
// a value all the way down and the chain reads in one direction:
//
//     Label("Total").fontSize(20).textColor(.gray).margin(0, 8)

/// Anything carrying MAUI properties, whether or not it is drawn.
/// MAUI: BindableObject.
///
/// It sits BELOW VisualElement because MAUI has a tier there too. MAUI's
/// `Span` - one run of text inside a Label, and `TextSpan` here - carries
/// TextColor, FontSize and BackgroundColor and is not a view at all: no
/// opacity, no margin, no size. So
/// the mixins standing for MAUI's ITextElement and IFontElement have to be
/// wearable by something that is not a VisualElement, and this is what they are
/// written against.
public protocol PropertyContainer {
    /// What a modifier gives back.
    ///
    /// A control gives back ITSELF, so a chain goes on offering everything that
    /// control has: `Label("Hi").margin(8).lineBreakMode(.wordWrap)`. A style
    /// gives back itself the same way.
    ///
    /// A composed view has no node of its own to change, so it gives back a
    /// `ModifiedContent`, which does - see ContentView. That is the whole reason
    /// this is not simply `Self`.
    associatedtype Modified = Self

    /// The node being described. Modifiers copy it, change one property, and
    /// return the copy.
    var node: Node { get set }

    /// A copy of the node with one thing changed.
    ///
    /// The one operation every modifier in this file is built from, which is
    /// what keeps them all working for composed views and styles as well as
    /// controls: there is a single place where a change is stored, and only
    /// that place has to know where it goes.
    func modified(_ change: (inout Node) -> Void) -> Modified
}

extension PropertyContainer {
    /// Sets a property by its token, for anything the typed modifiers do not
    /// cover yet. Named after MAUI's BindableObject.SetValue.
    ///
    ///     Label("Hi").setValue(.fontSize, .number(20))
    ///     Label("Hi").setValue("fontSize", .number(20))   // the same, spelled
    ///
    /// The vocabularies are PUBLIC, so the library's own tokens are there to be
    /// written; an application reaching a property of a control IT registered
    /// declares a token of its own the same way, and a literal serves for a
    /// one-off, `Prop` being `ExpressibleByStringLiteral`. See Core/Tokens.swift.
    ///
    /// The renderer has to know the name too - an unrecognized property is
    /// ignored rather than reported.
    public func setValue(_ property: Prop, _ value: PropValue) -> Modified {
        modified { $0.props[property] = value }
    }

    /// The same, from a `Binding` - the value it holds, and a note of whose
    /// state that was.
    ///
    /// The note is what ARMS the property: a flight started on that state
    /// finds this property among the ones that moved and walks the control to
    /// it instead of assigning. A binding with nobody behind it - one made
    /// from closures - writes the value and arms nothing, which is the same
    /// binding `animateTo` refuses. See Core/Flight.swift.
    ///
    /// This is the door an APPLICATION arms its own registered control
    /// through - the library's armed modifiers are all one line over it, and
    /// an app's is the same line:
    ///
    ///     extension RatingBar {
    ///         func rating(_ value: Binding<Double>) -> Modified {
    ///             setValue(.rating, .number(value.wrappedValue), armedOn: value)
    ///         }
    ///     }
    ///
    /// The host walks whatever the registration DECLARED - the same table a
    /// style setter resolves through - so declaring the BindableProperty once
    /// is what makes the value styleable and walkable both. Write it on the
    /// CONTROL, never on its `…Properties` protocol: a `StyleBag` wears those,
    /// and a style has no state to arm.
    public func setValue<Value>(
        _ property: Prop,
        _ value: PropValue,
        armedOn binding: Binding<Value>
    ) -> Modified {
        modified {
            $0.props[property] = value
            $0.armed[property] = binding.flightKey
        }
    }
}

extension PropertyContainer where Modified == Self {
    /// A copy with one property changed. What every modifier on a control or a
    /// style is built from.
    public func modified(_ change: (inout Node) -> Void) -> Self {
        var copy = self
        change(&copy.node)
        return copy
    }
}

/// Anything carrying MAUI properties IN THE TREE, whether or not it is drawn.
/// MAUI: BindableObject.
///
/// A `PropertyContainer` that is also an `Element`: a control describes itself
/// in the tree, where a `Style` only carries values - which is why the events
/// are declared HERE and not one tier down. What can hold a handler is
/// something that exists on screen, never a bag of values.
public protocol BindableObject: PropertyContainer, Element where Modified: Element {}

/// A control backed by a node, and drawn. MAUI: VisualElement.
public protocol VisualElement: BindableObject, VisualElementProperties {}

extension BindableObject {
    /// Registers a handler for an event by name, for events the typed modifiers
    /// do not cover yet - beside whatever is there, with the VALUES the event
    /// carried.
    ///
    ///     BoxView()
    ///         .onPinchUpdated { … }
    ///         .onEvent(.pinchUpdated) { payload in
    ///             log.append(payload.value(1)?.number ?? 0)   // the scale
    ///         }
    ///
    /// The other half of the `setValue` escape hatch, and the ONLY one for
    /// events: nothing public replaces a handler, because a two-way binding
    /// leaves a write-back handler behind and replacing it would kill the
    /// binding without a word. A typed modifier turns a payload into a value
    /// and drops one it cannot read - which is right for an author and wrong
    /// for anyone asking why nothing happens. This hands over exactly what the
    /// host sent, unread: one typed value per property of the MAUI EventArgs,
    /// in the order MAUI declares them - `payload.value(0)?.string` reads the
    /// first as text, `.number`, `.bool` and `.numbers` read the other kinds,
    /// and an event with nothing to say hands over an empty list. The event
    /// is a token - a literal spelling works, and an application listening to
    /// its own control's event declares one, exactly as the library does.
    public func onEvent(_ event: Event, _ handler: @escaping ValueEventHandler<[PropValue]>) -> Modified {
        addHandler(event) { try await handler(EventBuffer.current) }
    }

    /// Adds a handler to an event that may already have one - the typed form
    /// every modifier in this library writes: `.textChanged`, never a
    /// spelling, Core/Tokens.swift being the one place the names exist.
    ///
    /// What a two-way binding leaves behind is a handler: `Entry($name)` writes
    /// the new text back on every edit. An `.onTextChanged` written after it has
    /// to run BESIDE that, not instead of it, or the binding would go quietly
    /// dead - which is why the typed event modifiers all come through here.
    ///
    /// On this tier and not on `PropertyContainer`, so nothing reachable from
    /// a `Style` - the library's own code included - can put a handler in a
    /// bag that cannot carry one.
    func addHandler(_ event: Event, _ handler: @escaping EventHandler) -> Modified {
        modified { $0.addHandler(event, handler) }
    }
}

extension BindableObject where Modified == Self {
    /// The node this control describes - itself, since a control has one.
    public var body: Node { node }
}

// MARK: - VisualElement

/// The properties every drawn control has - the value half of MAUI's
/// VisualElement, shared by the control and its `Style`. What is NOT here is
/// deliberate: identity, lifecycle and the read-only bindings live on
/// `VisualElement`, where only a control can reach them.
public protocol VisualElementProperties: PropertyContainer {}

extension VisualElement {
    /// How this view's values MOVE when they change. This library's own.
    ///
    ///     Border { … }.motion(.spring(response: 260))
    ///     Label(count).motion(.none)
    ///
    /// A value that changes TRAVELS to its new setting - that is the default,
    /// and this is where it is changed for one view. `.none` snaps, which is
    /// what a reading written on every frame wants: a number following a
    /// finger, a clock's seconds, anything already moving under its own steam.
    ///
    /// It applies to THIS view and not to what is inside it. Nothing else in
    /// this library reaches down a tree, and a value travelling because
    /// something four levels up said so is the kind of surprise that costs an
    /// afternoon to find; a whole application is set at once with
    /// `Application.motion`.
    ///
    /// - Parameter motion: how its values are to travel.
    /// - Returns: the view, with the motion on it.
    public func motion(_ motion: Motion) -> Modified {
        modified { node in
            var plan = node.motion ?? MotionPlan(base: nil)
            plan.base = motion
            node.motion = plan
        }
    }

    /// How SOME of this view's values move, leaving the rest as they were.
    /// This library's own.
    ///
    ///     VStack { … }
    ///         .motion(.spring(response: 240))
    ///         .motion(.none, .size)
    ///
    /// Written beside the plain form or on its own, and as many times as there
    /// are answers to give. The LAST one that names a value is the one that
    /// answers for it, which is what a modifier written later means everywhere
    /// else in this library.
    ///
    /// What it is for: a view whose SHAPE changes should usually take its new
    /// size at once while still crossing to its new place - a panel that grows
    /// out of nothing is the one movement a reader reads as a fault, and a
    /// panel that slides is not.
    ///
    /// - Parameters:
    ///   - motion: how those values are to travel.
    ///   - values: which of them. See `MotionValues` for what each name covers.
    /// - Returns: the view, with the rule on it.
    public func motion(_ motion: Motion, _ values: MotionValues) -> Modified {
        modified { node in
            var plan = node.motion ?? MotionPlan(base: nil)
            plan.rules.append((values: values, motion: motion))
            node.motion = plan
        }
    }

    /// Who this view is, among its siblings.
    ///
    /// Two renders are matched by identity: a view that comes back with the same
    /// one keeps the control it already had, and only the properties that
    /// changed are written to it. Give one to anything whose position can
    /// change - the rows of a collection above all - and inserting, removing or
    /// reordering MOVES the existing controls instead of rewriting each one into
    /// its neighbour:
    ///
    ///     VStack {
    ///         ForEach(items, id: \.id) { item in
    ///             Label(item.title)           // identity from the loop
    ///         }
    ///
    ///         if showingTotal {
    ///             Label("Total").id("total")  // identity written by hand
    ///         }
    ///     }
    ///
    /// `ForEach` already gives each view its item's identity, so this modifier
    /// is for a view written by hand - or for one whose identity is something
    /// other than what the loop hands out, since the author's `.id()` wins.
    ///
    /// A view without one is identified by its position, which is what a fixed
    /// layout wants and what a collection cannot use.
    ///
    /// ANY `Hashable` is an identity - a string, a number, a UUID, or the
    /// author's own enum or struct. It is described into text here, which is
    /// what a window's `id`, a navigation path's element and a modal's do too,
    /// so one value means one thing wherever identity is given:
    ///
    ///     Label(file.name).id(file)           // the item itself
    ///     Label(tab.title).id(tab)            // the same enum a window uses
    ///
    /// The trap is a type that describes itself with LESS than it holds: the
    /// text comes from `String(describing:)`, so a `CustomStringConvertible`
    /// printing one field of a compound key gives two different values one
    /// identity, and the differ then tells those views apart by where they
    /// stand rather than by what they are. An enum's or a struct's synthesized
    /// description carries every field and is safe; one written by hand has to
    /// stay as distinct as the value.
    ///
    /// A CLASS has no synthesized description at all - it prints its type's
    /// name, the same text for every instance of it - so identify a class by
    /// something it HOLDS (`.id(file.path)`) rather than by the object.
    ///
    /// Not a property in the usual sense, so it does not go through `setValue`:
    /// it is not sent to MAUI as one. The host keeps it on the control, in the
    /// attached element every walk matches by.
    ///
    /// - Parameter value: who this view is. Distinct among its siblings and
    ///   the same across renders - two views sharing one identity are two views
    ///   the differ cannot tell apart.
    public func id(_ value: some Hashable) -> Modified {
        modified { $0.id = String(describing: value) }
    }

    /// Puts this control INTO state - how an ACT reaches it: the differ fills
    /// the state with the element's own identity as it walks, so there is
    /// nothing to spell and nothing to collide. See Core/ControlState.swift.
    ///
    ///     @State private var field = ControlState<Entry>()
    ///
    ///     Entry($address).assign(field)
    ///     Button("Edit").onClicked { try await field.focus() }
    ///
    /// NOT an identity: a view carrying only an assignment is still matched by
    /// where it was written, so a collection's rows keep wanting `.id()` - and
    /// both compose, `.id("row-7").assign(row)` being a named row one act can
    /// also reach. Typed: a `ControlState<Self>`, so the declaration and the
    /// view agree at compile time, and the state offers exactly the acts this
    /// control has. On a COMPOSED view, write it directly on the initializer's
    /// result: the later links of a chain type as the wrapper the modifiers
    /// return, not as the view.
    public func assign(_ state: ControlState<Self>) -> Modified {
        modified { $0.assigned = state.box }
    }

    /// Provides an object to this view and everything under it, resolved by
    /// TYPE: any view below declaring `@Environment var context: MyContext`
    /// reads the nearest `MyContext` provided above it. A nearer
    /// `.environment()` of the same type overrides for its own branch.
    ///
    ///     @State var context = MyContext()   // a @StateClass, usually
    ///
    ///     ChildView()
    ///         .environment(context)
    ///
    /// Providing is free for this view: it passes a reference and reads no
    /// property, so changes IN the object rebuild the readers below and not
    /// the provider. Replacing the object itself - writing the `@State` that
    /// holds it - rebuilds the branch, which is then told about the new one.
    /// Nothing about it crosses the boundary; see Core/Environment.swift.
    public func environment<Value: AnyObject>(_ object: Value) -> Modified {
        modified { $0.environments.append((key: ObjectIdentifier(Value.self), object: object)) }
    }

    /// A style from the application's resources, by the key it was given.
    /// MAUI: VisualElement.Style, written `Style="{StaticResource Headline}"`.
    ///
    ///     Label("Welcome").style("Headline")
    ///
    /// Only for a style that HAS a key: one without applies to every control of
    /// its type by itself, which is what makes it implicit. See Views/Style.swift.
    ///
    /// The key is a NAME rather than prose - one spelling meaning one style
    /// wherever it is written - so it is a `.name` and not a `.string`. It
    /// never leaves this side in any case: `styled(_:with:)` resolves it and
    /// takes it off the node, the host having no dictionary to look one up in.
    public func style(_ key: String) -> Modified { setValue(.style, .name(key)) }
}

extension VisualElementProperties {
    /// Whether the view is there at all. MAUI: VisualElement.IsVisible.
    ///
    /// **SHOWING AND HIDING CROSSES.** MAUI's own property is a flag and
    /// nothing else - a view blinks in and out of existence with it - and here
    /// it is a MOTION: a view being hidden fades to nothing FIRST and goes when
    /// it gets there, and one being shown appears at nothing and comes up. Two
    /// views in one slot - a tab chosen, a panel swapped - therefore cross,
    /// which is the whole reason it works this way.
    ///
    /// The view stays in the tree the entire time and MAUI is simply told
    /// later; a view on its way out answers no touch, so a tap during the
    /// change reaches what is arriving. A view described for the FIRST time is
    /// simply there or not - nothing anybody saw is changing - and
    /// `.motion(.none)` puts the flag back to being a flag.
    public func isVisible(_ value: Bool) -> Modified { setValue(.isVisible, .bool(value)) }

    /// Whether the view responds to the user. Disabling a container disables
    /// everything in it. MAUI: VisualElement.IsEnabled.
    public func isEnabled(_ value: Bool) -> Modified { setValue(.isEnabled, .bool(value)) }

    /// Whether the view lets touches through to whatever is behind it. A view
    /// that is `true` is not hit at all, and is not the same as one that is
    /// disabled: a disabled view still takes the touch and does nothing with
    /// it. MAUI: VisualElement.InputTransparent.
    public func inputTransparent(_ value: Bool) -> Modified { setValue(.inputTransparent, .bool(value)) }

    /// Which way the view lays its content out - and, for a language written
    /// right to left, the edge everything starts from.
    /// MAUI: VisualElement.FlowDirection.
    ///
    ///     VStack { … }.flowDirection(.rightToLeft)
    ///
    /// It is INHERITED: a view left at `.matchParent` takes whatever the view
    /// above it has, so an application usually says it once at the top.
    public func flowDirection(_ value: FlowDirection) -> Modified { setValue(.flowDirection, value.propValue) }

    /// How opaque the view is, from 0 to 1. MAUI: VisualElement.Opacity.
    public func opacity(_ value: Double) -> Modified { setValue(.opacity, .number(value)) }

    /// What is drawn behind the view. MAUI: VisualElement.BackgroundColor.
    ///
    /// A `Color(light:dark:)` here is resolved as it is written, the read
    /// recorded - a theme change rebuilds the views that asked, and the other
    /// half is written then.
    public func backgroundColor(_ value: Color) -> Modified { setValue(.backgroundColor, value.propValue) }

    /// What is drawn behind the view, when one colour will not do.
    /// MAUI: VisualElement.Background, which is a Brush.
    ///
    ///     VStack { … }.background(.linearGradient([
    ///         GradientStop(.cornflowerBlue, 0),
    ///         GradientStop(.indigo, 1),
    ///     ]))
    ///
    /// Both exist for the reason MAUI has both: `.backgroundColor` is one
    /// colour, and this is a gradient. A view given both draws the brush.
    public func background(_ value: Brush) -> Modified { setValue(.background, value.propValue) }

    /// How wide the view asks to be, in device units. A REQUEST: the layout has
    /// the last word. MAUI: VisualElement.WidthRequest.
    public func widthRequest(_ value: Double) -> Modified { setValue(.widthRequest, .number(value)) }

    /// How tall the view asks to be. MAUI: VisualElement.HeightRequest.
    public func heightRequest(_ value: Double) -> Modified { setValue(.heightRequest, .number(value)) }

    /// The width below which the view asks not to be squeezed.
    /// MAUI: VisualElement.MinimumWidthRequest.
    public func minimumWidthRequest(_ value: Double) -> Modified { setValue(.minimumWidthRequest, .number(value)) }

    /// The height below which the view asks not to be squeezed.
    /// MAUI: VisualElement.MinimumHeightRequest.
    public func minimumHeightRequest(_ value: Double) -> Modified { setValue(.minimumHeightRequest, .number(value)) }

    /// The width above which the view asks not to be stretched.
    /// MAUI: VisualElement.MaximumWidthRequest.
    public func maximumWidthRequest(_ value: Double) -> Modified { setValue(.maximumWidthRequest, .number(value)) }

    /// The height above which the view asks not to be stretched.
    /// MAUI: VisualElement.MaximumHeightRequest.
    public func maximumHeightRequest(_ value: Double) -> Modified { setValue(.maximumHeightRequest, .number(value)) }

    /// Turns the view, in degrees clockwise, about its anchor.
    /// MAUI: VisualElement.Rotation.
    public func rotation(_ value: Double) -> Modified { setValue(.rotation, .number(value)) }

    /// Tips the view about its horizontal axis, in degrees - the top going away
    /// as the bottom comes forward. MAUI: VisualElement.RotationX.
    public func rotationX(_ value: Double) -> Modified { setValue(.rotationX, .number(value)) }

    /// Turns the view about its vertical axis, in degrees - one side going away
    /// as the other comes forward. MAUI: VisualElement.RotationY.
    public func rotationY(_ value: Double) -> Modified { setValue(.rotationY, .number(value)) }

    /// Resizes the view about its anchor, 1 being its natural size. Drawing
    /// only - the space the layout gave it does not change.
    /// MAUI: VisualElement.Scale.
    public func scale(_ value: Double) -> Modified { setValue(.scale, .number(value)) }

    /// Scales the view sideways only. MAUI: VisualElement.ScaleX.
    public func scaleX(_ value: Double) -> Modified { setValue(.scaleX, .number(value)) }

    /// Scales the view up and down only. MAUI: VisualElement.ScaleY.
    public func scaleY(_ value: Double) -> Modified { setValue(.scaleY, .number(value)) }

    /// Moves the view sideways from where the layout put it, in device units.
    /// MAUI: VisualElement.TranslationX.
    public func translationX(_ value: Double) -> Modified { setValue(.translationX, .number(value)) }

    /// Moves the view up or down from where the layout put it.
    /// MAUI: VisualElement.TranslationY.
    public func translationY(_ value: Double) -> Modified { setValue(.translationY, .number(value)) }

    /// Where rotation and scaling pivot, sideways: 0 the left edge, 1 the right,
    /// 0.5 the middle. MAUI: VisualElement.AnchorX.
    public func anchorX(_ value: Double) -> Modified { setValue(.anchorX, .number(value)) }

    /// The same, vertically: 0 the top edge, 1 the bottom.
    /// MAUI: VisualElement.AnchorY.
    public func anchorY(_ value: Double) -> Modified { setValue(.anchorY, .number(value)) }

    /// Who is drawn on top where views overlap, higher being nearer the front.
    /// MAUI: VisualElement.ZIndex.
    public func zIndex(_ value: Int) -> Modified { setValue(.zIndex, .number(Double(value))) }
}

// MARK: - What the control knows and this side does not
//
// Everything above is written TO a control. These read FROM one: properties MAUI
// changes by itself - the size a layout settled on, the focus the platform moved
// - which no event on this side could have predicted.
//
// A binding is the whole API: give it one and it is kept in step.
//
//     Entry($name).isFocused($editing)
//
// Nothing is watched until it is asked for. MAUI raises PropertyChanged on Width
// and Height at every measure, and a subscription per control would cost real
// work for an answer nobody wanted.

extension VisualElement {
    /// Runs when the view has been attached to the window and is on screen.
    /// MAUI: VisualElement.Loaded.
    ///
    /// Where something that runs for as long as the view shows is started - a
    /// clock, a poll - paired with `.onUnloaded`, which is where it stops. The
    /// pair fires again on every return: leaving a tab unloads the page's
    /// views and coming back loads them, so a loop started here and stopped
    /// there is running exactly while the reader can see it.
    ///
    ///     .onLoaded { ticking = true; try await run() }
    ///     .onUnloaded { ticking = false }
    ///
    /// MAUI raises the event as the view attaches - a handler this modifier
    /// puts on a view that is ALREADY on screen waits for the next attach,
    /// nothing replaying the one that happened.
    public func onLoaded(_ handler: @escaping EventHandler) -> Modified {
        addHandler(.loaded, handler)
    }

    /// Runs when the view stops being shown - popped with its page, hidden with
    /// the tab holding it, or no longer described by the tree at all.
    /// MAUI: VisualElement.Unloaded.
    ///
    /// The last of those is what makes this the place to stop what `.onLoaded`
    /// started: a page left behind by an assignment - `path = []` - is gone
    /// from the tree the moment that is written, and a loop nothing stops goes
    /// on running with nothing to show for it.
    public func onUnloaded(_ handler: @escaping EventHandler) -> Modified {
        addHandler(.unloaded, handler)
    }

    /// Whether the platform has given this control the focus.
    /// MAUI: VisualElement.IsFocused, which is read-only - so this only writes
    /// INTO the binding.
    public func isFocused(_ binding: Binding<Bool>) -> Modified {
        addHandler(.isFocusedChanged) {
            if let focused = EventBuffer.current.value()?.bool {
                binding.wrappedValue = focused
            }
        }
    }

    /// The width a layout settled on. MAUI: VisualElement.Width, also read-only
    /// - `widthRequest` is what asks for one.
    public func width(_ binding: Binding<Double>) -> Modified {
        addHandler(.widthChanged) {
            if let width = EventBuffer.current.value()?.number {
                // SNAPPED, like every reading this library writes back: a value
                // that follows a finger, a frame or a scroll is re-answered
                // many times a second, and one filtered through a fifth of a
                // second would lag visibly behind what the reader is doing.
                binding.snap(to: width)
            }
        }
    }

    /// The height a layout settled on. MAUI: VisualElement.Height.
    public func height(_ binding: Binding<Double>) -> Modified {
        addHandler(.heightChanged) {
            if let height = EventBuffer.current.value()?.number {
                binding.snap(to: height)
            }
        }
    }
}

// MARK: - View

/// The properties every positioned view has - the value half of MAUI's View,
/// shared by the control and its `Style`. The attached properties are here
/// too, being properties: where a view sits in a grid is as styleable as its
/// margin.
public protocol ViewProperties: VisualElementProperties {}

/// A VisualElement a layout positions. MAUI: View. What this tier ADDS to the
/// property half is what only a control can carry: the gestures, and the
/// context menu.
public protocol View: VisualElement, ViewProperties {}

extension ViewProperties {
    /// The space kept OUTSIDE the view, between it and its neighbours.
    /// MAUI: View.Margin. Padding is the space inside.
    ///
    ///     Label("Total").margin(16)                      // all four sides
    ///     Label("Total").margin(Thickness(16, 0, 0, 0))  // the left edge only
    public func margin(_ value: Thickness) -> Modified { setValue(.margin, value.propValue) }

    /// Left and right, then top and bottom. MAUI writes this `Margin="16,8"`.
    public func margin(_ horizontalSize: Double, _ verticalSize: Double) -> Modified {
        margin(Thickness(horizontalSize, verticalSize))
    }

    /// Each side in turn, in MAUI's order: left, top, right, bottom.
    public func margin(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> Modified {
        margin(Thickness(left, top, right, bottom))
    }

    /// How the view uses the width its parent offers - filling it, or sitting at
    /// one end of it. MAUI: View.HorizontalOptions.
    ///
    ///     Button("Save").horizontalOptions(.center)
    public func horizontalOptions(_ value: LayoutOptions) -> Modified {
        setValue(.horizontalOptions, value.propValue)
    }

    /// The same, for the height. MAUI: View.VerticalOptions.
    public func verticalOptions(_ value: LayoutOptions) -> Modified {
        setValue(.verticalOptions, value.propValue)
    }
}

extension View {
    /// A menu on the view itself, opened with a right-click.
    /// MAUI: FlyoutBase.SetContextFlyout.
    ///
    ///     Label(item.name)
    ///         .contextFlyout {
    ///             MenuFlyoutItem("Rename").onClicked { rename(item) }
    ///             MenuFlyoutSeparator()
    ///             MenuFlyoutItem("Delete").isDestructive(true).onClicked { remove(item) }
    ///         }
    ///
    /// The same entries a menu bar takes - `MenuFlyoutItem`, `MenuFlyoutSubItem`
    /// and `MenuFlyoutSeparator` - attached to a view instead of to a page.
    ///
    /// **Only a DESKTOP shows one.** MAUI attaches the menu on Mac Catalyst
    /// and Windows; on iOS and on Android `ViewHandler.MapContextFlyout` is an
    /// EMPTY method - read from 10.0.20's IL after a long press on both kinds
    /// of phone showed nothing - so nothing opens there and nothing complains.
    /// (The MenuFlyout handler CLASSES exist in the iOS assembly, Catalyst
    /// sharing the platform folder; the attach is what iOS lacks.) Say so
    /// where a reader would otherwise think the view is broken, and do not put
    /// the only way to do something behind it.
    ///
    /// - Parameter items: the entries, in the order they are shown.
    public func contextFlyout(@MenuBuilder _ items: () -> [Element]) -> Modified {
        modified {
            // Appended, so the view's own children keep the positions the differ
            // gave them - the rule a group's header and footer follow. The host
            // reads it by TYPE and leaves it out of the arrangement.
            $0.children.append(Node(type: .contextFlyout, children: items().map { $0.body }))
        }
    }
}

// MARK: - Gestures
//
// MAUI declares GestureRecognizers on View, so anything can carry one - a Border
// holding a whole row, an Image, a Label. That is what a list row IS in MAUI:
// not a button, but a view with a tap recognizer on it.
//
// All seven of MAUI's recognizers are here - tap, swipe, pan, pinch, pointer,
// drag and drop. Each is added to the view when the
// tree first carries a handler for it and kept for as long as it does, the same
// way a control's own events are subscribed once - so a re-render can change
// what a gesture does without anything being rebuilt.
//
// The recognizer's own properties ride with the handler rather than becoming
// modifiers of their own: `.onSwiped(direction: .left)` says what it listens
// for in the same breath as what it does, and there is no half-configured
// recognizer to leave lying about.
//
// What a gesture reports arrives already typed - see Types/Gestures.swift for
// the values and the one format they travel in.

extension View {
    // MARK: Tap

    /// Runs when the view is tapped. MAUI: TapGestureRecognizer.Tapped.
    ///
    ///     Border {
    ///         HStack { … }
    ///     }
    ///     .onTapped { path.append(.details(id)) }
    ///
    /// The whole view answers, not a button inside it - which is the difference
    /// between a row you can tap and a row with something tappable in it.
    public func onTapped(_ handler: @escaping EventHandler) -> Modified {
        addHandler(.tapped, handler)
    }

    /// The same, for a double tap or more.
    /// MAUI: TapGestureRecognizer.NumberOfTapsRequired.
    public func onTapped(
        numberOfTapsRequired: Int,
        _ handler: @escaping EventHandler
    ) -> Modified {
        // Both changes in one `modified`, because chaining would return
        // `Modified.Modified` and nothing here can promise that is `Modified`.
        modified {
            $0.props[.numberOfTapsRequired] = .number(Double(numberOfTapsRequired))
            $0.addHandler(.tapped, handler)
        }
    }

    // MARK: Swipe

    /// Runs when the view is swiped, with the direction it went.
    /// MAUI: SwipeGestureRecognizer.Swiped.
    ///
    ///     Border { … }
    ///         .onSwiped(direction: [.left, .right]) { direction in
    ///             if direction == .left { items.removeLast() }
    ///         }
    ///
    /// - Parameters:
    ///   - direction: which ways to listen for. MAUI: Direction, a flags enum -
    ///     a recognizer that listens for nothing recognizes nothing, so the
    ///     default is every direction.
    ///   - threshold: how far the finger must travel, in device units.
    ///     MAUI: Threshold.
    public func onSwiped(
        direction: SwipeDirection = .all,
        threshold: Double? = nil,
        _ handler: @escaping ValueEventHandler<SwipeDirection>
    ) -> Modified {
        modified {
            $0.props[.swipeDirection] = direction.propValue
            $0.props[.swipeThreshold] = threshold.map { .number($0) }
            $0.addHandler(.swiped) {
                // A payload that will not read leaves the handler alone, the
                // rule every gesture follows - running it with an empty set
                // instead would say "a swipe happened" with no direction, which
                // no direction test could tell from a real one.
                if let direction = SwipeDirection(EventBuffer.current.value()) {
                    try await handler(direction)
                }
            }
        }
    }

    // MARK: Pan

    /// Runs as the view is dragged, from the moment it starts until it is let
    /// go. MAUI: PanGestureRecognizer.PanUpdated.
    ///
    ///     BoxView(.cornflowerBlue)
    ///         .translationX(offsetX)
    ///         .onPanUpdated { pan in
    ///             if pan.status == .running { offsetX = pan.totalX }
    ///         }
    ///
    /// The totals are measured from where the pan began, which is what makes
    /// moving a view a matter of assigning them to its translation.
    ///
    /// - Parameter touchCount: how many fingers. MAUI: TouchCount.
    public func onPanUpdated(
        touchCount: Int? = nil,
        _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> Modified {
        modified {
            $0.props[.panTouchCount] = touchCount.map { .number(Double($0)) }
            $0.addHandler(.panUpdated) {
                if let update = PanUpdate(EventBuffer.current) {
                    try await handler(update)
                }
            }
        }
    }

    // MARK: Pinch

    /// Runs as two fingers move apart or together.
    /// MAUI: PinchGestureRecognizer.PinchUpdated.
    ///
    /// `scale` is RELATIVE - how much has changed since the last report, not
    /// since the pinch began - which is MAUI's, and why a view being pinched
    /// multiplies rather than assigns.
    public func onPinchUpdated(_ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        addHandler(.pinchUpdated) {
            if let update = PinchUpdate(EventBuffer.current) {
                try await handler(update)
            }
        }
    }

    // MARK: Pointer

    /// Runs when a pointer enters the view. MAUI:
    /// PointerGestureRecognizer.PointerEntered.
    ///
    /// A pointer is a mouse, a trackpad or a pen - so these are the desktop
    /// gestures, and on a touch-only device they never fire.
    public func onPointerEntered(_ handler: @escaping EventHandler) -> Modified {
        addHandler(.pointerEntered, handler)
    }

    /// Runs when a pointer leaves the view - the other half of a hover.
    /// MAUI: PointerGestureRecognizer.PointerExited.
    public func onPointerExited(_ handler: @escaping EventHandler) -> Modified {
        addHandler(.pointerExited, handler)
    }

    /// Runs as the pointer moves over the view, with where it is in the view's
    /// own coordinates. MAUI: PointerGestureRecognizer.PointerMoved.
    public func onPointerMoved(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        addHandler(.pointerMoved) {
            if let point = Point(EventBuffer.current.value()) {
                try await handler(point)
            }
        }
    }

    /// Runs when a pointer button goes down over the view, with where it went
    /// down in the view's own coordinates.
    /// MAUI: PointerGestureRecognizer.PointerPressed.
    public func onPointerPressed(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        addHandler(.pointerPressed) {
            if let point = Point(EventBuffer.current.value()) {
                try await handler(point)
            }
        }
    }

    /// Runs when the pointer button comes back up, with where it came up.
    /// MAUI: PointerGestureRecognizer.PointerReleased.
    public func onPointerReleased(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        addHandler(.pointerReleased) {
            if let point = Point(EventBuffer.current.value()) {
                try await handler(point)
            }
        }
    }

    // MARK: Drag and drop

    /// Makes the view draggable, carrying `text` with it.
    /// MAUI: DragGestureRecognizer.
    ///
    ///     Label(item)
    ///         .draggable(text: item)
    ///
    /// What travels is a string, because that is the one thing a MAUI
    /// DataPackage carries that means the same on every platform. The handler,
    /// if there is one, runs when the drag starts - it cannot decide what is
    /// carried, since MAUI needs the data before this side could answer.
    public func draggable(
        text: String,
        canDrag: Bool = true,
        onDragStarting: EventHandler? = nil
    ) -> Modified {
        modified {
            $0.props[.dragText] = .string(text)
            $0.props[.canDrag] = .bool(canDrag)

            if let onDragStarting = onDragStarting {
                $0.addHandler(.dragStarting, onDragStarting)
            }
        }
    }

    /// Runs when a drag that started here ends, wherever it ended.
    /// MAUI: DragGestureRecognizer.DropCompleted.
    public func onDropCompleted(_ handler: @escaping EventHandler) -> Modified {
        addHandler(.dropCompleted, handler)
    }

    /// Accepts what is dropped on the view, with the text it carried.
    /// MAUI: DropGestureRecognizer.Drop.
    ///
    ///     Border { … }
    ///         .onDrop { text in items.append(text) }
    public func onDrop(_ handler: @escaping ValueEventHandler<String>) -> Modified {
        modified {
            $0.props[.allowDrop] = .bool(true)
            $0.addHandler(.drop) {
                if let text = EventBuffer.current.value()?.string {
                    try await handler(text)
                }
            }
        }
    }

    /// Runs while a drag is over the view, before it is let go.
    /// MAUI: DropGestureRecognizer.DragOver.
    public func onDragOver(_ handler: @escaping EventHandler) -> Modified {
        addHandler(.dragOver, handler)
    }

    /// Runs when a drag leaves the view without being let go - the mirror of
    /// `onDragOver`, and where a highlight put up there is taken down.
    /// MAUI: DropGestureRecognizer.DragLeave.
    public func onDragLeave(_ handler: @escaping EventHandler) -> Modified {
        addHandler(.dragLeave, handler)
    }
}

// MARK: - Where a view sits in a Grid
//
// MAUI declares these on Grid and writes them on the CHILD - `Grid.Row="1"` in
// XAML, `Grid.SetRow(view, 1)` in code. An attached property, in other words:
// the grid asks, the child answers. So they live on View, where any view that
// might find itself in a grid can reach them, and they keep the name they are
// written under rather than being shortened to `.row()`.
//
// A view that says nothing sits at row 0, column 0, spanning one of each.

extension ViewProperties {
    /// Which row of the enclosing Grid the view sits in, counting from 0.
    /// MAUI: Grid.Row.
    ///
    ///     Label("Name").gridRow(0).gridColumn(0)
    ///     Entry($name).gridRow(0).gridColumn(1)
    public func gridRow(_ value: Int) -> Modified { setValue(.gridRow, .number(Double(value))) }

    /// Which column of the enclosing Grid the view sits in, counting from 0.
    /// MAUI: Grid.Column.
    public func gridColumn(_ value: Int) -> Modified { setValue(.gridColumn, .number(Double(value))) }

    /// How many rows the view covers, starting at its own.
    /// MAUI: Grid.RowSpan.
    public func gridRowSpan(_ value: Int) -> Modified { setValue(.gridRowSpan, .number(Double(value))) }

    /// How many columns the view covers, starting at its own.
    /// MAUI: Grid.ColumnSpan.
    public func gridColumnSpan(_ value: Int) -> Modified { setValue(.gridColumnSpan, .number(Double(value))) }
}

// MARK: - Where a view sits in an AbsoluteLayout
//
// The same story as a Grid's, and the one place the prefix rule gives ground.
// Written out it would be `absoluteLayoutLayoutBounds`: MAUI's property really
// is LayoutBounds and its class really is AbsoluteLayout, so the stutter is
// MAUI's own. Repeating it buys nothing - `Layout` twice says no more than
// `Layout` once, and there is no second `Bounds` on an AbsoluteLayout to tell it
// apart from - and it costs an author a name nobody types right first time.
//
// So the doubled word goes and nothing else does: `.absoluteLayoutBounds` and
// `.absoluteLayoutFlags`, keeping the class prefix that says which layout is
// asking. The MAUI name is in the `///` above each, as it is everywhere else,
// which is what keeps MAUI's documentation the reference for this library.
//
// The wire says the same thing, so there is one name from the modifier to the
// renderer's table rather than a mapping in between.

extension ViewProperties {
    /// Where the view sits and how big it is.
    /// MAUI: AbsoluteLayout.LayoutBounds, shortened by the one repeated word.
    ///
    /// Read as device units unless the flags say otherwise, which is what makes
    /// the two go together:
    ///
    ///     .absoluteLayoutBounds(Rect(0.5, 0, 0.5, 1))
    ///     .absoluteLayoutFlags(.all)
    public func absoluteLayoutBounds(_ value: Rect) -> Modified {
        setValue(.absoluteLayoutBounds, value.propValue)
    }

    /// Which of those four numbers are fractions of the layout rather than
    /// device units. MAUI: AbsoluteLayout.LayoutFlags, shortened the same way.
    public func absoluteLayoutFlags(_ value: AbsoluteLayoutFlags) -> Modified {
        setValue(.absoluteLayoutFlags, value.propValue)
    }
}

// MARK: - What a view asks a FlexLayout for
//
// The flex properties written on the CHILD, which is where CSS puts them too.
// The layout's own - direction, wrap, justifyContent - are modifiers on
// FlexLayout; these are the ones a child answers with.

extension ViewProperties {
    /// Where the view comes in the line, whatever order it was written in.
    /// MAUI: FlexLayout.Order.
    public func flexLayoutOrder(_ value: Int) -> Modified {
        setValue(.flexLayoutOrder, .number(Double(value)))
    }

    /// What share of the SPARE room the view takes, against its siblings' share.
    /// 0 - MAUI's default - takes none of it. MAUI: FlexLayout.Grow.
    public func flexLayoutGrow(_ value: Double) -> Modified {
        setValue(.flexLayoutGrow, .number(value))
    }

    /// What share of the OVERFLOW the view gives up when there is not enough
    /// room. 1 is MAUI's default. MAUI: FlexLayout.Shrink.
    public func flexLayoutShrink(_ value: Double) -> Modified {
        setValue(.flexLayoutShrink, .number(value))
    }

    /// This view's answer to the layout's `alignItems`, for one that wants a
    /// different one. MAUI: FlexLayout.AlignSelf.
    public func flexLayoutAlignSelf(_ value: FlexAlignSelf) -> Modified {
        setValue(.flexLayoutAlignSelf, value.propValue)
    }

    /// How much room the view asks for before any of it is shared out.
    /// MAUI: FlexLayout.Basis.
    public func flexLayoutBasis(_ value: FlexBasis) -> Modified {
        setValue(.flexLayoutBasis, value.propValue)
    }
}

// MARK: - Layout

/// The properties every layout has, shared by the control and its `Style`.
public protocol LayoutProperties: ViewProperties {}

/// A view that arranges children. MAUI: Layout.
public protocol Layout: View, LayoutProperties, PaddingElement {}

extension LayoutProperties {
    /// Whether a child drawn outside the layout's bounds is cut off at them.
    /// MAUI: Layout.IsClippedToBounds.
    ///
    /// The trap is that this is about the LAYOUT's edges, while `.clip` on any
    /// view is about a shape given to that view.
    public func isClippedToBounds(_ value: Bool) -> Modified {
        setValue(.isClippedToBounds, .bool(value))
    }

    /// Whether `.inputTransparent` on this layout reaches its children too.
    /// MAUI: Layout.CascadeInputTransparent.
    ///
    /// True - MAUI's default - means a transparent layout lets touches through
    /// to whatever is behind the whole of it, children included. False lets the
    /// children go on being touched while the layout's own background does not.
    public func cascadeInputTransparent(_ value: Bool) -> Modified {
        setValue(.cascadeInputTransparent, .bool(value))
    }

    /// Which parts of the screen's UNSAFE strip - the notch, the bars, the
    /// soft keyboard - this layout stays clear of, one value for all four
    /// edges. MAUI: Layout.SafeAreaEdges.
    ///
    ///     VStack { … }.safeAreaEdges(.none)    // edge to edge
    ///
    /// iOS is where it shows; the other platforms have no unsafe strip and
    /// ignore it. THE TRAP this answers, measured on an iPhone: an iOS
    /// layout defaults to `.container` and MAUI applies the inset at ARRANGE
    /// time only, so a flyout pane's header pushes its content below the
    /// status bar while its MEASURED height knows nothing of it - the bottom
    /// of the header is clipped by exactly the safe-area inset. `.none` on
    /// the header is the answer: the content sits where the padding says and
    /// the frame fits it.
    public func safeAreaEdges(_ value: SafeAreaRegions) -> Modified {
        setValue(.safeAreaEdges, value.propValue)
    }

    /// The same, said for the horizontal and the vertical edges separately -
    /// MAUI's two-value form.
    ///
    ///     Grid { … }.safeAreaEdges(.none, .container)
    ///
    /// Written out to all four edges before it travels - left and right from
    /// the first, top and bottom from the second - so the wire carries the one
    /// shape a `SafeAreaEdges` is and the host has a single thing to read
    /// rather than three spellings of it.
    ///
    /// - Parameters:
    ///   - horizontal: what the left and right edges stay clear of.
    ///   - vertical: what the top and bottom edges stay clear of.
    public func safeAreaEdges(
        _ horizontal: SafeAreaRegions,
        _ vertical: SafeAreaRegions
    ) -> Modified {
        safeAreaEdges(horizontal, vertical, horizontal, vertical)
    }

    /// The same, one edge at a time, in MAUI's order.
    ///
    /// The four regions travel as MEMBERS, in the order MAUI's `SafeAreaEdges`
    /// declares them - each one a value of its own rather than a run of
    /// numbers, a member and a quantity being different things on this wire.
    /// The one-value form sends the same member once, as a single
    /// `.enumeration`.
    ///
    /// - Parameters:
    ///   - left: what the left edge stays clear of.
    ///   - top: what the top edge stays clear of.
    ///   - right: what the right edge stays clear of.
    ///   - bottom: what the bottom edge stays clear of.
    public func safeAreaEdges(
        _ left: SafeAreaRegions,
        _ top: SafeAreaRegions,
        _ right: SafeAreaRegions,
        _ bottom: SafeAreaRegions
    ) -> Modified {
        setValue(.safeAreaEdges, .values([
            left.propValue,
            top.propValue,
            right.propValue,
            bottom.propValue,
        ]))
    }
}

/// The properties every stack has, shared by the control and its `Style`.
public protocol StackBaseProperties: LayoutProperties {}

/// A layout that stacks its children in one direction. MAUI: StackBase.
public protocol StackBase: Layout, StackBaseProperties {}

extension StackBaseProperties {
    /// The gap left BETWEEN children, in device units - not before the first or
    /// after the last, which is what padding is for. MAUI: StackBase.Spacing.
    public func spacing(_ value: Double) -> Modified { setValue(.spacing, .number(value)) }
}

// MARK: - Shape
//
// MAUI declares Fill, Stroke and how the stroke is drawn once, on Shape, and
// Rectangle, RoundRectangle, Ellipse, Line, Path, Polygon and Polyline inherit
// every one of them. So they are a tier here too, exactly as the font properties
// are - and like the font tier they are checked once, by the Elements fixture,
// rather than once per shape.

/// The properties every shape has, shared by the control and its `Style`.
public protocol ShapeProperties: ViewProperties {}

/// A drawn outline. MAUI: Shape.
public protocol Shape: View, ShapeProperties {}

extension ShapeProperties {
    /// What the inside of the shape is painted with. MAUI: Shape.Fill.
    ///
    ///     Ellipse().fill(.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]))
    public func fill(_ value: Brush) -> Modified { setValue(.fill, value.propValue) }

    /// The same, in one colour - `.fill(.solidColor(colour))` said shortly.
    public func fill(_ value: Color) -> Modified { fill(.solidColor(value)) }

    /// What the outline is painted with. MAUI: Shape.Stroke.
    public func stroke(_ value: Brush) -> Modified { setValue(.stroke, value.propValue) }

    /// The same, in one colour.
    public func stroke(_ value: Color) -> Modified { stroke(.solidColor(value)) }

    /// How thick the outline is, in device units. MAUI: Shape.StrokeThickness,
    /// whose default is 0 - where a `Border`'s defaults to 1.
    ///
    /// So a shape needs BOTH a stroke and a thickness before any outline
    /// appears; a stroke on its own draws nothing.
    public func strokeThickness(_ value: Double) -> Modified {
        setValue(.strokeThickness, .number(value))
    }

    /// The dashes and the gaps between them, in multiples of the stroke
    /// thickness. MAUI: Shape.StrokeDashArray.
    ///
    ///     Line().x2(240)
    ///         .stroke(.lightGray)
    ///         .strokeThickness(2)
    ///         .strokeDashArray([4, 2])   // 8 units of dash, 4 of gap
    public func strokeDashArray(_ value: [Double]) -> Modified {
        setValue(.strokeDashArray, .numbers(value))
    }

    /// How far into the dash pattern the line starts.
    /// MAUI: Shape.StrokeDashOffset.
    public func strokeDashOffset(_ value: Double) -> Modified {
        setValue(.strokeDashOffset, .number(value))
    }

    /// How the ends of an open line are drawn. MAUI: Shape.StrokeLineCap.
    public func strokeLineCap(_ value: PenLineCap) -> Modified {
        setValue(.strokeLineCap, value.propValue)
    }

    /// How two segments meet at a corner. MAUI: Shape.StrokeLineJoin.
    public func strokeLineJoin(_ value: PenLineJoin) -> Modified {
        setValue(.strokeLineJoin, value.propValue)
    }

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke thickness. MAUI: Shape.StrokeMiterLimit.
    public func strokeMiterLimit(_ value: Double) -> Modified {
        setValue(.strokeMiterLimit, .number(value))
    }

    /// What the shape does with the room it is given. MAUI: Shape.Aspect, which
    /// is a `Stretch` - not the `Aspect` an Image has, despite the name.
    public func aspect(_ value: Stretch) -> Modified { setValue(.aspect, value.propValue) }
}

// MARK: - InputView

/// MAUI: InputView - the class Entry, Editor and SearchBar all derive from,
/// and the one place MAUI declares what they share: the hint, its colour, the
/// keyboard, the length cap and read-only. Declared once here for the same
/// reason.
///
/// `ViewProperties` rather than `VisualElementProperties`, because this names a
/// CLASS and MAUI's InputView derives from View: a tier standing for a class
/// sits where that class sits. It is the mixins - `PaddingElement`,
/// `TextAlignmentElement` - that stop at VisualElement, and they stop there
/// because MAUI's interfaces do not imply IView: a Page takes a padding and is
/// not a view.
public protocol InputViewProperties: ViewProperties {}

/// A View the reader types into. MAUI: InputView.
///
/// The element half of the tier, the way `Layout` and `Shape` are the element
/// halves of theirs - and it is what a `Style<Entry>` is told apart BY: the
/// conditional conformances in Style.swift name the element protocol, so a
/// tier with only a property half cannot be given to a style without giving it
/// `View`'s modifiers by accident.
public protocol InputView: View, InputViewProperties {}

extension InputView {
    /// Fires on every edit, with the whole of the new text - not the character
    /// that arrived. MAUI: InputView.TextChanged.
    ///
    /// Runs after a binding's write, if there is one, so the state already
    /// holds what the payload carries.
    public func onTextChanged(_ handler: @escaping ValueEventHandler<String>) -> Modified {
        addHandler(.textChanged) {
            if let text = EventBuffer.current.value()?.string {
                try await handler(text)
            }
        }
    }
}

extension InputViewProperties {
    /// Where the caret sits, counted in characters from the start.
    /// MAUI: InputView.CursorPosition.
    ///
    /// A field the reader is typing in moves this by itself, so writing it is
    /// for putting the caret somewhere the reader did not - the end of text
    /// just filled in, say. MAUI CLAMPS it to the text, so a position past the
    /// end lands at the end.
    public func cursorPosition(_ value: Int) -> Modified {
        setValue(.cursorPosition, .number(Double(value)))
    }

    /// How many characters from the caret are selected, 0 being none.
    /// MAUI: InputView.SelectionLength.
    ///
    ///     Entry($name).cursorPosition(0).selectionLength(name.count)
    ///
    /// selects the lot, which is what a field wants when it is filled in for
    /// the reader to replace.
    public func selectionLength(_ value: Int) -> Modified {
        setValue(.selectionLength, .number(Double(value)))
    }

    /// Whether the platform underlines what it thinks is misspelt.
    /// MAUI: InputView.IsSpellCheckEnabled.
    ///
    /// Worth turning off for anything that is not prose - a code, a name, a
    /// serial number - where the underline says nothing and the platform's
    /// corrections get in the way.
    public func isSpellCheckEnabled(_ value: Bool) -> Modified {
        setValue(.isSpellCheckEnabled, .bool(value))
    }

    /// Whether the platform offers the next word as the reader types.
    /// MAUI: InputView.IsTextPredictionEnabled.
    ///
    /// Not the same as the spell check, and usually turned off with it and for
    /// the same fields.
    public func isTextPredictionEnabled(_ value: Bool) -> Modified {
        setValue(.isTextPredictionEnabled, .bool(value))
    }

    /// What the field says while it is empty. MAUI: InputView.Placeholder.
    public func placeholder(_ value: String) -> Modified {
        setValue(.placeholder, .string(value))
    }

    /// The colour of that text. MAUI: InputView.PlaceholderColor.
    public func placeholderColor(_ value: Color) -> Modified {
        setValue(.placeholderColor, value.propValue)
    }

    /// Whether the text can be selected and copied but not changed - which is
    /// not the same as disabled. MAUI: InputView.IsReadOnly.
    public func isReadOnly(_ value: Bool) -> Modified {
        setValue(.isReadOnly, .bool(value))
    }

    /// Which keyboard the platform offers - numeric, email, url and the rest.
    /// MAUI: InputView.Keyboard.
    public func keyboard(_ value: Keyboard) -> Modified {
        setValue(.keyboard, value.propValue)
    }

    /// How many characters the field accepts. MAUI: InputView.MaxLength.
    public func maxLength(_ value: Int) -> Modified {
        setValue(.maxLength, .number(Double(value)))
    }
}

// MARK: - Composition

/// A view assembled from other views. MAUI: ContentView.
///
/// This is how a piece of interface is factored out and reused:
///
///     struct Header: ContentView {
///         private let title: String
///
///         init(_ title: String) {
///             self.title = title
///         }
///
///         var content: Element {
///             Label(title).fontSize(28).fontAttributes(.bold)
///         }
///     }
///
/// `content` is read on every render, like every other part of the tree, so a
/// composed view sees state changes exactly as an inline one does.
///
/// It is configured the way every control is: WHAT IT IS goes in the
/// initializer and has no default, and everything a caller may leave out is a
/// MODIFIER returning `Self` - one copy, one assignment into a `private` field,
/// which is what keeps the memberwise initializer from being a second way in.
/// `CollectionView` is the library's own, and `itemSize`, `header`, `selection` and
/// the rest are written exactly that way. An optional value is a SECOND
/// initializer delegating to the first, never a defaulted parameter.
///
/// A composed view is a View, so the modifiers every view has can be written on
/// one - AFTER its own, since these give back something that is no longer a
/// `Header`:
///
///     Header("Settings")
///         .margin(0, 8)
///         .gridRow(1)
///
/// Not the ones that belong to a particular control, though - a composed view
/// might be made of anything, and `.fontSize()` on something that turns out to
/// be a stack would be a promise this library cannot keep.
///
/// A modifier written on one gives back a `ModifiedContent`, because there is
/// nothing here to write it on: `content` is rebuilt from scratch every time it
/// is read, so a change stored on the composed value itself would be gone by the
/// next render.
public protocol ContentView: View where Modified == ModifiedContent {
    /// What this view is made of, read afresh on every render.
    var content: Element { get }
}

extension ContentView {
    /// The content's node - a composed view IS what it is made of.
    ///
    /// Not built here: what goes into the tree is a placeholder, and the differ
    /// builds the content once it knows whether this view stood here last
    /// render - so a `@State` declared on the view keeps its value across the
    /// rebuild. See Core/Stateful.swift.
    public var body: Node {
        Node.composed(self, type: String(reflecting: Self.self)) { content.body }
    }

    /// A modifier written on a composed view. There is nothing here to keep the
    /// change in, so it goes into a `ModifiedContent` wrapping the placeholder;
    /// the differ writes what accumulates on it over the built content.
    public func modified(_ change: (inout Node) -> Void) -> ModifiedContent {
        var node = body
        change(&node)
        return ModifiedContent(node: node)
    }

    /// The placeholder, read afresh each time.
    ///
    /// Assigning to it does nothing, and nothing does: `modified` above is what
    /// every modifier goes through, and it never touches this. The requirement
    /// comes from VisualElement, where a control really does have a node of its
    /// own to keep.
    public var node: Node {
        get { body }
        set {}
    }
}

/// A composed view with a modifier written on it.
///
/// The first modifier written on a composed view produces one of these, which
/// has a node to hold the change, and from there it behaves like any other
/// view.
///
/// It offers what every MAUI view has - margin, opacity, where it sits in a grid
/// - and nothing that only some do. What is inside might be a Label or a stack,
/// and this is not the place to guess.
public struct ModifiedContent: View {
    /// The content's node, with the change written into it.
    public var node: Node

    /// Wraps a node that a modifier has already been applied to. Made by
    /// `ContentView.modified`; there is rarely a reason to call this directly.
    public init(node: Node) {
        self.node = node
    }
}
