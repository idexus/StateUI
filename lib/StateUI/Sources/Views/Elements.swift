// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The control hierarchy: the tiers a control's modifiers come from.
//
// Each property is declared ONCE, on the tier whose controls all carry it, and
// every control on that tier inherits it: opacity from
// `VisualElementProperties`, margin from `ViewProperties`, padding from
// `PaddingElement`, the font size from `FontElement`. So a modifier is
// available on exactly the controls that carry the property - `.spacing()` on
// a stack, `.placeholder()` on a TextField, and nothing on a Label that a Label
// does not carry.
//
// The hierarchy is TWO parallel halves, and the split is what makes "only what
// is allowed can be written" a compiler rule rather than a convention:
//
//     PropertyContainer            what holds property VALUES - controls and styles
//     ├── VisualElementProperties  opacity, isVisible, background, size…
//     │   └── ViewProperties       margin, options, grid and absolute placement
//     │       ├── LayoutProperties avoidsSafeArea
//     │       │   └── StackBaseProperties  spacing
//     │       └── ShapeProperties  fill, stroke…
//     └── the mixins, one file each, worn by whichever controls carry them:
//         TextStyleElement, TextElement, FontElement, TextAlignmentElement,
//         PaddingElement, LineHeightElement, DecorableTextElement,
//         BorderElement, BarElement, ImageElement, MenuItemElement
//
//     Element                      anything that can describe itself as a tree
//     └── ModifiableElement           a PropertyContainer IN the tree - events and lifetime live here
//         └── VisualElement        identity (.id), the read-only bindings
//             └── View             gestures, pan feeds, the frame report, the context menu
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

/// Anything carrying property values, whether or not it is drawn - a control,
/// a `Style`, a `TextSpan`.
///
/// It sits BELOW `VisualElement` because not everything that carries
/// properties is a view. A `TextSpan` - one run of text inside a Label -
/// carries a text colour, a font size and a background colour and is not a
/// view at all: no opacity, no margin, no size. So the text and font mixins,
/// `TextStyleElement` and `FontElement`, have to be wearable by something that
/// is not a `VisualElement`, and this is what they are written against.
public protocol PropertyContainer {
    /// What a modifier gives back.
    ///
    /// A control gives back ITSELF, so a chain goes on offering everything that
    /// control has: `Label("Hi").margin(8).lineBreak(.wordWrap)`. A style
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

    /// Drives one of this element's properties from a state the HOST moves,
    /// the state's value being the type the contract declares - what an
    /// application's own control is handed for a property its registration
    /// declares.
    ///
    /// Write it on the CONTROL, never on its `…Properties` protocol: a
    /// `StyleBag` wears those, and a style is driven by nothing.
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - state: the value the host carries it from - `$x` on a `@State` or
    ///     on a `@Binding`, whole. A PART of one, `$room.width`, has no image
    ///     of its own for the host to write into, and is refused with a word.
    ///   - mode: which way it crosses.
    ///   - kind: which of the host's doors the value goes through.
    /// - Returns: the element, with the registration on it.
    public func setValue<Owner: Contract, Value: HostRepresentable & StateValue>(
        _ property: ElementProperty<Owner, Value>,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        setValue(property.token, on: state, mode: mode, kind: kind)
    }

    /// The same, for a value the host WALKS - a number, a colour, a thickness,
    /// a point. Through the `.property` door the state is walked as a JOURNEY,
    /// so `$stars.journey.move(to: 5)` moves the member the way it moves a
    /// Border's opacity; through any other door - a feed, a plain value the
    /// control sets as it stands - the value crosses as itself. The compiler
    /// picks this one wherever the value can be walked.
    ///
    ///     func rating(_ state: Binding<Double>) -> Modified {
    ///         setValue(RatingBarContract.rating, on: state, mode: .inOut, kind: .property)
    ///     }
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - state: the whole state, `$x`.
    ///   - mode: which way it crosses.
    ///   - kind: which of the host's doors the value goes through.
    /// - Returns: the element, with the registration on it.
    public func setValue<Owner: Contract, Value: HostRepresentable & Walked>(
        _ property: ElementProperty<Owner, Value>,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        setValue(property.token, on: state, mode: mode, kind: kind)
    }

    /// Writes the NUMBER of a carried state onto a property, which is how a
    /// drag is told where to report - `panX`, `panY`.
    ///
    /// Taking the number asks the host to carry the state, and reads nothing
    /// at build - so the value the platform then writes into it, forty times
    /// a second under a finger, rebuilds nothing.
    ///
    /// - Parameters:
    ///   - property: which property carries the number.
    ///   - state: the state to report into.
    /// - Returns: the element, reporting there.
    func driven<Value: StateValue>(_ property: Prop, by state: Binding<Value>) -> Modified {
        guard let image = state.image else {
            complain("`\(property.name)` was told to report into a part of a state, or a "
                + "binding made from closures, which the host cannot carry. Report "
                + "into the whole state.")
            return modified { _ in }
        }

        return setValue(property, .number(Double(Renderer.shared.number(for: image))))
    }

    /// Drives a property from state the HOST moves, by its token - what the
    /// typed `setValue(_:on:mode:kind:)` and every driven modifier are written
    /// over.
    ///
    /// - Parameters:
    ///   - property: which property, by the token the host resolves it under.
    ///   - state: the value the host carries it from - `$x` on a `@State` or on
    ///     a `@Binding`, whole. A PART of one, `$room.width`, has no image of
    ///     its own for the host to write into, and the guard below refuses it.
    ///   - mode: which way it crosses.
    ///   - kind: which of the host's doors the value goes through.
    /// - Returns: the element, with the registration on it.
    func setValue<Value: StateValue>(
        _ property: Prop,
        on state: Binding<Value>,
        mode: StateMode,
        kind: StateKind
    ) -> Modified {
        // THE IMAGE, NEVER THE VALUE: taking `state.image` asks the host to
        // carry the state and reads nothing at build, which is the whole of
        // what keeps a value moving forty times a second from rebuilding the
        // view it is worn on. A part of a state has no image to hand.
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
                values: property.moving.union(Value.moving))
        }
    }

    /// The registration for a value the host WALKS, by its token: through the
    /// `.property` door the state is walked as a JOURNEY, through any other the
    /// value crosses as itself. What the typed `setValue(_:on:mode:kind:)` over
    /// a walked value is written over, picked by the compiler where the value
    /// can be walked.
    ///
    /// - Parameters:
    ///   - property: which property, by the token the host resolves it under.
    ///   - state: the whole state, `$x`. A part of one has no image to hand.
    ///   - mode: which way it crosses.
    ///   - kind: which of the host's doors the value goes through.
    /// - Returns: the element, with the registration on it.
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

    /// The same registration over an image already made - what a `Slider`
    /// and a `Stepper` write over a plain `Double`, which the host walks as a
    /// journey and which therefore wears a journey's lanes rather than the
    /// value's own.
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - image: the image the host carries the state on.
    ///   - mode: which way the value crosses.
    ///   - kind: which of the host's doors it goes through.
    ///   - moving: what the value is, for the law that answers it.
    /// - Returns: the element, wearing that property from the image.
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
                values: property.moving.union(moving))
        }
    }

    /// A property the host WALKS from a state - a number, a colour, a
    /// thickness, a point: the host walks the property there under the
    /// value's law, and the state goes on answering its plain type, a read
    /// being where the value is going and `$x.journey` where it is. What
    /// every binding twin of a value that travels is written over
    /// (Views/Bound.swift), a `Slider`'s thumb and a scroller's offset too.
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - state: the whole state, handed as `$x`.
    /// - Returns: the element, with the property walked from that state.
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

    /// A property the host SETS as the value stands - a flag, a count, a
    /// number that never travels - on its own frames, with nothing walking.
    /// `.inOut` where the control reports the value back: a switch flipped,
    /// a choice made, which then lands on the state as the host's own write.
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - state: the whole state, handed as `$x`.
    ///   - mode: `.out` unless the control reports it.
    /// - Returns: the element, with the property set from that state.
    func plain<Value: StateValue>(_ property: Prop, by state: Binding<Value>, mode: StateMode = .out) -> Modified {
        setValue(property, on: state, mode: mode, kind: .plain)
    }

    /// Words the host writes into a text property as the state changes - a
    /// placeholder, a title, a caption - the way a driven text is written.
    /// `.inOut` where the reader types into the property: what they type lands
    /// on the state, whole, as the host's own write.
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - state: the whole state, handed as `$x`.
    ///   - mode: `.out` unless the control reports it.
    /// - Returns: the element, with the words carried from that state.
    func words(_ property: Prop, by state: Binding<String>, mode: StateMode = .out) -> Modified {
        setValue(property, on: state, mode: mode, kind: .text)
    }

    /// A member the host WALKS from a state of the type its contract
    /// declares - `journey(_:by:)` over the member.
    func journey<Owner: Contract, Value: Walked & HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        by state: Binding<Value>
    ) -> Modified {
        journey(property.token, by: state)
    }

    /// A member the host SETS as the state of its declared type stands -
    /// `plain(_:by:mode:)` over the member.
    func plain<Owner: Contract, Value: StateValue & HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        by state: Binding<Value>,
        mode: StateMode = .out
    ) -> Modified {
        plain(property.token, by: state, mode: mode)
    }

    /// Words the host writes into a text member as the state changes -
    /// `words(_:by:mode:)` over the member.
    func words<Owner: Contract>(
        _ property: ElementProperty<Owner, String>,
        by state: Binding<String>,
        mode: StateMode = .out
    ) -> Modified {
        words(property.token, by: state, mode: mode)
    }
}

extension VisualElement {
    /// The DESCRIBED two-way form a control falls back to where the binding it
    /// was handed is a part of a state, or one made from closures - which the
    /// host cannot carry, and which the tree therefore shows: the value read
    /// at build, and every report written back through the binding. The
    /// closure that wrote it is a reader, and renders per report.
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - value: the binding shown and written back into.
    ///   - event: the event the control reports the value with.
    /// - Returns: the element, describing and reporting that value.
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
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - value: the binding shown and written back into.
    ///   - event: the event the control reports the value with.
    /// - Returns: the element, describing and reporting that value.
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
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - value: the binding shown and written back into.
    ///   - event: the event the control reports the text with.
    /// - Returns: the element, describing and reporting that text.
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
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - value: the binding shown and written back into.
    ///   - event: the event the control reports the day with.
    /// - Returns: the element, describing and reporting that day.
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
    ///
    /// - Parameters:
    ///   - property: which property.
    ///   - value: the binding shown and written back into.
    ///   - event: the event the control reports the time with.
    /// - Returns: the element, describing and reporting that time.
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
    /// test, a script or an agent driving the application asks the platform's
    /// own automation for, where the alternative is a coordinate read off a
    /// picture. What a READER is told is `.accessibilityLabel`.
    ///
    /// On this tier because a toolbar item and a menu entry carry one as much
    /// as a view does - so the button in a page's bar can be named. The three
    /// a screen reader hears are a view's alone and stay on
    /// `VisualElementProperties`.
    ///
    /// Keep it stable across renders and unique on the page: an id that moves
    /// with the state is an id nothing can wait for, and two things sharing
    /// one leave the driver to guess.
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

/// Anything carrying property values IN THE TREE, whether or not it is drawn.
///
/// A `PropertyContainer` that is also an `Element`: a control describes itself
/// in the tree, where a `Style` only carries values - which is why the events
/// are declared HERE and not one tier down. What can hold a handler is
/// something that exists on screen, never a bag of values.
public protocol ModifiableElement: PropertyContainer, Element where Modified: Element {}

/// A control backed by a node, and drawn.
public protocol VisualElement: ModifiableElement, VisualElementProperties {}

extension ModifiableElement {
    /// Hears one of this element's events that carries nothing.
    ///
    ///     onEvent(TrafficLightContract.closed) { shown = false }
    ///
    /// Beside whatever handler is there already, never instead of it. An event
    /// that arrives carrying anything is reported once and does not reach the
    /// handler: what arrives is what the contract says.
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
    /// Beside whatever handler is there already, never instead of it. What
    /// arrives is what the contract says or nothing: a payload with the value
    /// missing, one too many, or one of another kind is reported once and does
    /// not reach the handler.
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

    /// Adds a handler to an event that may already have one - the typed form
    /// every modifier in this library writes: `.textChanged`, never a
    /// spelling, Core/Tokens.swift being the one place the names exist.
    ///
    /// What a two-way binding leaves behind is a handler: `TextField($name)` writes
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

extension ModifiableElement where Modified == Self {
    /// The node this control describes - itself, since a control has one.
    public var body: Node { node }
}

// MARK: - VisualElement

/// The properties every drawn control has - the value half of
/// `VisualElement`, shared by the control and its `Style`. What is NOT here is
/// deliberate: identity and the read-only bindings live on `VisualElement`,
/// and an element's lifetime on `ModifiableElement`, where only a control can
/// reach them.
public protocol VisualElementProperties: PropertyContainer {}

extension VisualElement {
    /// How this view's values MOVE when they change.
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
    /// `application.motion`, in its session.
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
    /// what a navigation path's element, a tab and a modal's do too, so one
    /// value means one thing wherever identity is given:
    ///
    ///     Label(file.name).id(file)   // the item itself
    ///     Label(tab.title).id(tab)    // the same enum a TabbedView uses
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
    /// it travels as the element's identity, and the host finds and keeps the
    /// native control by it.
    ///
    /// - Parameter value: who this view is. Distinct among its siblings and
    ///   the same across renders - two views sharing one identity are two views
    ///   the differ cannot tell apart.
    public func id(_ value: some Hashable) -> Modified {
        modified { $0.id = String(describing: value) }
    }

    /// Puts an AIM on this control - how an ACT reaches it: the differ fills
    /// the aim with the element's own identity as it walks, so there is
    /// nothing to spell and nothing to collide. See Core/Aim.swift.
    ///
    ///     @Aim(TextField.self) private var field
    ///
    ///     TextField($address).aim(field)
    ///     Button("Edit").onClicked { try await field.focus() }
    ///
    /// **A model declares one the same way**, beside the state its page
    /// shows - the MODEL is what the view's `@State` keeps, and two models
    /// are two aims:
    ///
    ///     final class Form {
    ///         @State var address = ""
    ///
    ///         @Aim(TextField.self) var field
    ///     }
    ///
    /// Who the view is to an ACT, where `.id(_:)` is who it is to the differ -
    /// and NOT an identity: a view carrying only an aim is still matched by
    /// where it was written, so a collection's rows keep wanting `.id()`, and
    /// both compose, `.id("row-7").aim(row)` being a named row one act can
    /// also reach. Typed: an `Aim<Self>`, so the declaration and the view
    /// agree at compile time, and the aim offers exactly the acts this control
    /// has. On a COMPOSED view, write it directly on the initializer's result:
    /// the later links of a chain type as the wrapper the modifiers return,
    /// not as the view.
    ///
    /// - Parameter aim: the aim the control answers to.
    public func aim(_ aim: Aim<Self>) -> Modified {
        modified { $0.aim = aim.box }
    }

    /// READS WHERE A VALUE THE HOST IS MOVING HAS GOT TO, so many times a
    /// second, into a state of your own.
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
    /// **A STATE IS AT ITS VALUE THE MOMENT IT IS WRITTEN**, which is why this
    /// exists: `fade = 0.1` puts the destination on the state at once and the
    /// HOST walks the control there, so reading `fade` answers where it is
    /// GOING from the first frame to the last. Where it has GOT TO is the
    /// journey - `$fade.journey.value` - and reading THAT in a body is a build
    /// on every frame the value moves. This is the road between the two: some
    /// of those frames, into a state of its own.
    ///
    /// The sample is an ORDINARY state: writing it asks for a render and
    /// rebuilds the views that read it, under the ordinary rules. The source
    /// goes on standing at its destination and goes on costing nothing.
    ///
    /// **IT STOPS BY ITSELF.** A reading copies only what changed, so a value
    /// that has landed writes nothing and asks for nothing - and the host
    /// stops sending the moment the channel stops moving. The LAST frame of a
    /// walk is booked for the end of its window rather than dropped, so the
    /// sample ends where the value did.
    ///
    /// A value merely SHOWN wants a driven text instead
    /// (`Label($fade.journey.convert { … })`), which the host works out on its
    /// own frames and which costs no render at all. This is for one that
    /// decides WHICH VIEWS THERE ARE.
    ///
    /// Several views may read one source into several states at several rates:
    /// each reading is its own, with its own window, and none of them is a
    /// fact about the source. A binding that borrows no `@State` is not a
    /// value the host carries, has nothing to read, and says so.
    ///
    /// - Parameters:
    ///   - source: the value the host is moving, handed as `$x`.
    ///   - target: the state to read it into, handed as `$y`.
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
                // WHERE THE VALUE HAS GOT TO, off the lanes rather than through
                // the journey's own read: a reading is not a view depending on
                // the value, and one recorded mid-render would make whatever
                // element is being built a reader of a state it never
                // mentions.
                guard let now = from.journeyLanes?.value else { return }

                guard StateImage.bytes(of: now.carried)
                    != StateImage.bytes(of: into.value.carried) else { return }

                target.wrappedValue = now
            }))
        }
    }

    /// Provides an object to this view and everything under it, resolved by
    /// TYPE: any view below declaring `@Environment var context: MyContext`
    /// reads the nearest `MyContext` provided above it. A nearer
    /// `.environment()` of the same type overrides for its own branch.
    ///
    ///     @State var context = MyContext()   // a class of @State properties, usually
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
    public func style(_ key: String) -> Modified { setValue(VisualElementContract.style, Name(key)) }
}

extension VisualElementProperties {
    /// Whether the view is there at all.
    ///
    /// **SHOWING AND HIDING CROSSES.** This is a MOTION, not a flag that blinks
    /// a view in and out of existence: a view being hidden fades to nothing
    /// FIRST and goes when it gets there, and one being shown appears at
    /// nothing and comes up. Two views in one slot - a tab chosen, a panel
    /// swapped - therefore cross, which is the whole reason it works this way.
    ///
    /// The view stays in the tree the entire time and is hidden only once the
    /// fade lands; a view on its way out answers no touch, so a tap during the
    /// change reaches what is arriving. A view described for the FIRST time is
    /// simply there or not - nothing anybody saw is changing - and
    /// `.motion(.none)` puts the flag back to being a flag.
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

    /// What is drawn behind the view: a colour here, or a brush when one
    /// colour will not do. It is ONE property whichever it carries, and a
    /// view's own background replaces the one its style gives it.
    ///
    /// A `Color(light:dark:)` here carries both halves; the differ picks the
    /// one the theme asks for as it builds the view, so a theme change builds
    /// again exactly the views wearing a pair.
    public func background(_ value: Color) -> Modified { setValue(VisualElementContract.background, .color(value)) }

    /// What is drawn behind the view, when one colour will not do.
    ///
    ///     VStack { … }.background(.linearGradient([
    ///         GradientStop(.cornflowerBlue, 0),
    ///         GradientStop(.indigo, 1),
    ///     ]))
    ///
    /// The same property as a colour background: a view given both draws the
    /// one it was given last.
    public func background(_ value: Brush) -> Modified { setValue(VisualElementContract.background, .brush(value)) }

    /// How wide the view asks to be, in device units. A REQUEST: the layout has
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

    /// How this view is moved, turned and sized - ONE transform, about the
    /// view's own centre, and the same picture on every platform.
    ///
    ///     Card(item).transform(.rotate(14).scale(0.9).translate(100, 200))
    ///
    /// The parts happen in the ORDER they are written, each to what the parts
    /// before it made - a move written before a turn is swung round by it, one
    /// written after is not. See `ViewTransform` for what each part means, the
    /// one chain the five properties cannot carry whole, and why `turn` is not
    /// `.rotationY`.
    ///
    /// It writes `translationX`, `translationY`, `rotation`, `scaleX` and
    /// `scaleY` - so those five are this modifier's to say, and a view uses
    /// one or the other rather than both.
    ///
    /// - Parameter transform: how the view is moved, turned and sized. It is a
    ///   VALUE, so it can be worked out somewhere else, held in `@State` and
    ///   handed here.
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
    /// The trap: a turn OUT of the screen's plane is projected through a
    /// camera each platform chooses for itself, so the same number is not the
    /// same picture everywhere - measured on one run of cards at one angle,
    /// Apple turned them away where Android drew them tilted in the plane and
    /// moved as well. A turn that must look alike on every platform is written
    /// as what a turned rectangle LOOKS like: a `scaleX` of `cos(angle)`.
    public func rotationX(_ value: Double) -> Modified { setValue(VisualElementContract.rotationX, value) }

    /// Turns the view about its vertical axis, in degrees - one side going away
    /// as the other comes forward.
    ///
    /// The trap: a turn OUT of the screen's plane is projected through a
    /// camera each platform chooses for itself, so the same number is not the
    /// same picture everywhere. A turn that must look alike on every platform
    /// is written as what a turned rectangle LOOKS like: a `scaleX` of
    /// `cos(angle)`.
    public func rotationY(_ value: Double) -> Modified { setValue(VisualElementContract.rotationY, value) }

    /// Resizes the view about its pivot, 1 being its natural size. Drawing
    /// only - the space the layout gave it does not change.
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
    //
    // Everything above decides what is DRAWN. These four decide what the view
    // is to somebody not looking at it: a reader using a screen reader, and a
    // test, a script or an agent driving the application from outside.
    //
    // They are two different jobs and they do not stand in for one another.
    // `.accessibilityIdentifier` is a handle nothing reads out; the other three are read
    // out and are no use to a driver, a description being prose that changes
    // with the language the reader chose.

    /// What a screen reader says this view IS.
    ///
    ///     Button(icon: "bin.png").accessibilityLabel("Delete")
    ///
    /// A control whose meaning is carried by a picture, a colour or where it
    /// sits says nothing at all to a reader who cannot see it, and this is what
    /// it says instead. A control that shows its own words is already read from
    /// those, so a description written on one REPLACES them rather than adding
    /// to them - which is why the ones worth writing are on the controls that
    /// have no words of their own.
    public func accessibilityLabel(_ value: String) -> Modified { setValue(VisualElementContract.accessibilityLabel, value) }

    /// What a screen reader says will HAPPEN, after it has said what the view is.
    ///
    ///     Switch($lit)
    ///         .accessibilityLabel("Ceiling light")
    ///         .accessibilityHint("Turns the light on and off")
    ///
    /// The description names the control and this says what using it does, so
    /// a hint on a view nobody can act on is a sentence read out for nothing.
    public func accessibilityHint(_ value: String) -> Modified { setValue(VisualElementContract.accessibilityHint, value) }

    /// Whether a screen reader skips this view.
    ///
    ///     ColorBox(.silver).isAccessibilityHidden(true)
    ///
    /// Decoration is what this is for: a rule, a shadow, a picture that repeats
    /// what the words beside it already say. A reader moves through a page one
    /// thing at a time, so a view that says nothing is a stop that wastes their
    /// time - and hiding it is how it stops being one.
    ///
    /// Left unsaid the platform decides, which is the right answer nearly
    /// always: a view with words is reachable and a plain container is not.
    /// Say `false` where a platform has left something out, and never hide a
    /// view the reader has to be able to act on.
    public func isAccessibilityHidden(_ value: Bool) -> Modified { setValue(VisualElementContract.isAccessibilityHidden, value) }

    /// Whether taking this view out takes everything inside it too.
    ///
    ///     VStack { … }.automationExcludedWithChildren(true)
    ///
    /// The one above hides the view; this hides the SUBTREE, which is what a
    /// panel that is on screen but not the reader's business wants - a
    /// decorative header, a card standing behind the one in front. Written on
    /// a container, so one word covers what would otherwise be a word on every
    /// view in it.
    public func automationExcludedWithChildren(_ value: Bool) -> Modified { setValue(VisualElementContract.automationExcludedWithChildren, value) }

    /// That this view is a HEADING, and how deep.
    ///
    ///     Label("Settings").fontSize(24).accessibilityHeadingLevel(.level1)
    ///
    /// A reader who cannot see the page moves through it by its headings, which
    /// is what makes a long page navigable at all. Drawing a Label big says
    /// nothing about that: a heading is what this says it is.
    public func accessibilityHeadingLevel(_ value: HeadingLevel) -> Modified { setValue(VisualElementContract.accessibilityHeadingLevel, value) }
}

// MARK: - What the control knows and this side does not
//
// Everything above is written TO a control. These read FROM one: properties
// the platform changes by itself - the size a layout settled on, the focus it
// moved - which no event on this side could have predicted.
//
// A binding is the whole API: give it one and it is kept in step.
//
//     TextField($name).isFocused($editing)
//
// Nothing is watched until it is asked for. A size changes at every measure,
// and a subscription per control would cost real work for an answer nobody
// wanted.

extension VisualElement {
    /// Whether the platform has given this control the focus. Read-only - the
    /// platform moves the focus - so this only writes INTO the binding.
    public func isFocused(_ binding: Binding<Bool>) -> Modified {
        onEvent(VisualElementContract.isFocusedChanged) { focused in
            binding.wrappedValue = focused
        }
    }

}

// MARK: - View

/// The properties every positioned view has - the value half of `View`,
/// shared by the control and its `Style`. Where a view sits in a parent Grid
/// or AbsoluteLayout is here too, being a property: where a view sits in a
/// grid is as styleable as its margin.
public protocol ViewProperties: VisualElementProperties {}

/// A VisualElement a layout positions. What this tier ADDS to the
/// property half is what only a control can carry: the gestures, the two pan
/// feeds, the frame report, and the context menu.
public protocol View: VisualElement, ViewProperties, Page {}

extension ViewProperties {
    /// The space kept OUTSIDE the view, between it and its neighbours.
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
            // Appended, so the view's own children keep the positions the differ
            // gave them. The host reads it by TYPE and leaves it out of the
            // arrangement.
            $0.children.append(Node(contract: ContextMenuContract.self, children: items().map { $0.body }))
        }
    }
}

// MARK: - Gestures
//
// Gestures belong to every view, so a Border holding a whole row, an Image or
// a Label can answer one. A list row can therefore be a view with a tap
// recognizer rather than a button disguised as a container.
//
// StateUI describes tap, swipe, pan, pinch, pointer, drag and drop. Each is
// added to the view when the tree first carries a handler for it and kept for
// as long as it does, the same way a control's own events are subscribed once
// - so a re-render can change
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

    /// Runs when the view is tapped by the platform's native recognizer.
    ///
    ///     Border {
    ///         HStack { … }
    ///     }
    ///     .onTapped { path.append(.details(id)) }
    ///
    /// The whole view answers, not a button inside it - which is the difference
    /// between a row you can tap and a row with something tappable in it.
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
        // Both changes in one `modified`, because chaining would return
        // `Modified.Modified` and nothing here can promise that is `Modified`.
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

    /// Writes how far the view has been dragged ACROSS into a driven state, which
    /// describes nothing again.
    ///
    ///     @State private var turn = 0.0
    ///
    ///     ColorBox(.transparent).panX($turn)
    ///
    /// The same distance `onPanUpdated` reports, taken off the path that
    /// builds the interface: nothing is described when it moves, and what
    /// follows it - a `.engine(following:)` - is put where its
    /// arithmetic now says. So a run of views can be TAKEN HOLD OF and moved,
    /// frame by frame, with no view built and no message sent.
    ///
    /// A drag MOVES the value on from where it stood rather than setting it,
    /// so a second drag carries on where the first left the run rather than
    /// starting it over.
    ///
    /// - Parameter value: the driven state the distance is written into.
    /// - Returns: the view, reporting there.
    public func panX(_ value: Binding<Double>) -> Modified {
        driven(ViewContract.panXChannel.token, by: value)
    }

    /// Writes how far the view has been dragged DOWN into a driven state, which
    /// describes nothing again.
    ///
    ///     ColorBox(.transparent).panY($turn)
    ///
    /// See `panX(_:)` for what that means and what it costs.
    ///
    /// - Parameter value: the driven state the distance is written into.
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
    /// The totals are measured from where the pan began, which is what makes
    /// moving a view a matter of assigning them to its translation.
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
    /// `scale` is RELATIVE - how much has changed since the last report, not
    /// since the pinch began - so a view being pinched multiplies rather than
    /// assigns.
    public func onPinchUpdated(_ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        onEvent(ViewContract.pinchUpdated) { phase, scale, origin in
            try await handler(PinchUpdate(phase: phase, scale: scale, scaleOrigin: origin))
        }
    }

    // MARK: Pointer

    /// Runs when a pointer enters the view.
    ///
    /// A pointer is a mouse, a trackpad or a pen - so these are the desktop
    /// gestures, and on a touch-only device they never fire.
    public func onPointerEntered(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerEntered, handler)
    }

    /// Runs when a pointer leaves the view - the other half of a hover.
    public func onPointerExited(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerExited, handler)
    }

    /// Runs as the pointer moves over the view, with where it is in the view's
    /// own coordinates - where the platform says where; a move it gives no
    /// position for does not run it.
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
    /// Text is StateUI's portable drag payload. The handler, if there is one,
    /// runs when the drag starts; it cannot decide what is carried because a
    /// native drag session needs its payload synchronously.
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
//
// A grid's placement is written on the CHILD: the grid asks, the child
// answers. So these live on View, where any view that might find itself in a
// grid can reach them, and they carry the grid's name - `.gridRow()`, never
// `.row()` - which says which layout is asking.
//
// A view that says nothing sits at row 0, column 0, spanning one of each.

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
//
// The same as a Grid's, and the one place the prefix rule gives ground. The
// layout's name followed by the property's would be
// `absoluteLayoutLayoutBounds`, and repeating it buys nothing - `Layout` twice
// says no more than `Layout` once, and there is no second `Bounds` on an
// AbsoluteLayout to tell it apart from - while it costs an author a name
// nobody types right first time.
//
// So the doubled word goes and nothing else does: `.absoluteLayoutBounds` and
// `.absoluteLayoutProportions`, keeping the prefix that says which layout is asking.
//
// The wire says the same thing, so there is one name from the modifier to the
// host's table rather than a mapping in between.

extension ViewProperties {
    /// Where the view sits and how big it is.
    ///
    /// Read as device units unless the flags say otherwise, which is what makes
    /// the two go together:
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
    ///
    /// The trap is that this is about the LAYOUT's edges, while `.clip` on any
    /// view is about a shape given to that view.
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

    /// Which parts of the screen's UNSAFE strip - the notch, the bars, the
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
    /// Written out to all four edges before it travels - left and right from
    /// the first, top and bottom from the second - so the wire carries the one
    /// shape a `SafeAreaEdges` is and the host has a single thing to read
    /// rather than three spellings of it.
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
    /// The four regions travel as MEMBERS, in that order - each one a value of
    /// its own rather than a run of numbers, a member and a quantity being
    /// different things on this wire. The one-value form sends the same
    /// member once, as a single `.enumeration`.
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
    /// The gap left BETWEEN children, in device units - not before the first or
    /// after the last, which is what padding is for.
    public func spacing(_ value: Double) -> Modified { setValue(StackBaseContract.spacing, value) }
}

// MARK: - Shape
//
// Rectangle, Ellipse, Line, Path, Polygon and Polyline share
// one drawing vocabulary. It is a tier here exactly as the font properties are,
// and is checked once by the Elements fixture rather than once per shape.

/// The properties every shape has, shared by the control and its `Style`.
public protocol ShapeProperties: ViewProperties {}

/// A drawn outline.
public protocol Shape: View, ShapeProperties {}

extension ShapeProperties {
    /// A transform applied to the GEOMETRY before it is drawn - the same
    /// `ViewTransform` every view takes, whole: the shape is redrawn from the
    /// transformed path, so a lean (`skew`) and every chain draw exactly, and
    /// the stroke follows the shape it makes. In the shape's own units, about
    /// its own origin. The host transforms the path each shape makes, so one
    /// modifier means one thing on all of them.
    ///
    ///     Line().x2(56).y2(0)
    ///         .renderTransform(.rotate(15).scaleX(1.2))
    ///
    /// Not the same as `.transform(_:)`, which every view has: that one moves
    /// what was DRAWN, about the view's centre, after the layout has placed
    /// it.
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

    /// How thick the outline is, in device units. The default is one, so a
    /// `.stroke()` on its own draws a one-unit line,
    /// and a thickness on its own draws nothing, there being no stroke to draw
    /// it with.
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

/// What TextField, TextEditor and SearchField share: the hint, its colour, the
/// keyboard, the length cap and read-only. Declared once here, so the three
/// fields carry one definition of each rather than a copy apiece.
///
/// `ViewProperties` rather than `VisualElementProperties`, because this tier
/// stands for a KIND of control - a positioned view the reader types into -
/// and so sits where a view sits. It is the mixins - `PaddingElement`,
/// `TextAlignmentElement` - that stop at `VisualElementProperties`: each names
/// a set of properties rather than a kind of control, and asks for nothing a
/// positioned view adds.
public protocol InputViewProperties: ViewProperties {}

/// A View the reader types into.
///
/// The element half of the tier, the way `Layout` and `Shape` are the element
/// halves of theirs - and it is what a `Style<TextField>` is told apart BY: the
/// conditional conformances in Style.swift name the element protocol, so a
/// tier with only a property half cannot be given to a style without giving it
/// `View`'s modifiers by accident.
public protocol InputView: View, InputViewProperties {}

extension InputView {
    /// Fires on every edit, with the whole of the new text - not the character
    /// that arrived.
    ///
    /// Runs after a binding's write, if there is one, so the state already
    /// holds what the payload carries.
    public func onTextChanged(_ handler: @escaping ValueEventHandler<String>) -> Modified {
        onEvent(InputViewContract.textChanged, handler)
    }
}

extension InputViewProperties {
    /// Where the caret sits, counted in characters from the start.
    ///
    /// A field the reader is typing in moves this by itself, so writing it is
    /// for putting the caret somewhere the reader did not - the end of text
    /// just filled in, say. It is CLAMPED to the text, so a position past the
    /// end lands at the end.
    public func cursorPosition(_ value: Int) -> Modified {
        setValue(InputViewContract.cursorPosition, value)
    }

    /// How many characters from the caret are selected, 0 being none.
    ///
    ///     TextField($name).cursorPosition(0).selectionLength(name.count)
    ///
    /// selects the lot, which is what a field wants when it is filled in for
    /// the reader to replace.
    public func selectionLength(_ value: Int) -> Modified {
        setValue(InputViewContract.selectionLength, value)
    }

    /// Whether the platform underlines what it thinks is misspelt.
    ///
    /// Worth turning off for anything that is not prose - a code, a name, a
    /// serial number - where the underline says nothing and the platform's
    /// corrections get in the way.
    public func isSpellCheckEnabled(_ value: Bool) -> Modified {
        setValue(InputViewContract.isSpellCheckEnabled, value)
    }

    /// Whether the platform offers the next word as the reader types.
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

/// A view assembled from other views.
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
///         var content: any View {
///             Label(title).fontSize(28).fontAttributes(.bold)
///         }
///     }
///
/// `content` is read whenever the view is built - the first time, and again
/// when what it was built with or a state it read changes; otherwise the view
/// is carried whole.
///
/// It is configured the way every control is: WHAT IT IS goes in the
/// initializer and has no default, and everything a caller may leave out is a
/// MODIFIER returning `Self` - one copy, one assignment into a `private` field,
/// which is what keeps the memberwise initializer from being a second way in.
/// `GalleryView.position` follows that rule. An optional purpose value is a
/// SECOND initializer delegating to the first, never a defaulted parameter.
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
    /// What this view is made of, read each time the view is built.
    var content: any View { get }
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
    /// comes from PropertyContainer, where a control or a style really does
    /// have a node of its own to keep.
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
/// It offers what every view has - margin, opacity, where it sits in a grid
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
