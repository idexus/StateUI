// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The tiers a control's modifiers come from, and the modifiers every view
// shares. Each property is declared once, on the tier whose controls all carry
// it, and a `Style` wears only the property half of each tier.
// Design: docs/design/views/tiers.md#two-halves

/// Anything carrying property values, whether or not it is drawn: a control,
/// a `Style`, a `TextSpan`.
public protocol PropertyContainer {
    /// What a modifier gives back: the control or style itself, so a chain goes
    /// on offering everything it has, or a `ModifiedContent` for a composed view.
    associatedtype Modified = Self

    /// The node being described. Modifiers copy it, change one property, and
    /// return the copy.
    var node: Node { get set }

    /// A copy with one thing changed: the one operation every modifier is
    /// built from.
    func modified(_ change: (inout Node) -> Void) -> Modified
}

extension PropertyContainer {
    /// Sets a property by its token - what the typed `setValue` is written
    /// over, and every modifier that writes a value it built itself.
    func setValue(_ property: Prop, _ value: PropValue) -> Modified {
        modified { $0.props[property] = value }
    }

    /// Sets one of this element's properties to a value of the type its
    /// contract declares.
    ///
    ///     func signal(_ value: TrafficSignal) -> Self {
    ///         setValue(TrafficLightContract.signal, value)
    ///     }
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - value: what it holds.
    /// - Returns: the element, with the value on it.
    public func setValue<Owner: Contract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value
    ) -> Modified {
        setValue(property.token, value.propValue)
    }

    /// Carries one of this element's properties from a state the host keeps,
    /// the state's value being the type the contract declares - how an
    /// application's own control takes a binding for a property.
    ///
    /// Write it on the control, never on its `…Properties` protocol, which a
    /// `Style` wears too.
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - state: the whole state, `$x`, of a `@State` or a `@Binding`. A part
    ///     of one, `$room.width`, cannot be carried and is refused.
    ///   - mode: which way the value crosses.
    ///   - kind: how the host applies the value; see `StateKind`.
    /// - Returns: the element, with the registration on it.
    public func setValue<Owner: Contract, Value: HostRepresentable & StateValue>(
        _ property: ElementProperty<Owner, Value>,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        setValue(property.token, on: state, mode: mode, kind: kind)
    }

    /// The same, for a value the host can animate - a number, a colour, a
    /// thickness, a point. With `kind: .property` the host animates the
    /// property along the state's journey, so `$stars.journey.move(to: 5)`
    /// moves it; any other kind carries the value as it stands.
    ///
    ///     func rating(_ state: Binding<Double>) -> Modified {
    ///         setValue(RatingBarContract.rating, on: state, mode: .inOut, kind: .property)
    ///     }
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - state: the whole state, `$x`.
    ///   - mode: which way the value crosses.
    ///   - kind: how the host applies the value; see `StateKind`.
    /// - Returns: the element, with the registration on it.
    public func setValue<Owner: Contract, Value: HostRepresentable & Walked>(
        _ property: ElementProperty<Owner, Value>,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        setValue(property.token, on: state, mode: mode, kind: kind)
    }

    /// Writes the number of a carried state onto a property - how a drag is
    /// told where to report (`panX`, `panY`). It reads nothing at build, so
    /// the reports rebuild nothing.
    func driven<Value: StateValue>(_ property: Prop, by state: Binding<Value>) -> Modified {
        guard let image = state.image else {
            complain("`\(property.name)` was told to report into a part of a state, or a "
                + "binding made from closures, which the host cannot carry. Report "
                + "into the whole state.")
            return modified { _ in }
        }

        return setValue(property, .number(Double(Renderer.shared.number(for: image))))
    }

    /// Carries a property from a state by its token - what the typed
    /// `setValue(_:on:mode:kind:)` and every driven modifier are written over.
    /// Design: docs/design/views/bindings.md#the-image-never-the-value
    func setValue<Value: StateValue>(
        _ property: Prop,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        // The image, never the value: nothing is read at build.
        guard let image = state.image else {
            complain("`\(property.name)` was driven from a part of a state, or a binding "
                + "made from closures, which the host cannot carry. Drive it from "
                + "the whole state.")
            return modified { _ in }
        }

        state.described?.wearThemedPair()

        return modified {
            $0.driven[property] = StateRegistration(
                state: image,
                conversion: state.conversion,
                mode: mode,
                kind: kind,
                values: property.facts.moves.union(Value.moving))
        }
    }

    /// The same for a value the host can animate, by its token: `.property`
    /// carries it as a journey, any other kind as itself.
    func setValue<Value: Walked>(
        _ property: Prop,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        guard kind == .property else {
            guard let image = state.image else {
                complain("`\(property.name)` was driven from a part of a state, or a binding "
                    + "made from closures, which the host cannot carry. Drive it from "
                    + "the whole state.")
                return modified { _ in }
            }

            state.described?.wearThemedPair()

            return setValue(property, onImage: image, mode: mode, kind: kind,
                            moving: Value.moving, conversion: state.conversion)
        }

        guard let image = state.journeyImage else {
            complain("`\(property.name)` was handed a part of a state, a binding made from "
                + "closures, or a state the host already carries in another shape, "
                + "none of which it can walk. Hand it the whole state.")
            return modified { _ in }
        }

        state.described?.wearThemedPair()

        return setValue(property, onImage: image, mode: mode, kind: kind,
                        moving: JourneyLanes<Value>.moving, conversion: state.conversion)
    }

    /// The same registration over an image already made; `moving` says which
    /// lanes the value animates in - a journey's, for a carried `Double`.
    func setValue(
        _ property: Prop,
        onImage image: HostStorage,
        mode: StateMode,
        kind: StateKind,
        moving: MotionValues,
        conversion: Conversion? = nil
    ) -> Modified {
        modified {
            $0.driven[property] = StateRegistration(
                state: image,
                conversion: conversion,
                mode: mode,
                kind: kind,
                values: property.facts.moves.union(moving))
        }
    }

    /// A property the host animates from a state - what every binding twin of
    /// an animatable value, a slider's thumb and a scroller's offset are
    /// written over.
    /// Design: docs/design/views/bindings.md#binding-twins
    func journey<Value: Walked>(_ property: Prop, by state: Binding<Value>) -> Modified {
        guard let image = state.journeyImage else {
            complain("`\(property.name)` was handed a part of a state, a binding made from "
                + "closures, or a state the host already carries in another shape, "
                + "none of which it can walk. Hand it the whole state, declared for "
                + "it.")
            return modified { _ in }
        }

        state.described?.wearThemedPair()

        return setValue(property, onImage: image, mode: .inOut, kind: .property,
                        moving: JourneyLanes<Value>.moving, conversion: state.conversion)
    }

    /// A property the host sets as the state's value stands, with no animation;
    /// `.inOut` where the control reports it back, as a switch does.
    func plain<Value: StateValue>(_ property: Prop, by state: Binding<Value>, mode: StateMode = .out) -> Modified {
        setValue(property, on: state, mode: mode, kind: .plain)
    }

    /// Text the host writes into a property as the state changes; `.inOut`
    /// where the user types into it.
    func words(_ property: Prop, by state: Binding<String>, mode: StateMode = .out) -> Modified {
        setValue(property, on: state, mode: mode, kind: .text)
    }

    /// `journey(_:by:)` over a member of the type its contract declares.
    func journey<Owner: Contract, Value: Walked & HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        by state: Binding<Value>
    ) -> Modified {
        journey(property.token, by: state)
    }

    /// `plain(_:by:mode:)` over a member of the type its contract declares.
    func plain<Owner: Contract, Value: StateValue & HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        by state: Binding<Value>,
        mode: StateMode = .out
    ) -> Modified {
        plain(property.token, by: state, mode: mode)
    }

    /// `words(_:by:mode:)` over a text member.
    func words<Owner: Contract>(
        _ property: ElementProperty<Owner, String>,
        by state: Binding<String>,
        mode: StateMode = .out
    ) -> Modified {
        words(property.token, by: state, mode: mode)
    }
}

extension VisualElement {
    /// The described two-way form, for a binding the host cannot carry - a part
    /// of a state, or one made from closures: the value read at build, and each
    /// report written back through the binding.
    /// Design: docs/design/views/bindings.md#two-way-controls
    func described(_ property: Prop, _ value: Binding<Bool>, on event: Event) -> Modified {
        modified {
            $0.props[property] = .bool(value.wrappedValue)
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.bool {
                    value.wrappedValue = moved
                }
            }
        }
    }

    /// The same, for a whole number - a choice.
    func described(_ property: Prop, _ value: Binding<Int>, on event: Event) -> Modified {
        modified {
            $0.props[property] = .number(Double(value.wrappedValue))
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.int {
                    value.wrappedValue = moved
                }
            }
        }
    }

    /// The same, for text - what a field typed into reports.
    func described(_ property: Prop, _ value: Binding<String>, on event: Event) -> Modified {
        modified {
            $0.props[property] = .string(value.wrappedValue)
            $0.addHandler(event) {
                if let typed = EventBuffer.current.value()?.string {
                    value.wrappedValue = typed
                }
            }
        }
    }

    /// The same, for a day - what a date picker reports.
    func described(_ property: Prop, _ value: Binding<CalendarDate>, on event: Event) -> Modified {
        modified {
            $0.props[property] = value.wrappedValue.propValue
            $0.addHandler(event) {
                if let chosen = CalendarDate(EventBuffer.current.value()) {
                    value.wrappedValue = chosen
                }
            }
        }
    }

    /// The same, for a time of day - what a time picker reports.
    func described(_ property: Prop, _ value: Binding<ClockTime>, on event: Event) -> Modified {
        modified {
            $0.props[property] = value.wrappedValue.propValue
            $0.addHandler(event) {
                if let chosen = ClockTime(EventBuffer.current.value()) {
                    value.wrappedValue = chosen
                }
            }
        }
    }
}

extension PropertyContainer {
    /// A stable name that automation finds this by.
    ///
    ///     Button("Save").accessibilityIdentifier("save")
    ///     ToolbarItem("Home").accessibilityIdentifier("chrome.home")
    ///
    /// Nothing shows it and no screen reader says it: it is the handle a UI
    /// test, a script or an agent asks the platform's automation for. What a
    /// screen-reader user hears is `.accessibilityLabel`. Keep it stable
    /// across renders and unique on the page.
    public func accessibilityIdentifier(_ value: String) -> Modified { setValue(PropertyContainerContract.accessibilityIdentifier, value) }
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

/// Anything carrying property values in the tree, and so able to hear
/// events - which a `Style`, carrying values only, never can.
public protocol ModifiableElement: PropertyContainer, Element where Modified: Element {}

/// A control backed by a node, and drawn.
public protocol VisualElement: ModifiableElement, VisualElementProperties {}

extension ModifiableElement {
    /// Hears one of this element's events that carries nothing.
    ///
    ///     onEvent(TrafficLightContract.closed) { shown = false }
    ///
    /// Runs beside any handler already there. An event that arrives carrying
    /// anything is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract>(
        _ event: ElementEvent<Owner, Void>,
        _ handler: @escaping EventHandler
    ) -> Modified {
        addHandler(event.token) {
            guard MemberValues.carried(EventBuffer.current, by: event.name) != nil else { return }

            try await handler()
        }
    }

    /// Hears one of this element's events, its value handed over as the type
    /// its contract declares.
    ///
    ///     func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
    ///         onEvent(TrafficLightContract.lampTapped, handler)
    ///     }
    ///
    /// Runs beside any handler already there. A payload that is not what the
    /// contract says is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the value.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ handler: @escaping ValueEventHandler<Value>
    ) -> Modified {
        addHandler(event.token) {
            guard let value = MemberValues.carried(EventBuffer.current, by: event.name, as: Value.self)
            else { return }

            try await handler(value)
        }
    }

    /// Hears one of this element's events that carries two values, handed
    /// over as the types its contract declares, in its order.
    ///
    ///     onEvent(GaugeContract.dimmed) { level, lit in … }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> Modified {
        addHandler(event.token) {
            guard let (first, second) = MemberValues.carried(
                EventBuffer.current, by: event.name, as: First.self, Second.self)
            else { return }

            try await handler(first, second)
        }
    }

    /// Hears one of this element's events that carries three values, handed
    /// over as the types its contract declares, in its order.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> Modified {
        addHandler(event.token) {
            guard let (first, second, third) = MemberValues.carried(
                EventBuffer.current, by: event.name, as: First.self, Second.self, Third.self)
            else { return }

            try await handler(first, second, third)
        }
    }

    /// Adds a handler beside any already there, by token - on this tier, so
    /// nothing reachable from a `Style` can put one in a bag of values.
    /// Design: docs/design/views/modifiers.md#a-handler-runs-beside-the-one-before
    func addHandler(_ event: Event, _ handler: @escaping EventHandler) -> Modified {
        modified { $0.addHandler(event, handler) }
    }
}

extension ModifiableElement where Modified == Self {
    /// The node this control describes - itself, since a control has one.
    public var body: Node { node }
}

// MARK: - VisualElement

/// The properties every drawn control has: the value half of
/// `VisualElement`, shared by the control and its `Style`.
public protocol VisualElementProperties: PropertyContainer {}

extension VisualElement {
    /// How this view's values animate when they change.
    ///
    ///     Border { … }.motion(.spring(response: 260))
    ///     Label(count).motion(.none)
    ///
    /// A changed value animates to its new setting by default; `.none` snaps,
    /// which is what a value rewritten every frame wants. It applies to this
    /// view only, not to the views inside it; `application.motion` sets the
    /// whole application.
    ///
    /// - Parameter motion: how its values animate.
    /// - Returns: the view, with the motion on it.
    public func motion(_ motion: Motion) -> Modified {
        modified { node in
            var plan = node.motion ?? MotionPlan(base: nil)
            plan.base = motion
            node.motion = plan
        }
    }

    /// How some of this view's values animate, leaving the rest as they were.
    ///
    ///     VStack { … }
    ///         .motion(.spring(response: 240))
    ///         .motion(.none, .size)
    ///
    /// The last rule that names a value answers for it. The usual use is a view
    /// whose shape changes: it takes its new size at once while still
    /// animating to its new place.
    ///
    /// - Parameters:
    ///   - motion: how those values animate.
    ///   - values: which of them. See `MotionValues` for what each name covers.
    /// - Returns: the view, with the rule on it.
    public func motion(_ motion: Motion, _ values: MotionValues) -> Modified {
        modified { node in
            var plan = node.motion ?? MotionPlan(base: nil)
            plan.rules.append((values: values, motion: motion))
            node.motion = plan
        }
    }

    /// Who this view is among its siblings: its key across renders.
    ///
    /// A view that comes back with the same key keeps its control, and only the
    /// properties that changed are written to it. Give one to anything whose
    /// position can change, so inserting, removing or reordering moves the
    /// existing controls instead of rewriting each into its neighbour:
    ///
    ///     VStack {
    ///         ForEach(items, id: \.id) { item in
    ///             Label(item.title)           // key from the loop
    ///         }
    ///
    ///         if showingTotal {
    ///             Label("Total").id("total")  // key written by hand
    ///         }
    ///     }
    ///
    /// An `.id()` written on the view wins over the one `ForEach` gives. Any
    /// `Hashable` is a key - a string, a number, a UUID, the author's own enum
    /// or struct - compared as `String(describing:)`: a description that says
    /// less than the value gives two values one key, and a class is keyed by
    /// something it holds (`.id(file.path)`).
    ///
    /// - Parameter value: who this view is - distinct among its siblings and
    ///   the same across renders.
    public func id(_ value: some Hashable) -> Modified {
        modified { $0.id = String(describing: value) }
    }

    /// Puts an aim on this control, which is how an act reaches it.
    ///
    ///     @Aim(TextField.self) private var field
    ///
    ///     TextField($address).aim(field)
    ///     Button("Edit").onClicked { try await field.focus() }
    ///
    /// A model may declare its aims beside its state. An aim is not a key: a
    /// view carrying only an aim is still matched by where it was written, so
    /// rows keep wanting `.id()`, and the two compose - `.id("row-7").aim(row)`.
    /// On a composed view, write it directly on the initializer's result.
    ///
    /// - Parameter aim: the aim the control answers to.
    public func aim(_ aim: Aim<Self>) -> Modified {
        modified { $0.aim = aim.box }
    }

    /// Reads where a value the host is animating has got to, at most so many
    /// times a second, into a state of your own.
    ///
    ///     @State private var fade = 1.0
    ///     @State private var shown = 1.0
    ///
    ///     VStack {
    ///         Label("\(Int(shown * 100))%")
    ///     }
    ///     .opacity($fade)
    ///     .samples($fade, into: $shown, .every(100))
    ///
    /// Reading `fade` answers where it is going, and `$fade.journey.value` in a
    /// body rebuilds that body on every frame; this copies some of those frames
    /// into an ordinary state instead. It stops when the value lands, the last
    /// sample being where the value ended. A value that is only shown wants a
    /// driven text (`Label($fade.journey.convert { … })`), which costs no render.
    ///
    /// - Parameters:
    ///   - source: the value the host is animating, `$x` of a `@State`.
    ///   - target: the state to read it into, `$y`.
    ///   - asks: how often, at most.
    /// - Returns: the element, with that reading asked for.
    public func samples<Value: Walked>(
        _ source: Binding<Value>,
        into target: Binding<Value>,
        _ asks: Asks
    ) -> Modified {
        modified {
            guard let from = source.described, let image = from.walkedImage(),
                  let into = target.described
            else {
                complain("`.samples` was given a binding that borrows no @State the host "
                    + "walks - a closure binding, a part of a state, or a state carried as "
                    + "the value itself - so there is no journey to read. Hand it the "
                    + "state itself.")
                return
            }

            $0.samples.append((image: image, into: ObjectIdentifier(into), asks: asks, take: {
                // Off the lanes, not the journey's own read, so the element being
                // built does not become a reader of the value.
                guard let now = from.journeyLanes?.value else { return }

                guard StateImage.bytes(of: now.carried)
                    != StateImage.bytes(of: into.value.carried) else { return }

                target.wrappedValue = now
            }))
        }
    }

    /// Provides an object to this view and everything under it, resolved by
    /// type: any view below declaring `@Environment var context: MyContext`
    /// reads the nearest `MyContext` provided above it. A nearer
    /// `.environment()` of the same type overrides for its own branch.
    ///
    ///     @State var context = MyContext()   // a class of @State properties, usually
    ///
    ///     ChildView()
    ///         .environment(context)
    ///
    /// Providing reads no property, so a change in the object rebuilds the
    /// readers below and not the provider; replacing the object rebuilds the
    /// branch.
    public func environment<Value: AnyObject>(_ object: Value) -> Modified {
        modified { $0.environments.append((key: ObjectIdentifier(Value.self), object: object)) }
    }

    /// The keyed style from the application's style sheet that this view wears.
    ///
    ///     Label("Welcome").style("Headline")
    ///
    /// A style without a key applies to every control of its type by itself.
    public func style(_ key: String) -> Modified { setValue(VisualElementContract.style, Name(key)) }
}

extension VisualElementProperties {
    /// Whether the view is shown.
    ///
    /// Showing and hiding animate: a view being hidden fades out before it
    /// goes, one being shown fades in, so two views swapped in one place
    /// cross-fade. A view on its way out answers no touch. A view described for
    /// the first time is simply shown or not; `.motion(.none)` makes the change
    /// immediate.
    public func isVisible(_ value: Bool) -> Modified { setValue(VisualElementContract.isVisible, value) }

    /// Whether the view responds to the user. Disabling a container disables
    /// everything in it.
    public func isEnabled(_ value: Bool) -> Modified { setValue(VisualElementContract.isEnabled, value) }

    /// Whether the view and everything in it ignore input: a tap or a click
    /// goes through to whatever is behind it. Not the same as disabled - a
    /// disabled view still takes the touch and does nothing with it. A layout
    /// whose children should still answer says `letsInputThrough` instead.
    public func ignoresInput(_ value: Bool) -> Modified { setValue(VisualElementContract.ignoresInput, value) }

    /// Which way the view lays its content out - and, for a language written
    /// right to left, the edge everything starts from.
    ///
    ///     VStack { … }.layoutDirection(.rightToLeft)
    ///
    /// It is INHERITED: a view left at `.inherited` takes whatever the view
    /// above it has, so an application usually says it once at the top.
    public func layoutDirection(_ value: LayoutDirection) -> Modified { setValue(VisualElementContract.layoutDirection, value) }

    /// How opaque the view is, from 0 to 1.
    public func opacity(_ value: Double) -> Modified { setValue(VisualElementContract.opacity, value) }

    /// What is drawn behind the view. A view's own background replaces its
    /// style's, and a `Color(light:dark:)` follows the system theme.
    public func background(_ value: Color) -> Modified { setValue(VisualElementContract.background, .color(value)) }

    /// What is drawn behind the view, when one colour will not do.
    ///
    ///     VStack { … }.background(.linearGradient([
    ///         GradientStop(.cornflowerBlue, 0),
    ///         GradientStop(.indigo, 1),
    ///     ]))
    ///
    /// The same property as a colour background: the one written last wins.
    public func background(_ value: Brush) -> Modified { setValue(VisualElementContract.background, .brush(value)) }

    /// How wide the view asks to be, in device units. A request: the layout has
    /// the last word.
    public func width(_ value: Double) -> Modified { setValue(VisualElementContract.width, value) }

    /// How tall the view asks to be.
    public func height(_ value: Double) -> Modified { setValue(VisualElementContract.height, value) }

    /// The width below which the view asks not to be squeezed.
    public func minimumWidth(_ value: Double) -> Modified { setValue(VisualElementContract.minimumWidth, value) }

    /// The height below which the view asks not to be squeezed.
    public func minimumHeight(_ value: Double) -> Modified { setValue(VisualElementContract.minimumHeight, value) }

    /// The width above which the view asks not to be stretched.
    public func maximumWidth(_ value: Double) -> Modified { setValue(VisualElementContract.maximumWidth, value) }

    /// The height above which the view asks not to be stretched.
    public func maximumHeight(_ value: Double) -> Modified { setValue(VisualElementContract.maximumHeight, value) }

    /// Turns the view, in degrees clockwise, about its pivot.
    public func rotation(_ value: Double) -> Modified { setValue(VisualElementContract.rotation, value) }

    /// How this view is moved, turned and sized: one transform about the view's
    /// own centre, the same picture on every platform.
    ///
    ///     Card(item).transform(.rotate(14).scale(0.9).translate(100, 200))
    ///
    /// The parts apply in the order written, each to what the parts before it
    /// made; see `ViewTransform`. It writes `translationX`, `translationY`,
    /// `rotation`, `scaleX` and `scaleY`, so use it or those five, not both.
    ///
    /// - Parameter transform: how the view is moved, turned and sized - a value
    ///   that can be held in `@State`.
    /// - Returns: the view, transformed.
    public func transform(_ transform: ViewTransform) -> Modified {
        modified {
            $0.write(VisualElementContract.translationX, transform.x)
            $0.write(VisualElementContract.translationY, transform.y)
            $0.write(VisualElementContract.rotation, transform.rotation)
            $0.write(VisualElementContract.scaleX, transform.width)
            $0.write(VisualElementContract.scaleY, transform.height)
        }
    }

    /// Tips the view about its horizontal axis, in degrees - the top going away
    /// as the bottom comes forward.
    ///
    /// Each platform projects a turn out of the screen's plane through its own
    /// camera, so the same angle draws differently; for the same picture
    /// everywhere, write a `scaleY` of `cos(angle)` instead.
    public func rotationX(_ value: Double) -> Modified { setValue(VisualElementContract.rotationX, value) }

    /// Turns the view about its vertical axis, in degrees - one side going away
    /// as the other comes forward.
    ///
    /// Each platform projects a turn out of the screen's plane through its own
    /// camera, so the same angle draws differently; for the same picture
    /// everywhere, write a `scaleX` of `cos(angle)` instead.
    public func rotationY(_ value: Double) -> Modified { setValue(VisualElementContract.rotationY, value) }

    /// Resizes the view about its pivot, 1 being its natural size. Drawing
    /// only: the space the layout gave it does not change.
    public func scale(_ value: Double) -> Modified { setValue(VisualElementContract.scale, value) }

    /// Scales the view sideways only.
    public func scaleX(_ value: Double) -> Modified { setValue(VisualElementContract.scaleX, value) }

    /// Scales the view up and down only.
    public func scaleY(_ value: Double) -> Modified { setValue(VisualElementContract.scaleY, value) }

    /// Moves the view sideways from where the layout put it, in device units.
    public func translationX(_ value: Double) -> Modified { setValue(VisualElementContract.translationX, value) }

    /// Moves the view up or down from where the layout put it.
    public func translationY(_ value: Double) -> Modified { setValue(VisualElementContract.translationY, value) }

    /// Where rotation and scaling pivot, sideways: 0 the left edge, 1 the right,
    /// 0.5 the middle.
    public func pivotX(_ value: Double) -> Modified { setValue(VisualElementContract.pivotX, value) }

    /// The same, vertically: 0 the top edge, 1 the bottom.
    public func pivotY(_ value: Double) -> Modified { setValue(VisualElementContract.pivotY, value) }

    /// Who is drawn on top where views overlap, higher being nearer the front.
    public func zIndex(_ value: Int) -> Modified { setValue(VisualElementContract.zIndex, value) }

    // MARK: - What the view says about itself
    // Design: docs/design/views/modifiers.md#accessibility-and-automation

    /// What a screen reader says this view is.
    ///
    ///     Button(icon: "bin.png").accessibilityLabel("Delete")
    ///
    /// For a control whose meaning is carried by a picture, a colour or where
    /// it sits. On a control that shows its own words it replaces them.
    public func accessibilityLabel(_ value: String) -> Modified { setValue(VisualElementContract.accessibilityLabel, value) }

    /// What a screen reader says using the view does, after saying what it is.
    ///
    ///     Switch($lit)
    ///         .accessibilityLabel("Ceiling light")
    ///         .accessibilityHint("Turns the light on and off")
    ///
    /// Only for a view the user can act on.
    public func accessibilityHint(_ value: String) -> Modified { setValue(VisualElementContract.accessibilityHint, value) }

    /// Whether a screen reader skips this view.
    ///
    ///     ColorBox(.silver).isAccessibilityHidden(true)
    ///
    /// For decoration: a rule, a shadow, a picture repeating the words beside
    /// it. Left unsaid, the platform decides, which is nearly always right; say
    /// `false` where a platform left something out, and never hide a view the
    /// user has to act on.
    public func isAccessibilityHidden(_ value: Bool) -> Modified { setValue(VisualElementContract.isAccessibilityHidden, value) }

    /// Whether a screen reader skips this view and everything inside it.
    ///
    ///     VStack { … }.automationExcludedWithChildren(true)
    ///
    /// For a panel on screen that is not the user's business - a decorative
    /// header, a card standing behind the one in front.
    public func automationExcludedWithChildren(_ value: Bool) -> Modified { setValue(VisualElementContract.automationExcludedWithChildren, value) }

    /// That this view is a heading, and how deep.
    ///
    ///     Label("Settings").fontSize(24).accessibilityHeadingLevel(.level1)
    ///
    /// A screen-reader user moves through a long page by its headings; a Label
    /// drawn big is not one until this says so.
    public func accessibilityHeadingLevel(_ value: HeadingLevel) -> Modified { setValue(VisualElementContract.accessibilityHeadingLevel, value) }
}

// MARK: - What the platform reports

extension VisualElement {
    /// Whether the platform has given this control the focus, written into the
    /// binding. Read-only: the platform moves the focus.
    public func isFocused(_ binding: Binding<Bool>) -> Modified {
        onEvent(VisualElementContract.isFocusedChanged) { focused in
            binding.wrappedValue = focused
        }
    }

}

// MARK: - View

/// The properties every positioned view has: the value half of `View`, shared
/// by the control and its `Style`, including where it sits in a Grid or an
/// AbsoluteLayout.
public protocol ViewProperties: VisualElementProperties {}

/// A visual element a layout positions, with the gestures, the pan feeds,
/// the frame report and the context menu only a control can carry.
public protocol View: VisualElement, ViewProperties, Page {}

extension ViewProperties {
    /// The space kept outside the view, between it and its neighbours.
    /// Padding is the space inside.
    ///
    ///     Label("Total").margin(16)                      // all four sides
    ///     Label("Total").margin(Insets(16, 0, 0, 0))  // the left edge only
    public func margin(_ value: Insets) -> Modified { setValue(ViewContract.margin, value) }

    /// Left and right, then top and bottom.
    public func margin(_ horizontalSize: Double, _ verticalSize: Double) -> Modified {
        margin(Insets(horizontalSize, verticalSize))
    }

    /// Each side in turn: left, top, right, bottom.
    public func margin(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> Modified {
        margin(Insets(left, top, right, bottom))
    }

    /// How the view uses the width its parent offers - filling it, or sitting at
    /// one end of it.
    ///
    ///     Button("Save").horizontalAlignment(.center)
    public func horizontalAlignment(_ value: Alignment) -> Modified {
        setValue(ViewContract.horizontalAlignment, value)
    }

    /// The same, for the height.
    public func verticalAlignment(_ value: Alignment) -> Modified {
        setValue(ViewContract.verticalAlignment, value)
    }
}

extension View {
    /// A menu on the view itself, opened with a right-click.
    ///
    ///     Label(item.name)
    ///         .contextMenu {
    ///             MenuItem("Rename").onClicked { rename(item) }
    ///             MenuSeparator()
    ///             MenuItem("Delete").isDestructive(true).onClicked { remove(item) }
    ///         }
    ///
    /// The same entries a menu bar takes - `MenuItem`, `Menu`
    /// and `MenuSeparator` - attached to a view instead of to a page.
    ///
    /// Context menus are a desktop interaction. A host with no native context
    /// menu interaction leaves this modifier inert, so do not put the only way
    /// to perform an essential action behind it.
    ///
    /// - Parameter items: the entries, in the order they are shown.
    public func contextMenu(@MenuBuilder _ items: () -> [Element]) -> Modified {
        modified {
            // After the view's own children; the host finds it by type.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.append(Node(contract: ContextMenuContract.self, children: items().map { $0.body }))
        }
    }
}

// MARK: - Gestures
// Design: docs/design/views/modifiers.md#gestures

extension View {
    // MARK: Tap

    /// Runs when the view is tapped by the platform's native recognizer.
    ///
    ///     Border {
    ///         HStack { … }
    ///     }
    ///     .onTapped { path.append(.details(id)) }
    ///
    /// The whole view answers, not a button inside it.
    public func onTapped(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.tapped, handler)
    }

    /// The same, for a double tap or more: `count` taps in a row.
    ///
    ///     Label("Reset").onTapped(count: 2) { taps = 0 }
    public func onTapped(
        count: Int,
        _ handler: @escaping EventHandler
    ) -> Modified {
        // One `modified`: chaining would return `Modified.Modified`.
        modified {
            $0.write(ViewContract.tapCount, count)
            $0.addHandler(ViewContract.tapped.token, handler)
        }
    }

    // MARK: Swipe

    /// Runs when the view is swiped, with the one dominant direction it went.
    ///
    ///     Border { … }
    ///         .onSwiped(direction: [.left, .right]) { direction in
    ///             if direction == .left { items.removeLast() }
    ///         }
    ///
    /// - Parameters:
    ///   - direction: which ways to listen for. A view that listens for nothing
    ///     recognizes nothing, so the default is every direction.
    ///   - threshold: how far the finger must travel, in device units.
    public func onSwiped(
        direction: SwipeDirection = .all,
        threshold: Double? = nil,
        _ handler: @escaping ValueEventHandler<SwipeDirection>
    ) -> Modified {
        modified {
            $0.write(ViewContract.swipeDirection, direction)
            $0.describe(ViewContract.swipeThreshold, threshold)
            $0.addHandler(ViewContract.swiped.token) {
                // A payload that does not read leaves the handler alone.
                if let direction = SwipeDirection(EventBuffer.current.value()) {
                    try await handler(direction)
                }
            }
        }
    }

    // MARK: Pan

    /// Writes how far the view has been dragged across into a state, with no
    /// view rebuilt as it moves.
    ///
    ///     @State private var turn = 0.0
    ///
    ///     ColorBox(.transparent).panX($turn)
    ///
    /// The distance `onPanUpdated` reports, for an `.engine(following:)` to
    /// follow frame by frame. A drag moves the value on from where it stood, so
    /// a second drag carries on where the first left off.
    ///
    /// - Parameter value: the state the distance is written into.
    /// - Returns: the view, reporting there.
    public func panX(_ value: Binding<Double>) -> Modified {
        driven(ViewContract.panXChannel.token, by: value)
    }

    /// Writes how far the view has been dragged down into a state, with no view
    /// rebuilt as it moves; see `panX(_:)`.
    ///
    ///     ColorBox(.transparent).panY($turn)
    ///
    /// - Parameter value: the state the distance is written into.
    /// - Returns: the view, reporting there.
    public func panY(_ value: Binding<Double>) -> Modified {
        driven(ViewContract.panYChannel.token, by: value)
    }

    /// Runs as the view is dragged, from the moment it starts until it is let
    /// go.
    ///
    ///     ColorBox(.cornflowerBlue)
    ///         .translationX(offsetX)
    ///         .onPanUpdated { pan in
    ///             if pan.phase == .running { offsetX = pan.totalX }
    ///         }
    ///
    /// The totals are measured from where the pan began.
    ///
    /// - Parameter touchCount: how many simultaneous pointers the host must
    ///   require. A host that cannot distinguish that count does not recognize
    ///   the gesture when the requested count is unsupported.
    public func onPanUpdated(
        touchCount: Int? = nil,
        _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> Modified {
        modified {
            $0.describe(ViewContract.panTouchCount, touchCount)
            $0.addHandler(ViewContract.panUpdated.token) {
                if let (phase, totalX, totalY) = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.panUpdated.name,
                    as: GesturePhase.self, Double.self, Double.self) {
                    try await handler(PanUpdate(phase: phase, totalX: totalX, totalY: totalY))
                }
            }
        }
    }

    // MARK: Pinch

    /// Runs as two fingers move apart or together.
    ///
    /// `scale` is relative - the change since the last report, not since the
    /// pinch began - so a view being pinched multiplies rather than assigns.
    public func onPinchUpdated(_ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        onEvent(ViewContract.pinchUpdated) { phase, scale, origin in
            try await handler(PinchUpdate(phase: phase, scale: scale, scaleOrigin: origin))
        }
    }

    // MARK: Pointer

    /// Runs when a pointer enters the view.
    ///
    /// A pointer is a mouse, a trackpad or a pen; on a touch-only device these
    /// never fire.
    public func onPointerEntered(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerEntered, handler)
    }

    /// Runs when a pointer leaves the view - the other half of a hover.
    public func onPointerExited(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerExited, handler)
    }

    /// Runs as the pointer moves over the view, with where it is in the view's
    /// own coordinates; a move the platform gives no position for does not run
    /// it.
    public func onPointerMoved(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerMoved) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// Runs when a pointer button goes down over the view, with where it went
    /// down in the view's own coordinates.
    public func onPointerPressed(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerPressed) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// Runs when the pointer button comes back up, with where it came up.
    public func onPointerReleased(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerReleased) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    // MARK: Drag and drop

    /// Makes the view draggable, carrying `text` with it.
    ///
    ///     Label(item)
    ///         .draggable(text: item)
    ///
    /// Text is the portable drag payload. `onDragStarting` runs when the drag
    /// starts, too late to decide what is carried: a native drag needs its
    /// payload at once.
    public func draggable(
        text: String,
        canDrag: Bool = true,
        onDragStarting: EventHandler? = nil
    ) -> Modified {
        modified {
            $0.write(ViewContract.dragText, text)
            $0.write(ViewContract.canDrag, canDrag)

            if let onDragStarting = onDragStarting {
                $0.addHandler(ViewContract.dragStarting.token, onDragStarting)
            }
        }
    }

    /// Runs when a drag that started here ends, wherever it ended.
    public func onDropCompleted(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dropCompleted, handler)
    }

    /// Accepts what is dropped on the view, with the text it carried.
    ///
    ///     Border { … }
    ///         .onDrop { text in items.append(text) }
    public func onDrop(_ handler: @escaping ValueEventHandler<String>) -> Modified {
        modified {
            $0.write(ViewContract.allowDrop, true)
            $0.addHandler(ViewContract.drop.token) {
                if let text = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.drop.name, as: String.self) {
                    try await handler(text)
                }
            }
        }
    }

    /// Runs while a drag is over the view, before it is let go.
    public func onDragOver(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragOver, handler)
    }

    /// Runs when a drag leaves the view without being let go - the mirror of
    /// `onDragOver`, and where a highlight put up there is taken down.
    public func onDragLeave(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragLeave, handler)
    }
}

// MARK: - Where a view sits in a Grid
// Design: docs/design/views/modifiers.md#placement-is-written-on-the-child

extension ViewProperties {
    /// Which row of the enclosing Grid the view sits in, counting from 0.
    ///
    ///     Label("Name").gridRow(0).gridColumn(0)
    ///     TextField($name).gridRow(0).gridColumn(1)
    public func gridRow(_ value: Int) -> Modified { setValue(ViewContract.gridRow, value) }

    /// Which column of the enclosing Grid the view sits in, counting from 0.
    public func gridColumn(_ value: Int) -> Modified { setValue(ViewContract.gridColumn, value) }

    /// How many rows the view covers, starting at its own.
    public func gridRowSpan(_ value: Int) -> Modified { setValue(ViewContract.gridRowSpan, value) }

    /// How many columns the view covers, starting at its own.
    public func gridColumnSpan(_ value: Int) -> Modified { setValue(ViewContract.gridColumnSpan, value) }
}

// MARK: - Where a view sits in an AbsoluteLayout

extension ViewProperties {
    /// Where the view sits and how big it is.
    ///
    /// Read as device units unless the proportions say otherwise:
    ///
    ///     .absoluteLayoutBounds(Rect(0.5, 0, 0.5, 1))
    ///     .absoluteLayoutProportions(.all)
    public func absoluteLayoutBounds(_ value: Rect) -> Modified {
        setValue(ViewContract.absoluteLayoutBounds, value)
    }

    /// Which of those four numbers are fractions of the layout rather than
    /// device units.
    public func absoluteLayoutProportions(_ value: AbsoluteLayoutProportions) -> Modified {
        setValue(ViewContract.absoluteLayoutProportions, value)
    }
}

// MARK: - Layout

/// The properties every layout has, shared by the control and its `Style`.
public protocol LayoutProperties: ViewProperties {}

/// A view that arranges children.
public protocol Layout: View, LayoutProperties, PaddingElement {}

extension LayoutProperties {
    /// Whether a child drawn outside the layout's bounds is cut off at them.
    public func clipsContent(_ value: Bool) -> Modified {
        setValue(LayoutContract.clipsContent, value)
    }

    /// Whether the layout's own empty area lets input through to whatever is
    /// behind it, while its children still answer - an overlay whose buttons
    /// float over a page that stays in reach.
    ///
    ///     Grid { panel }.letsInputThrough(true)
    ///
    /// `.ignoresInput(true)` is the other half: the view and everything in it
    /// let input through. Where both are set, `ignoresInput` wins.
    public func letsInputThrough(_ value: Bool) -> Modified {
        setValue(LayoutContract.letsInputThrough, value)
    }

    /// Which parts of the screen's unsafe strip - the notch, the bars, the
    /// on-screen keyboard - this layout stays clear of, one value for all four
    /// edges.
    ///
    ///     VStack { … }.avoidsSafeArea(.none)    // edge to edge
    ///
    /// iOS is where it shows; the other platforms have no unsafe strip and
    /// ignore it. A layout that stays clear of the strip is inset by it, so a
    /// header meant to reach the top edge wants `.none`: its content then sits
    /// where its padding says, and its frame fits that content.
    public func avoidsSafeArea(_ value: SafeArea) -> Modified {
        setValue(LayoutContract.avoidsSafeArea, .uniform(value))
    }

    /// The same, said for the horizontal and the vertical edges separately.
    ///
    ///     Grid { … }.avoidsSafeArea(.none, .container)
    ///
    /// Left and right take the first, top and bottom the second.
    ///
    /// - Parameters:
    ///   - horizontal: what the left and right edges stay clear of.
    ///   - vertical: what the top and bottom edges stay clear of.
    public func avoidsSafeArea(
        _ horizontal: SafeArea,
        _ vertical: SafeArea
    ) -> Modified {
        avoidsSafeArea(horizontal, vertical, horizontal, vertical)
    }

    /// The same, one edge at a time: left, top, right, bottom.
    ///
    /// - Parameters:
    ///   - left: what the left edge stays clear of.
    ///   - top: what the top edge stays clear of.
    ///   - right: what the right edge stays clear of.
    ///   - bottom: what the bottom edge stays clear of.
    public func avoidsSafeArea(
        _ left: SafeArea,
        _ top: SafeArea,
        _ right: SafeArea,
        _ bottom: SafeArea
    ) -> Modified {
        setValue(LayoutContract.avoidsSafeArea, .edges(left: left, top: top, right: right, bottom: bottom))
    }
}

/// The properties every stack has, shared by the control and its `Style`.
public protocol StackBaseProperties: LayoutProperties {}

/// A layout that stacks its children in one direction.
public protocol StackBase: Layout, StackBaseProperties {}

extension StackBaseProperties {
    /// The gap left between children, in device units - not before the first
    /// or after the last, which is what padding is for.
    public func spacing(_ value: Double) -> Modified { setValue(StackBaseContract.spacing, value) }
}

// MARK: - Shape

/// The properties every shape has, shared by the control and its `Style`.
public protocol ShapeProperties: ViewProperties {}

/// A drawn outline.
public protocol Shape: View, ShapeProperties {}

extension ShapeProperties {
    /// A transform applied to the shape's geometry before it is drawn, in the
    /// shape's own units about its own origin; the stroke follows the
    /// transformed path, and a `skew` draws exactly.
    ///
    ///     Line().x2(56).y2(0)
    ///         .renderTransform(.rotate(15).scaleX(1.2))
    ///
    /// `.transform(_:)` instead moves what was drawn, about the view's centre.
    public func renderTransform(_ value: ViewTransform) -> Modified {
        setValue(ShapeContract.renderTransform, value)
    }

    /// What the inside of the shape is painted with.
    ///
    ///     Ellipse().fill(.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]))
    public func fill(_ value: Brush) -> Modified { setValue(ShapeContract.fill, value) }

    /// The same, in one colour - `.fill(.solidColor(colour))` said shortly.
    public func fill(_ value: Color) -> Modified { fill(.solidColor(value)) }

    /// What the outline is painted with.
    public func stroke(_ value: Brush) -> Modified { setValue(ShapeContract.stroke, value) }

    /// The same, in one colour.
    public func stroke(_ value: Color) -> Modified { stroke(.solidColor(value)) }

    /// How thick the outline is, in device units - 1 unless said. A thickness
    /// with no `.stroke` draws nothing.
    public func strokeWidth(_ value: Double) -> Modified {
        setValue(ShapeContract.strokeWidth, value)
    }

    /// The dashes and the gaps between them, in multiples of the stroke
    /// thickness.
    ///
    ///     Line().x2(240)
    ///         .stroke(.lightGray)
    ///         .strokeWidth(2)
    ///         .strokeDashPattern([4, 2])   // 8 units of dash, 4 of gap
    public func strokeDashPattern(_ value: [Double]) -> Modified {
        setValue(ShapeContract.strokeDashPattern, value)
    }

    /// How far into the dash pattern the line starts.
    public func strokeDashOffset(_ value: Double) -> Modified {
        setValue(ShapeContract.strokeDashOffset, value)
    }

    /// How the ends of an open line are drawn.
    public func strokeLineCap(_ value: LineCap) -> Modified {
        setValue(ShapeContract.strokeLineCap, value)
    }

    /// How two segments meet at a corner.
    public func strokeLineJoin(_ value: LineJoin) -> Modified {
        setValue(ShapeContract.strokeLineJoin, value)
    }

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke thickness.
    public func strokeMiterLimit(_ value: Double) -> Modified {
        setValue(ShapeContract.strokeMiterLimit, value)
    }

    /// What the shape does with the room it is given - the `Aspect` an Image
    /// takes too. `.fit`, the default, scales the drawing to fit and keeps its
    /// proportions; `.center` keeps the size its own numbers say.
    public func aspect(_ value: Aspect) -> Modified { setValue(ShapeContract.aspect, value) }
}

// MARK: - InputView

/// What `TextField`, `TextEditor` and `SearchField` share: the placeholder
/// and its colour, the keyboard, the caret and selection, the length cap and
/// read-only.
public protocol InputViewProperties: ViewProperties {}

/// A view the user types into.
public protocol InputView: View, InputViewProperties {}

extension InputView {
    /// Fires on every edit, with the whole of the new text. Runs after a
    /// binding's write, so the state already holds it.
    public func onTextChanged(_ handler: @escaping ValueEventHandler<String>) -> Modified {
        onEvent(InputViewContract.textChanged, handler)
    }
}

extension InputViewProperties {
    /// Where the caret sits, counted in characters from the start.
    ///
    /// Typing moves it by itself; write it to put the caret somewhere else,
    /// such as the end of text just filled in. A position past the end lands
    /// at the end.
    public func cursorPosition(_ value: Int) -> Modified {
        setValue(InputViewContract.cursorPosition, value)
    }

    /// How many characters from the caret are selected, 0 being none.
    ///
    ///     TextField($name).cursorPosition(0).selectionLength(name.count)
    ///
    /// selects the lot, for a field filled in for the user to replace.
    public func selectionLength(_ value: Int) -> Modified {
        setValue(InputViewContract.selectionLength, value)
    }

    /// Whether the platform underlines what it thinks is misspelt.
    ///
    /// Worth turning off for anything that is not prose - a code, a name, a
    /// serial number.
    public func isSpellCheckEnabled(_ value: Bool) -> Modified {
        setValue(InputViewContract.isSpellCheckEnabled, value)
    }

    /// Whether the platform offers the next word as the user types.
    ///
    /// Not the same as the spell check, and usually turned off with it and for
    /// the same fields.
    public func isTextPredictionEnabled(_ value: Bool) -> Modified {
        setValue(InputViewContract.isTextPredictionEnabled, value)
    }

    /// What the field says while it is empty.
    public func placeholder(_ value: String) -> Modified {
        setValue(InputViewContract.placeholder, value)
    }

    /// The colour of that text.
    public func placeholderColor(_ value: Color) -> Modified {
        setValue(InputViewContract.placeholderColor, value)
    }

    /// Whether the text can be selected and copied but not changed - which is
    /// not the same as disabled.
    public func isReadOnly(_ value: Bool) -> Modified {
        setValue(InputViewContract.isReadOnly, value)
    }

    /// What the field is for - an email address, a number, a url and the rest -
    /// which picks the keyboard the platform offers.
    public func inputPurpose(_ value: InputPurpose) -> Modified {
        setValue(InputViewContract.inputPurpose, value)
    }

    /// How many characters the field accepts.
    public func maximumLength(_ value: Int) -> Modified {
        setValue(InputViewContract.maximumLength, value)
    }
}

// MARK: - Composition

/// A view assembled from other views - how a piece of interface is factored
/// out and reused:
///
///     struct Header: ContentView {
///         private let title: String
///
///         init(_ title: String) {
///             self.title = title
///         }
///
///         var content: any View {
///             Label(title).fontSize(28).fontAttributes(.bold)
///         }
///     }
///
/// `content` is read the first time the view is built, and again when what it
/// was built with or a state it read changes; otherwise the view is carried
/// whole.
///
/// Configure it the way every control is: what it is goes in the initializer,
/// with no default, and what a caller may leave out is a modifier returning
/// `Self` that sets a `private` field. The modifiers every view has work on it
/// too, written after its own, since they return a `ModifiedContent`:
///
///     Header("Settings")
///         .margin(0, 8)
///         .gridRow(1)
public protocol ContentView: View where Modified == ModifiedContent {
    /// What this view is made of, read each time the view is built.
    var content: any View { get }
}

extension ContentView {
    // Design: docs/design/views/composition.md#a-composed-view-is-a-placeholder
    /// A placeholder for the content, which the differ builds once it knows
    /// whether this view stood here last render - so its `@State` is kept.
    public var body: Node {
        Node.composed(self, type: String(reflecting: Self.self)) { content.body }
    }

    /// A modifier written on a composed view, kept on a `ModifiedContent`
    /// wrapping the placeholder.
    public func modified(_ change: (inout Node) -> Void) -> ModifiedContent {
        var node = body
        change(&node)
        return ModifiedContent(node: node)
    }

    /// The placeholder, read afresh each time; assigning to it does nothing.
    public var node: Node {
        get { body }
        set {}
    }
}

/// A composed view with a modifier written on it. It offers what every view
/// has - margin, opacity, where it sits in a grid - and nothing that only
/// some views do.
public struct ModifiedContent: View {
    /// The content's node, with the change written into it.
    public var node: Node

    /// Wraps a node that a modifier has already been applied to. Made by
    /// `ContentView.modified`; there is rarely a reason to call this directly.
    public init(node: Node) {
        self.node = node
    }
}
