// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Styles: what every control of a type looks like - resolved on THIS side.
//
// A MAUI Style is a bag of property values applied to every control of a type,
// and this library already writes those values one way: as modifiers. So a
// style is written with the same modifiers, chained on the style itself:
//
//     Style<Label>()
//         .textColor(AppColors.text)
//         .fontSize(14)
//
// The style conforms to the PROPERTY half of its target's tiers and to
// nothing else - see the split at the top of Elements.swift - so after the
// dot an author is offered exactly what a style can carry. A modifier the
// target does not have does not compile, and neither does anything that is
// not a property: `Style<Label>().onTapped { }` and `Style<Label>().id("x")`
// are refused at the keyboard, which is the rule this library is built to -
// what can be written is what is allowed.
//
// They live in a sheet the application declares. A style with no key applies to
// every control of its type; one with a key is asked for by name.
//
//     struct GalleryApp: Application {
//         var styles: StyleSheet? {
//             StyleSheet {
//                 Style<Label>().fontSize(14)                  // every Label
//                 Style<Label>("Headline").fontSize(32)        // by name
//             }
//         }
//     }
//
//     Label("Welcome").style("Headline")
//
// WHERE A STYLE IS APPLIED is the one thing here that is not MAUI's. Nothing
// about a style crosses the boundary: the differ merges it into the control it
// belongs to, so what the host receives is a control with every value already
// on it. There is no ResourceDictionary, no `Style` object, no StaticResource
// and nothing on the far side that has to know what a style is - which is what
// keeps the renderer small enough to be written again for another platform, and
// why the rules are stated here rather than inherited:
//
//   - A KEYED style replaces the implicit one for the type, and a value written
//     on the control beats both - one property at a time.
//   - A state written on the CONTROL is written over the state of the same name
//     in its style, one setter at a time. MAUI replaces the whole group list,
//     because a group list is one property; merging is the rule every other
//     value here already follows, and it is what lets a control hear a state
//     (`.onVisualStateChanged`) without losing the paint its style gave it.
//   - `basedOn` is flattened when the sheet is built, so a chain costs nothing
//     per control.
//
// See `StyleSheet` below for the resolution itself, and `Diff.element` for
// where it runs.

/// A control a style can be written for.
///
/// The requirement is an initializer that sets nothing - `new Label()` is
/// legal in MAUI for the same reason - and what the style takes from it is
/// the node TYPE, so the target is named once, by the control itself, rather
/// than spelled again as a string.
public protocol StyleTarget: VisualElement {
    /// A control with nothing set. Where a style reads its target's type.
    init()

    /// The state a control of this type RESTS in - and therefore the one a
    /// group of states that named none is given, so that it has somewhere to
    /// return to.
    ///
    /// It is `.normal` for everything but a RadioButton, and that exception is
    /// MAUI's doing rather than a choice made here - see the note on
    /// `VisualState.unchecked`. A control an application registers itself may
    /// say so too, if the C# behind it drives a state of its own.
    static var restingVisualState: VisualState<Self> { get }
}

extension StyleTarget {
    /// Where nearly everything rests: `VisualElement.ChangeVisualState` moves an
    /// enabled, unfocused, un-hovered control to Normal.
    public static var restingVisualState: VisualState<Self> { .normal }
}

/// One state a control can be in. MAUI: VisualState.
///
/// The names are MAUI's, spelled exactly as they are: the VisualStateManager
/// matches a state by its name, so unlike an enum value on the wire this is not
/// camelCased - "PointerOver" is the state, and "pointerOver" is nothing.
///
/// The TARGET is a phantom, and it is what makes the list after the dot the
/// states that control actually enters: `Style<Switch>().visualState(.on)`
/// compiles and `Style<Button>().visualState(.on)` does not, because nothing
/// ever moves a Button into On and a state nothing drives is a style that
/// silently does nothing. Which control drives which was measured against MAUI
/// itself - `MauiStatesTests` on the C# side is where that is pinned.
public struct VisualState<Target>: Equatable, Sendable {
    /// The name the VisualStateManager matches on, exactly as MAUI spells it.
    public let name: String

    /// A state MAUI has that this type does not name yet. Spell it as MAUI
    /// does: `VisualState("PointerOver")`, not "pointerOver".
    public init(_ name: String) {
        self.name = name
    }
}

/// The states every view has, `VisualElement.ChangeVisualState` being what
/// drives them.
extension VisualState where Target: VisualElement {
    /// The ordinary state - nothing pressed, focused or disabled. What a control
    /// returns to. MAUI: VisualStateManager.CommonStates.
    public static var normal: Self { Self("Normal") }

    /// While `isEnabled` is false.
    public static var disabled: Self { Self("Disabled") }

    /// While the control has the keyboard focus.
    public static var focused: Self { Self("Focused") }

    /// While the control does NOT have the keyboard focus.
    ///
    /// MAUI enters this straight AFTER Normal, so a group declaring both rests
    /// here rather than there - measured. That makes it a second spelling of
    /// Normal rather than the pair of `.focused`, and worth writing only where
    /// saying it twice says something.
    public static var unfocused: Self { Self("Unfocused") }

    /// While a mouse or pen is over the control. Never on a touch-only device.
    public static var pointerOver: Self { Self("PointerOver") }

    /// While the control is the chosen one.
    ///
    /// Nothing in `VisualElement` drives this: it is entered by whatever does
    /// the choosing - the flyout, which moves the row it is showing and
    /// everything in it, and MAUI's own indicator dots.
    public static var selected: Self { Self("Selected") }

}

/// A Button is held down. MAUI: `Button.ChangeVisualState`.
extension VisualState where Target == Button {
    /// While the button is held down. MAUI raises it from the platform, so this
    /// is a real press rather than a gesture recognized on this side.
    public static var pressed: Self { Self("Pressed") }
}

/// An ImageButton is held down - the same state, on the other button.
extension VisualState where Target == ImageButton {
    /// While the button is held down.
    public static var pressed: Self { Self("Pressed") }
}

/// A Switch says which way it is. MAUI: `Switch.ChangeVisualState`.
extension VisualState where Target == Switch {
    /// While `isToggled` is true.
    public static var on: Self { Self("On") }

    /// While `isToggled` is false.
    public static var off: Self { Self("Off") }
}

/// A CheckBox has ONE state of its own, and it is named for the property.
extension VisualState where Target == CheckBox {
    /// While `isChecked` is true. There is no unchecked state beside it: a
    /// CheckBox that is not checked is in `.normal`.
    public static var isChecked: Self { Self("IsChecked") }
}

/// A RadioButton has two, and neither is spelled the CheckBox's way.
extension VisualState where Target == RadioButton {
    /// While `isChecked` is true.
    public static var checked: Self { Self("Checked") }

    /// While `isChecked` is false, which is where a RadioButton RESTS.
    ///
    /// A RadioButton rests here rather than in `.normal`, and that is MAUI's
    /// doing rather than a choice made on this side.
    /// `RadioButton.ChangeVisualState` enters Checked or Unchecked FIRST and the
    /// ordinary Normal AFTER, so a group that declares Normal ends every
    /// transition there and the pair is never seen at all. It is the only
    /// control this way round - a Switch and a CheckBox call the base first, so
    /// their own states win over a Normal beside them. Measured;
    /// `MauiStatesTests` pins both halves.
    public static var unchecked: Self { Self("Unchecked") }
}

extension RadioButton {
    /// Unchecked, not Normal - see the note on `VisualState.unchecked`.
    public static var restingVisualState: VisualState<RadioButton> { .unchecked }
}

/// Property values for every control of a type. MAUI: Style.
///
///     Style<Button>()
///         .textColor(.white)
///         .backgroundColor(AppColors.primary)
///         .cornerRadius(8)
///         .padding(14, 10)
///         .visualState(.disabled) { $0
///             .textColor(AppColors.gray950)
///             .backgroundColor(AppColors.gray200)
///         }
///
/// The style itself takes the modifiers, and it conforms to the property half
/// of its target's tiers and to nothing else - so what can be written on one
/// is exactly what a style can carry. An event, a gesture, an `.id()` or
/// another control's property does not compile; the compiler is the check,
/// not the renderer.
///
/// `Style<Button>` is this type with its second parameter filled in. That
/// parameter is the CONTEXT - the style itself, or one of its states - a
/// phantom whose one job is to keep `visualState` from nesting: a state
/// cannot hold a state, and the constraint says so at the keyboard.
///
/// The target type is not written twice: it comes from the target's own blank
/// initializer, which is the same place its node type comes from.
public struct StyleBag<Target: StyleTarget, Context> {
    /// The setters written so far. The node's type is the TARGET's, so the
    /// one name travels from the control to the wire without being spelled
    /// again; its props are what the modifiers set.
    public var node: Node

    /// The key a keyed style is asked for by; nil for one every control of
    /// the type gets.
    var key: String?

    /// The key of the style this one starts from, flattened away when the
    /// sheet is built.
    var basedOn: String?

    /// The states written so far, arranged - the resting one first.
    var states: [Node] = []

    init(key: String?) {
        node = Node(type: Target().node.type)
        self.key = key
    }
}

/// The context of the style itself - where `visualState`, `basedOn` and
/// `applyToDerivedTypes` may be written. See `StyleBag`.
public enum StyleBase {}

/// The context inside a `visualState` closure: the same property surface,
/// minus what only the style itself can carry - a state cannot hold a state.
public enum StyleState {}

/// The public spelling of a style - `Style<Button>()` - with the context
/// filled in. Swift has no default generic arguments, and a typealias is how
/// the phantom stays out of every declaration.
public typealias Style<Target: StyleTarget> = StyleBag<Target, StyleBase>

extension StyleBag: PropertyContainer {
    /// A style's modifiers give back the style, so the chain goes on offering
    /// what the target can carry.
    public typealias Modified = StyleBag<Target, Context>
}

extension StyleBag where Context == StyleBase {
    /// A style every control of the type gets. MAUI: a Style with no `x:Key`.
    public init() {
        self.init(key: nil)
    }

    /// A style asked for by name. MAUI: `x:Key`, read back with
    /// `Style="{StaticResource …}"` - here, `.style("Headline")`.
    public init(_ key: String) {
        self.init(key: key)
    }

    /// The style this one starts from. MAUI: Style.BasedOn, which takes the
    /// style itself; here it is the key that style was given.
    ///
    /// The one it names must be in the same sheet - which is where the chain is
    /// flattened, once, so a style based on a style based on a style costs a
    /// control nothing. A key naming nothing is simply not started from, and a
    /// chain that comes back round to itself stops where it began.
    public func basedOn(_ key: String) -> Self {
        var copy = self
        copy.basedOn = key
        return copy
    }

    /// What changes while a control of this type is in a state.
    /// MAUI: a VisualState inside `VisualStateManager.VisualStateGroups`.
    ///
    ///     Style<Button>()
    ///         .backgroundColor(.cornflowerBlue)
    ///         .visualState(.disabled) { $0.backgroundColor(.gray) }
    ///
    /// The closure's `$0` is the same property surface the style has - and
    /// nothing more: a `visualState` inside a `visualState` does not compile,
    /// which is the phantom context doing its one job.
    ///
    /// - Parameters:
    ///   - state: which state these setters describe. What is offered after
    ///     the dot is the states this target actually enters.
    ///   - group: which VisualStateGroup the state belongs to. A control is in
    ///     one state per group and leaves a state only by entering another in
    ///     the SAME group, so states that exclude one another belong together.
    ///     MAUI requires a name and nearly everything is in `CommonStates`, so
    ///     that is the default.
    ///   - setters: the property values in force while the control is there.
    public func visualState(
        _ state: VisualState<Target>,
        group: String = "CommonStates",
        _ setters: (StyleBag<Target, StyleState>) -> StyleBag<Target, StyleState>
    ) -> Self {
        var copy = self

        copy.states = visualStates(
            copy.states,
            adding: Node(
                type: .visualState,
                props: [.name: .name(state.name), .group: .name(group)],
                children: [Node(
                    type: .setters,
                    props: setters(StyleBag<Target, StyleState>(key: nil)).node.props)]),
            resting: Target.restingVisualState.name)

        return copy
    }

    /// A state that changes nothing, which is how a control gets back to it.
    ///
    ///     Style<Button>()
    ///         .visualState(.normal)
    ///         .visualState(.disabled) { $0.textColor(.gray) }
    ///
    /// Worth writing where it says something - and not required, since a group
    /// that wrote none is given its target's resting state anyway.
    ///
    /// - Parameters:
    ///   - state: the state the control returns to, changing nothing.
    ///   - group: which VisualStateGroup it belongs to, `CommonStates` unless
    ///     said otherwise.
    public func visualState(_ state: VisualState<Target>, group: String = "CommonStates") -> Self {
        var copy = self

        copy.states = visualStates(
            copy.states,
            adding: Node(
                type: .visualState,
                props: [.name: .name(state.name), .group: .name(group)]),
            resting: Target.restingVisualState.name)

        return copy
    }
}

extension StyleBag where Context == StyleBase {
    /// The style with its target forgotten - what a `StyleSheet` files.
    ///
    /// A style is NOT an `Element`: it describes no part of the tree and never
    /// travels, so it has no body and no node type of its own. What survives
    /// the erasure is the target's node TYPE, which is what a control is
    /// matched against, and the states - already nodes, because those become
    /// the styled control's own children.
    var erased: AnyStyle {
        AnyStyle(
            target: node.type,
            key: key,
            basedOn: basedOn,
            props: node.props,
            states: states)
    }
}

/// The states of one target with `state` written into them: the ONE place a
/// list of states is arranged, so a style and a control put theirs in the same
/// shape.
///
/// Three rules, and each is there for a measured reason:
///
/// - A state REPLACES one of the same name in the same group, WHERE THE FIRST
///   ONE WAS. MAUI refuses two states of one name in one group, so the second
///   writing has to win rather than stand beside the first; it wins the values
///   and not the position, so writing order is what the list reads as.
/// - A group that names no resting state is given the TARGET's - an empty one,
///   changing nothing. A group is left by entering another state, so a group
///   whose only state is Disabled has no way back: the control is disabled once
///   and stays drawn that way for the rest of its life, with nothing anywhere
///   reporting it.
/// - And the resting state stands FIRST, because a group opens in the state it
///   declares first.
///
/// Which state is the resting one is the target's business, not always Normal:
/// see `StyleTarget.restingVisualState`, and the note on
/// `VisualState.unchecked`.
///
/// A state's name and its group are NAMES on the wire, not text: each repeats
/// on every state that shares it, and one spelling means one state wherever it
/// is written. So they are read back with `.name` here - `.string` would answer
/// nil for every one of them and leave every state matching every other.
func visualStates(_ existing: [Node], adding state: Node, resting: String) -> [Node] {
    let group = state.props[.group]?.name ?? ""
    let name = state.props[.name]?.name ?? ""

    var result = existing

    if let written = result.firstIndex(where: {
        $0.props[.group]?.name == group && $0.props[.name]?.name == name
    }) {
        result[written] = state
    } else {
        result.append(state)
    }

    guard let first = result.firstIndex(where: { $0.props[.group]?.name == group }) else {
        return result
    }

    guard let at = result.firstIndex(where: {
        $0.props[.group]?.name == group && $0.props[.name]?.name == resting
    }) else {
        result.insert(
            Node(type: .visualState,
                 props: [.name: .name(resting), .group: .name(group)]),
            at: first)

        return result
    }

    if at != first {
        result.insert(result.remove(at: at), at: first)
    }

    return result
}

extension VisualElement where Self: StyleTarget {
    /// What changes while THIS control is in a state - the same thing a style
    /// says, said about one control. MAUI: `VisualStateManager.VisualStateGroups`
    /// set on the control rather than through a Setter.
    ///
    ///     Button("Save")
    ///         .visualState(.disabled) { $0.textColor(Palette.disabled) }
    ///
    /// The closure's `$0` is the control's own property surface, exactly as a
    /// style's is - so what can be written in a state is what a style could
    /// carry, and the states offered after the dot are the ones this control
    /// actually enters.
    ///
    /// - Important: a state written here is written OVER the state of the same
    ///   name in the control's style, one setter at a time - so a control may
    ///   change what one state looks like and leave the rest of its style's
    ///   states exactly as they were. MAUI cannot do that, a group list being
    ///   one property; this side can, because the style is resolved here.
    /// - Parameters:
    ///   - state: which state these setters describe. What is offered after
    ///     the dot is the states this control actually enters.
    ///   - group: which VisualStateGroup the state belongs to. A control is in
    ///     one state per group and leaves a state only by entering another in
    ///     the SAME group, so states that exclude one another belong together.
    ///     MAUI requires a name and nearly everything is in `CommonStates`, so
    ///     that is the default.
    ///   - setters: the property values in force while the control is there.
    public func visualState(
        _ state: VisualState<Self>,
        group: String = "CommonStates",
        _ setters: (StyleBag<Self, StyleState>) -> StyleBag<Self, StyleState>
    ) -> Modified {
        visualState(Node(
            type: .visualState,
            props: [.name: .name(state.name), .group: .name(group)],
            children: [Node(
                type: .setters,
                props: setters(StyleBag<Self, StyleState>(key: nil)).node.props)]))
    }

    /// A state of this control's that changes nothing, which is how it gets back
    /// to it.
    ///
    ///     Button("Save")
    ///         .visualState(.normal)
    ///         .visualState(.pressed) { $0.opacity(0.6) }
    ///
    /// Worth writing where it says something - and not required, since a group
    /// that wrote none is given its control's resting state anyway.
    ///
    /// - Parameters:
    ///   - state: the state the control returns to, changing nothing.
    ///   - group: which VisualStateGroup it belongs to, `CommonStates` unless
    ///     said otherwise.
    public func visualState(
        _ state: VisualState<Self>,
        group: String = "CommonStates"
    ) -> Modified {
        visualState(Node(
            type: .visualState,
            props: [.name: .name(state.name), .group: .name(group)]))
    }

    /// Runs when this control ENTERS a state - which is what makes a state
    /// something that can be animated rather than only set.
    ///
    ///     @State private var lift = 1.0
    ///
    ///     Border { Label("Open") }
    ///         .scale($lift)
    ///         .onVisualStateChanged(.pointerOver, .normal) { state in
    ///             try await $lift.animateTo(state == .pointerOver ? 1.03 : 1, length: 120)
    ///         }
    ///
    /// A style's setters change instantly and there is nothing MAUI can do
    /// about that; a handler can take as long as it likes, so this is where a
    /// state becomes a transition.
    ///
    /// - Important: a control reports the states it DECLARES, and nothing else.
    ///   A VisualStateGroup announces what it entered in no other way - MAUI
    ///   gives `CurrentState` no event of its own - so the announcement is a
    ///   setter, and a setter has to sit in a state somebody wrote down. The
    ///   states named here are declared for you, in `CommonStates`, without
    ///   changing what the control looks like in them; states written with
    ///   `.visualState` are heard as they are, whatever group they are in.
    /// - Important: DECLARING a state can change which one the control rests in
    ///   - see `VisualState.unchecked` for the case where that bites. Name here
    ///   only the states this control is meant to react to.
    /// - Note: a control whose states come from a STYLE declares none of its
    ///   own, so name the ones to hear here as well - which costs nothing,
    ///   since a state named here is merged into its style's rather than
    ///   replacing it.
    /// - Parameter perform: labelled because Swift requires a label after a
    ///   variadic - written as a trailing closure it is never seen.
    public func onVisualStateChanged(
        _ states: VisualState<Self>...,
        perform handler: @escaping ValueEventHandler<VisualState<Self>>
    ) -> Modified {
        modified { node in
            for state in states {
                let already = node.children.contains {
                    $0.type == .visualState
                        && $0.props[.name]?.name == state.name
                        && $0.props[.group]?.name == "CommonStates"
                }

                guard !already else { continue }

                write(
                    Node(type: .visualState,
                         props: [.name: .name(state.name), .group: .name("CommonStates")]),
                    into: &node,
                    resting: Self.restingVisualState.name)
            }

            node.addHandler(.visualStateChanged) {
                // The name is what MAUI matches a state by, and what the report
                // carries. A payload of another shape leaves the handler alone,
                // the rule every typed event follows.
                //
                // `.string` and not `.name` on the way BACK: an event payload
                // is written without a dictionary, so what the host says a
                // state is called arrives as text however it went out.
                if let name = EventBuffer.current.value()?.string {
                    try await handler(VisualState<Self>(name))
                }
            }
        }
    }

    /// Writes one state into the control's own list of them.
    ///
    /// The states ride as CHILDREN of the control - the `.contextFlyout` shape,
    /// a modifier that writes a child rather than a property - appended after
    /// whatever the control lays out, which is where the renderer subtracts
    /// them.
    private func visualState(_ written: Node) -> Modified {
        modified { write(written, into: &$0, resting: Self.restingVisualState.name) }
    }
}

/// Puts one state among a control's own, keeping them arranged and leaving
/// whatever the control lays out exactly where it was.
func write(_ state: Node, into node: inout Node, resting: String) {
    node.states = true

    let laid = node.children.filter { $0.type != .visualState }

    node.children = laid + visualStates(
        node.children.filter { $0.type == .visualState },
        adding: state,
        resting: resting)
}

// MARK: - The sheet, and resolving against it

/// A style whose target type has been forgotten - what a `StyleSheet` collects.
///
/// Written as `Style<Label>()` and never by hand: the erasure happens where the
/// sheet's builder takes it, which is the last point at which there is anything
/// left to check.
public struct AnyStyle {
    /// The node type this style is for - the target's own, so the type is named
    /// once, by the control itself.
    let target: NodeType

    /// The key it is asked for by, or nil for the one every control of the type
    /// gets.
    let key: String?

    /// The style it starts from, until the sheet flattens the chain.
    let basedOn: String?

    /// What it sets.
    var props: [Prop: PropValue]

    /// The states it declares, arranged - the resting one first. These become
    /// the styled control's own `VisualState` children.
    var states: [Node]
}

/// Collects the styles written in a `StyleSheet`'s closure.
///
/// `if`, `else` and `for` all work here, which is what lets a sheet answer a
/// platform or an idiom. There is no identity to lose in a loop - a style is
/// filed by its target type or its key - so unlike a view builder this one
/// keeps `buildArray`.
@resultBuilder
public enum StyleBuilder {
    /// One style, whatever its target.
    public static func buildExpression<Target: StyleTarget>(_ style: Style<Target>) -> [AnyStyle] {
        [style.erased]
    }

    /// A group of them, already erased.
    public static func buildExpression(_ styles: [AnyStyle]) -> [AnyStyle] { styles }

    /// The statements of the closure, in order.
    public static func buildBlock(_ parts: [AnyStyle]...) -> [AnyStyle] { parts.flatMap { $0 } }

    /// An `if` with no `else`.
    public static func buildOptional(_ part: [AnyStyle]?) -> [AnyStyle] { part ?? [] }

    /// The `if` branch.
    public static func buildEither(first: [AnyStyle]) -> [AnyStyle] { first }

    /// The `else` branch.
    public static func buildEither(second: [AnyStyle]) -> [AnyStyle] { second }

    /// A `for` loop's turns.
    public static func buildArray(_ parts: [[AnyStyle]]) -> [AnyStyle] { parts.flatMap { $0 } }
}

/// The styles an application makes available. MAUI: ResourceDictionary.
///
/// Written on the Application, which is where MAUI keeps the ones that apply to
/// the whole app:
///
///     var styles: StyleSheet? {
///         StyleSheet {
///             Style<Label>().textColor(AppColors.text)
///             Style<Button>("Danger").backgroundColor(.firebrick)
///         }
///     }
///
/// It is read on every render, like everything else that describes the
/// interface, and it is a VALUE: two sheets saying the same thing are the same
/// sheet, so an application is free to build one on demand.
///
/// - Note: MAUI's own `StyleSheet` is its CSS one, which this library does not
///   surface. This is the sheet of `Style`s an application declares - what
///   `Application.Resources` holds in a MAUI app, minus everything a resource
///   dictionary can hold that is not a style, because nothing else is resolved
///   on this side.
public struct StyleSheet {
    /// Every style, in writing order, each with whatever it is based on already
    /// under it.
    ///
    /// The one storage: the two maps below are places IN it, not copies of it -
    /// which is also what lets a test see a style that was filed twice, where a
    /// dictionary would only ever show the winner.
    var written: [AnyStyle] = []

    /// Where the one every control of a type gets is.
    private var implicit: [NodeType: Int] = [:]

    /// Where the ones asked for by name are.
    private var keyed: [String: Int] = [:]

    /// The styles the closure describes, with every `basedOn` chain flattened.
    ///
    /// Two styles under one key, or two implicit ones for one target, are one:
    /// the LAST wins, as it does in a dictionary literal and in MAUI's own
    /// resource dictionary.
    public init(@StyleBuilder _ content: () -> [AnyStyle]) {
        written = content()

        for (index, style) in written.enumerated() {
            if let key = style.key {
                keyed[key] = index
            } else {
                implicit[style.target] = index
            }
        }

        // Flattened against what was WRITTEN, so a style may name one written
        // below it - the one thing this does that a XAML dictionary cannot,
        // where a StaticResource has to be declared first.
        let unflattened = written

        for index in written.indices {
            written[index] = StyleSheet.flatten(written[index], from: unflattened, keyed: keyed)
        }
    }

    /// One style with everything it is based on already under it.
    ///
    /// `chain` is what makes a cycle harmless: a style that comes back round to
    /// one already being flattened stops there, rather than looping forever
    /// over a mistake there is nowhere to report.
    private static func flatten(
        _ style: AnyStyle,
        from written: [AnyStyle],
        keyed: [String: Int],
        chain: Set<String> = []
    ) -> AnyStyle {
        guard let key = style.basedOn, !chain.contains(key), let at = keyed[key] else {
            return style
        }

        let base = StyleSheet.flatten(
            written[at], from: written, keyed: keyed, chain: chain.union([key]))

        var result = style
        result.props = base.props.merging(style.props) { _, mine in mine }
        result.states = merged(base.states, with: style.states)

        return result
    }

    /// The style a node wears: the one it asked for by name, or the one every
    /// control of its type gets.
    ///
    /// A key naming nothing falls through to the implicit style, which is what
    /// MAUI does too - an unresolved `Style` is no style, and no style is what
    /// makes an implicit one apply. A key naming a style declared for ANOTHER
    /// control falls through the same way: its values would be half applied
    /// and half dropped unread here, where MAUI refuses the TargetType
    /// mismatch out loud.
    func style(for node: Node) -> AnyStyle? {
        if let key = node.props[.style]?.name, let at = keyed[key],
           written[at].target == node.type {
            return written[at]
        }

        return implicit[node.type].map { written[$0] }
    }

    /// Whether two sheets say the same thing.
    ///
    /// Read once per render, by the differ, and only to decide whether a
    /// memoized subtree may still be skipped: an unchanged token says the
    /// INPUTS have not moved, and a sheet is not one of them. Hand-written
    /// because a state is a `Node`, which carries closures and cannot be
    /// Equatable - a state's props and its setters are all there is to compare.
    static func same(_ one: StyleSheet?, _ other: StyleSheet?) -> Bool {
        switch (one, other) {
        case (nil, nil): return true
        case (let one?, let other?): return same(one.written, other.written)
        default: return false
        }
    }

    private static func same(_ one: [AnyStyle], _ other: [AnyStyle]) -> Bool {
        one.count == other.count && zip(one, other).allSatisfy { mine, theirs in
            mine.target == theirs.target
                && mine.key == theirs.key
                && mine.props == theirs.props
                && same(mine.states, theirs.states)
        }
    }

    private static func same(_ one: [Node], _ other: [Node]) -> Bool {
        one.count == other.count && zip(one, other).allSatisfy { mine, theirs in
            mine.props == theirs.props && setters(of: mine) == setters(of: theirs)
        }
    }

    private static func setters(of state: Node) -> [Prop: PropValue] {
        state.children.first { $0.type == .setters }?.props ?? [:]
    }
}

/// The node as the host will see it: its style's values under its own, and the
/// states of both.
///
/// The ONE place a style is applied, called by `Diff.element` for every element
/// it builds - which is why it runs even with no sheet at all: `.style("…")` is
/// consumed here whatever happens, the host having no dictionary to look a key
/// up in.
func styled(_ node: Node, with sheet: StyleSheet?) -> Node {
    let style = sheet?.style(for: node)

    // Asked before it is written: assigning nil to a key a dictionary does not
    // have still makes the storage unique, so an unguarded removal would COPY
    // the props of every node in the tree, styled or not.
    guard style != nil || node.props[.style] != nil else { return node }

    var node = node
    node.props[.style] = nil

    guard let style = style else { return node }

    // The control's own values win, one property at a time - which is MAUI's
    // precedence and this library's everywhere else.
    if !style.props.isEmpty {
        node.props = style.props.merging(node.props) { _, own in own }
    }

    guard !style.states.isEmpty else { return node }

    // The states ride as slot children, appended after whatever the control
    // lays out - see `write(_:into:resting:)`, which puts the control's own
    // there in the same place.
    node.states = true

    let laid = node.children.filter { $0.type != .visualState }
    let own = node.children.filter { $0.type == .visualState }

    node.children = laid + merged(style.states, with: own)

    return node
}

/// The states of a control that also has a style: the style's, with the
/// control's written over them.
///
/// A state of the same name in the same group is OVERLAID rather than replaced,
/// so a control that declares `.pointerOver` only to hear it
/// (`.onVisualStateChanged`) keeps whatever its style paints there. MAUI cannot
/// do this - a group list is one property, so a control's replaces its style's
/// whole - and merging is what every other value on this side already does.
///
/// A state in a group the base does not have is appended, which is enough to
/// keep the arrangement: both lists arrive arranged, so each group's resting
/// state has already been put first among its own.
func merged(_ base: [Node], with own: [Node]) -> [Node] {
    guard !own.isEmpty else { return base }
    guard !base.isEmpty else { return own }

    var result = base

    for state in own {
        let group = state.props[.group]?.name
        let name = state.props[.name]?.name

        if let at = result.firstIndex(where: {
            $0.props[.group]?.name == group && $0.props[.name]?.name == name
        }) {
            result[at] = overlaid(result[at], with: state)
        } else {
            result.append(state)
        }
    }

    return result
}

/// One state written over another: its setters win, one property at a time.
///
/// A state that sets NOTHING changes nothing - which is what a state declared
/// only to be heard is, and the reason declaring one is safe.
private func overlaid(_ base: Node, with own: Node) -> Node {
    let mine = own.children.first { $0.type == .setters }?.props ?? [:]

    guard !mine.isEmpty else { return base }

    let theirs = base.children.first { $0.type == .setters }?.props ?? [:]

    var result = base
    result.children = [Node(type: .setters, props: theirs.merging(mine) { _, m in m })]

    return result
}

// MARK: - What a style may say
//
// The property half of the tiers, one line per tier: a `Style<Target>` offers
// a modifier exactly when the target's tier declares it, and the modifiers
// themselves are written ONCE, in Elements.swift, serving the control and the
// style alike. The element half - events, gestures, identity, lifecycle - is
// exactly what is missing from this list, and that absence is the feature.

extension StyleBag: VisualElementProperties {}
extension StyleBag: ViewProperties where Target: View {}
extension StyleBag: LayoutProperties where Target: Layout {}
extension StyleBag: StackBaseProperties where Target: StackBase {}
extension StyleBag: ShapeProperties where Target: Shape {}
extension StyleBag: PaddingElement where Target: PaddingElement {}
extension StyleBag: TextStyleElement where Target: TextStyleElement {}
extension StyleBag: TextElement where Target: TextElement {}
extension StyleBag: FontElement where Target: FontElement {}
extension StyleBag: TextAlignmentElement where Target: TextAlignmentElement {}
extension StyleBag: LineHeightElement where Target: LineHeightElement {}
extension StyleBag: DecorableTextElement where Target: DecorableTextElement {}
extension StyleBag: BorderElement where Target: BorderElement {}
extension StyleBag: ImageElement where Target: ImageElement {}
extension StyleBag: InputViewProperties where Target: InputView {}

// And each control's OWN property surface, one line per control - the
// protocol is declared beside the control, so this list only says "its style
// shares it".

extension StyleBag: ActivityIndicatorProperties where Target == ActivityIndicator {}
extension StyleBag: BorderProperties where Target == Border {}
extension StyleBag: BoxViewProperties where Target == BoxView {}
extension StyleBag: ButtonProperties where Target == Button {}
extension StyleBag: CheckBoxProperties where Target == CheckBox {}
extension StyleBag: DatePickerProperties where Target == DatePicker {}
extension StyleBag: EditorProperties where Target == Editor {}
extension StyleBag: EntryProperties where Target == Entry {}
extension StyleBag: FlexLayoutProperties where Target == FlexLayout {}
extension StyleBag: GraphicsViewProperties where Target == GraphicsView {}
extension StyleBag: GridProperties where Target == Grid {}
extension StyleBag: ImageProperties where Target == Image {}
extension StyleBag: ImageButtonProperties where Target == ImageButton {}
extension StyleBag: IndicatorViewProperties where Target == IndicatorView {}
extension StyleBag: LabelProperties where Target == Label {}
extension StyleBag: LineProperties where Target == Line {}
extension StyleBag: MapProperties where Target == Map {}
extension StyleBag: PathProperties where Target == Path {}
extension StyleBag: PickerProperties where Target == Picker {}
extension StyleBag: PolygonProperties where Target == Polygon {}
extension StyleBag: PolylineProperties where Target == Polyline {}
extension StyleBag: ProgressBarProperties where Target == ProgressBar {}
extension StyleBag: RadioButtonProperties where Target == RadioButton {}
extension StyleBag: RectangleProperties where Target == Rectangle {}
extension StyleBag: RefreshViewProperties where Target == RefreshView {}
extension StyleBag: RoundRectangleProperties where Target == RoundRectangle {}
extension StyleBag: ScrollViewProperties where Target == ScrollView {}
extension StyleBag: SearchBarProperties where Target == SearchBar {}
extension StyleBag: SliderProperties where Target == Slider {}
extension StyleBag: StepperProperties where Target == Stepper {}
extension StyleBag: SwipeViewProperties where Target == SwipeView {}
extension StyleBag: SwitchProperties where Target == Switch {}
extension StyleBag: TimePickerProperties where Target == TimePicker {}
extension StyleBag: TitleBarProperties where Target == TitleBar {}
extension StyleBag: WebViewProperties where Target == WebView {}

// MARK: - What can be styled
//
// Every control in Views/ - which is the rule, kept in one place so it can be
// read at a glance and so a test can insist on it. A style target is any control
// that can be made with nothing set, and each of these already could: the
// initializer that takes the value giving the control its purpose is one of
// several, never the only one.

extension Label: StyleTarget {}
extension Button: StyleTarget {}
extension Entry: StyleTarget {}
extension Editor: StyleTarget {}
extension Picker: StyleTarget {}
extension DatePicker: StyleTarget {}
extension TimePicker: StyleTarget {}
extension Switch: StyleTarget {}
extension CheckBox: StyleTarget {}
extension RadioButton: StyleTarget {}
extension Slider: StyleTarget {}
extension Stepper: StyleTarget {}
extension SearchBar: StyleTarget {}
extension ActivityIndicator: StyleTarget {}
extension ProgressBar: StyleTarget {}
extension Image: StyleTarget {}
extension ImageButton: StyleTarget {}
extension BoxView: StyleTarget {}
extension Border: StyleTarget {}
extension Grid: StyleTarget {}
extension ScrollView: StyleTarget {}
extension VerticalStackLayout: StyleTarget {}
extension HorizontalStackLayout: StyleTarget {}
extension AbsoluteLayout: StyleTarget {}
extension FlexLayout: StyleTarget {}
extension RefreshView: StyleTarget {}
extension SwipeView: StyleTarget {}
extension Rectangle: StyleTarget {}
extension RoundRectangle: StyleTarget {}
extension Ellipse: StyleTarget {}
extension Line: StyleTarget {}
extension Path: StyleTarget {}
extension Polygon: StyleTarget {}
extension Polyline: StyleTarget {}
extension GraphicsView: StyleTarget {}
extension IndicatorView: StyleTarget {}
extension WebView: StyleTarget {}
extension Map: StyleTarget {}
extension TitleBar: StyleTarget {}

// A SwipeItem is NOT one, and cannot be: MAUI's is a MenuItem rather than a
// View, so it has none of the properties a style would set and no VisualElement
// to hang one on. See Views/SwipeView.swift.
