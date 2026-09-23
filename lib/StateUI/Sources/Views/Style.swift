// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Styles: what every control of a type looks like, resolved on this side
// before the patch. A style is written with a control's own modifiers and
// carries only its target's property half.
// Design: docs/design/views/styles.md#styles-are-resolved-before-the-patch

/// Property values for every control of a type.
///
///     Style<Button>()
///         .textColor(.white)
///         .background(AppColors.primary)
///         .cornerRadius(8)
///         .padding(14, 10)
///         .visualState(.disabled) { $0
///             .textColor(AppColors.gray950)
///             .background(AppColors.gray200)
///         }
///
/// A style takes the modifiers of its target's properties and nothing else:
/// an event, a gesture, an `.id()` or another control's property does not
/// compile. Write it as `Style<Button>`; `Context` keeps a visual state from
/// holding another.
public struct StyleBag<Target: StyleTarget, Context> {
    /// The setters written so far, on a node of the target's type.
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

/// The context of the style itself, where `visualState` and `basedOn` may be
/// written. See `StyleBag`.
public enum StyleBase {}

/// The context inside a `visualState` closure: the same property surface,
/// minus what only the style itself can carry - a state cannot hold a state.
public enum StyleState {}

/// A style, `Style<Button>()`: a `StyleBag` with its context filled in.
public typealias Style<Target: StyleTarget> = StyleBag<Target, StyleBase>

extension StyleBag: PropertyContainer {
    /// A style's modifiers give back the style, so the chain goes on offering
    /// what the target can carry.
    public typealias Modified = StyleBag<Target, Context>
}

extension StyleBag where Context == StyleBase {
    /// A style every control of the type gets.
    public init() {
        self.init(key: nil)
    }

    /// A style asked for by name - `.style("Headline")` on a control.
    public init(_ key: String) {
        self.init(key: key)
    }

    /// The style this one starts from, named by the key that style was given.
    ///
    /// The one it names must be in the same sheet. A key naming nothing is
    /// ignored, and a chain that comes back round to itself stops there.
    public func basedOn(_ key: String) -> Self {
        var copy = self
        copy.basedOn = key
        return copy
    }

    /// What changes while a control of this type is in a state.
    ///
    ///     Style<Button>()
    ///         .background(.cornflowerBlue)
    ///         .visualState(.disabled) { $0.background(.gray) }
    ///
    /// The closure's `$0` offers the style's own property modifiers.
    ///
    /// - Parameters:
    ///   - state: which state these setters describe. What is offered after
    ///     the dot is the states this target actually enters.
    ///   - group: which group of states the state belongs to. A control is in
    ///     one state per group and leaves a state only by entering another in
    ///     the SAME group, so states that exclude one another belong together.
    ///     Every group has a name and nearly everything is in `CommonStates`,
    ///     so that is the default.
    ///   - setters: the property values in force while the control is there.
    public func visualState(
        _ state: VisualState<Target>,
        group: String = "CommonStates",
        _ setters: (StyleBag<Target, StyleState>) -> StyleBag<Target, StyleState>
    ) -> Self {
        var copy = self

        copy.states = visualStates(
            copy.states,
            adding: visualStateSetting(
                setters(StyleBag<Target, StyleState>(key: nil)).node.props, named: state.name, in: group),
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
    ///   - group: which group of states it belongs to, `CommonStates` unless
    ///     said otherwise.
    public func visualState(_ state: VisualState<Target>, group: String = "CommonStates") -> Self {
        var copy = self

        copy.states = visualStates(
            copy.states,
            adding: emptyVisualState(named: state.name, in: group),
            resting: Target.restingVisualState.name)

        return copy
    }
}

extension StyleBag where Context == StyleBase {
    /// The style with its target forgotten, for a `StyleSheet`: the target's
    /// node type, its values and its states.
    var erased: AnyStyle {
        AnyStyle(
            target: node.type,
            key: key,
            basedOn: basedOn,
            props: node.props,
            states: states)
    }
}

/// A style whose target type has been forgotten - what a `StyleSheet`
/// collects, made from a `Style<Label>()` and never by hand.
public struct AnyStyle {
    /// The node type this style is for - the target's own.
    let target: NodeType

    /// The key it is asked for by, or nil for the one every control of the type
    /// gets.
    let key: String?

    /// The style it starts from, until the sheet flattens the chain.
    let basedOn: String?

    /// What it sets.
    var props: [Prop: PropValue]

    /// The states it declares, arranged, the resting one first.
    var states: [Node]
}
