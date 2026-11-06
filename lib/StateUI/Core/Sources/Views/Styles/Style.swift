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
///         .shape(.roundedRectangle(8))
///         .padding(horizontal: 14, vertical: 10)
///         .visualState(.disabled) { $0
///             .textColor(AppColors.gray950)
///             .background(AppColors.gray200)
///         }
///
/// A style takes the modifiers of its target's properties and nothing else:
/// an event, a gesture, an `.id()` or another control's property does not
/// compile. Write it as `Style<Button>`; its `Scope` keeps a visual state from
/// holding another.
@MainActor
public struct Styling<Target: StyleTarget, Scope> {
    /// The setters written so far, on a node of the target's type.
    public var node: Node

    /// The key a keyed style is asked for by; nil for one every control of
    /// the type gets.
    var key: String?

    /// The key of the style this one starts from, flattened away when the
    /// sheet is built.
    var basedOn: String?

    /// The value of the target's member this style is worn for - a button's role, a picker's presentation - over the
    /// one every control of the type gets; nil for any other style.
    var variant: StyleVariant?

    /// The states written so far, in writing order.
    var states: [DeclaredState] = []

    init(key: String?) {
        node = Node(type: Target.nodeType)
        self.key = key
    }
}

/// Where a style's setters stand - the scope a `Styling` is written in.
public enum StyleScope {
    /// The style itself, where `visualState` and `basedOn` may be written.
    public enum Whole {}

    /// Inside a `visualState` closure: the same property surface, minus what only the style itself can carry - a
    /// state cannot hold a state.
    public enum VisualState {}
}

/// A style, `Style<Button>()`: the styling of every control of a type, in the scope of the whole style.
public typealias Style<Target: StyleTarget> = Styling<Target, StyleScope.Whole>

extension Styling: PropertyContainer {
    /// A style's modifiers give back the style, so the chain goes on offering
    /// what the target can carry.
    public typealias Modified = Styling<Target, Scope>
}

extension Styling where Scope == StyleScope.Whole {
    /// A style every control of the type gets.
    public init() {
        self.init(key: nil)
    }

    /// A style asked for by its key - `.style(.headline)` on a control.
    public init(_ key: StyleKey<Target>) {
        self.init(key: key.name)
    }
}

extension Styling where Scope == StyleScope.Whole, Target == Button {
    /// A style every button of `role` gets, standing over the one every button gets: it says only what the role
    /// changes. A button asking for a style by its key, or for the platform's own look, wears none of it.
    ///
    ///     Style<Button>().background(AppColors.accent)
    ///     Style<Button>(role: .destructive).background(AppColors.danger)
    public init(role: ButtonRole) {
        self.init(key: nil)
        variant = StyleVariant(ButtonContract.role, role, unsaid: .normal)
    }
}

extension Styling where Scope == StyleScope.Whole, Target == Picker {
    /// A style every picker of `presentation` gets - one saying none is a menu - standing over the one every picker
    /// gets: it says only what the presentation changes. A picker asking for a style by its key, or for the
    /// platform's own look, wears none of it.
    ///
    ///     Style<Picker>().textColor(AppColors.text)
    ///     Style<Picker>(presentation: .segmented).tint(AppColors.accent)
    public init(presentation: PickerPresentation) {
        self.init(key: nil)
        variant = StyleVariant(PickerContract.presentation, presentation, unsaid: .menu)
    }
}

extension Styling where Scope == StyleScope.Whole {
    /// The style this one starts from, named by the key that style was given.
    ///
    /// The one it names must be in the same sheet. A key naming nothing is
    /// ignored, and a chain that comes back round to itself stops there.
    public func basedOn(_ key: StyleKey<Target>) -> Modified {
        var copy = self
        copy.basedOn = key.name
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
    ///   - setters: the property values in force while the control is there.
    public func visualState(
        _ state: VisualState<Target>,
        _ setters: (Styling<Target, StyleScope.VisualState>) -> Styling<Target, StyleScope.VisualState>
    ) -> Self {
        var copy = self
        let values = setters(Styling<Target, StyleScope.VisualState>(key: nil)).node.props
        copy.states = written(copy.states, adding: DeclaredState(key: state.key, setters: values))
        return copy
    }

    /// A state that changes nothing - declared so the control can be heard entering it.
    ///
    ///     Style<Button>()
    ///         .visualState(.normal)
    ///         .visualState(.disabled) { $0.textColor(.gray) }
    ///
    /// - Parameter state: the state, changing nothing.
    public func visualState(_ state: VisualState<Target>) -> Modified {
        var copy = self
        copy.states = written(copy.states, adding: DeclaredState(key: state.key))
        return copy
    }
}

extension Styling where Scope == StyleScope.Whole {
    /// The style with its target forgotten, for a `StyleSheet`: the target's
    /// node type, its values and its states.
    var erased: AnyStyle {
        AnyStyle(
            target: node.type,
            key: key,
            basedOn: basedOn,
            variant: variant,
            props: node.props,
            states: states)
    }
}

/// A style whose target type has been forgotten - what a `StyleSheet`
/// collects, made from a `Style<Text>()` and never by hand.
@MainActor
public struct AnyStyle {
    /// The node type this style is for - the target's own.
    let target: NodeType

    /// The key it is asked for by, or nil for the one every control of the type
    /// gets.
    let key: String?

    /// The style it starts from, until the sheet flattens the chain.
    let basedOn: String?

    /// The value of its target's member it is worn for, over the implicit style; nil for any other.
    let variant: StyleVariant?

    /// What it sets.
    var props: [Prop: PropValue]

    /// The states it declares, in writing order.
    var states: [DeclaredState]
}
