// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Styles: what every control of a type looks like, resolved on this side
// before the patch. A style is written with a control's own modifiers and
// carries only its target's property half.
// Design: docs/design/views/styles.md#styles-are-resolved-before-the-patch

/// A control a style can be written for: one with an initializer that sets
/// nothing, from which the style takes its node type.
public protocol StyleTarget: VisualElement {
    /// A control with nothing set. Where a style reads its target's type.
    init()

    /// The state a control of this type rests in, given to a group of states
    /// that names none so it has somewhere to return to: `.normal` for
    /// everything but a RadioButton.
    static var restingVisualState: VisualState<Self> { get }
}

extension StyleTarget {
    /// Where nearly everything rests: an enabled, unfocused, un-hovered control
    /// is in Normal.
    public static var restingVisualState: VisualState<Self> { .normal }
}

/// One state a control can be in, for the control type `Target`: after the
/// dot are the states that control enters, so `Style<Switch>().visualState(.on)`
/// compiles and `Style<Button>().visualState(.on)` does not. Names are spelled
/// as the host matches them: "PointerOver", not "pointerOver".
public struct VisualState<Target>: Equatable, Sendable {
    /// The name a state is matched on, spelled exactly.
    public let name: String

    /// A state by its name, for one this type does not name yet. Spell it as
    /// the host matches it: `VisualState("PointerOver")`, not "pointerOver".
    public init(_ name: String) {
        self.name = name
    }
}

/// The states every view has, driven for every visual element.
extension VisualState where Target: VisualElement {
    /// The ordinary state - nothing pressed, focused or disabled. What a control
    /// returns to.
    public static var normal: Self { Self("Normal") }

    /// While `isEnabled` is false.
    public static var disabled: Self { Self("Disabled") }

    /// While the control has the keyboard focus.
    public static var focused: Self { Self("Focused") }

    /// While the control does not have the keyboard focus. A control enters it
    /// right after Normal, so a group declaring both rests here.
    public static var unfocused: Self { Self("Unfocused") }

    /// While a mouse or pen is over the control. Never on a touch-only device.
    public static var pointerOver: Self { Self("PointerOver") }

    /// While the control is the chosen one - entered by whatever does the
    /// choosing, such as a `PositionIndicator`'s dots drawn from views.
    public static var selected: Self { Self("Selected") }

}

/// A Button is held down.
extension VisualState where Target == Button {
    /// While the button is held down. The host raises it from the platform, so
    /// this is a real press rather than a gesture recognized on this side.
    public static var pressed: Self { Self("Pressed") }
}

/// A Switch says which way it is.
extension VisualState where Target == Switch {
    /// While `isOn` is true.
    public static var on: Self { Self("On") }

    /// While `isOn` is false.
    public static var off: Self { Self("Off") }
}

/// A CheckBox has ONE state of its own - the Switch's word for it.
extension VisualState where Target == CheckBox {
    /// While `isOn` is true. There is no off state beside it: a CheckBox that
    /// is not on is in `.normal`.
    public static var on: Self { Self("On") }
}

/// A RadioButton has two, and neither is spelled the CheckBox's way.
extension VisualState where Target == RadioButton {
    /// While `isOn` is true.
    public static var checked: Self { Self("Checked") }

    /// While `isOn` is false - where a RadioButton rests, since it enters
    /// Checked or Unchecked before Normal.
    public static var unchecked: Self { Self("Unchecked") }
}

extension RadioButton {
    /// Unchecked, not Normal - see the note on `VisualState.unchecked`.
    public static var restingVisualState: VisualState<RadioButton> { .unchecked }
}

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

/// The states of one target with `state` written into them: the one place a
/// list of states is arranged, for a style and a control alike.
/// Design: docs/design/views/styles.md#arranging-states
func visualStates(_ existing: [Node], adding state: Node, resting: String) -> [Node] {
    let group = state.visualStateGroup ?? ""
    let name = state.visualStateName ?? ""

    var result = existing

    if let written = result.firstIndex(where: {
        $0.visualStateGroup == group && $0.visualStateName == name
    }) {
        result[written] = state
    } else {
        result.append(state)
    }

    guard let first = result.firstIndex(where: { $0.visualStateGroup == group }) else {
        return result
    }

    guard let at = result.firstIndex(where: {
        $0.visualStateGroup == group && $0.visualStateName == resting
    }) else {
        result.insert(emptyVisualState(named: resting, in: group), at: first)

        return result
    }

    if at != first {
        result.insert(result.remove(at: at), at: first)
    }

    return result
}

extension VisualElement where Self: StyleTarget {
    /// What changes while this control is in a state - the same thing a style
    /// says, said about one control.
    ///
    ///     Button("Save")
    ///         .visualState(.disabled) { $0.textColor(Palette.disabled) }
    ///
    /// A state written here is written over the state of the same name in the
    /// control's style, one setter at a time.
    ///
    /// - Parameters:
    ///   - state: which state these setters describe. What is offered after
    ///     the dot is the states this control actually enters.
    ///   - group: which group of states the state belongs to. A control is in
    ///     one state per group and leaves a state only by entering another in
    ///     the SAME group, so states that exclude one another belong together.
    ///     Every group has a name and nearly everything is in `CommonStates`,
    ///     so that is the default.
    ///   - setters: the property values in force while the control is there.
    public func visualState(
        _ state: VisualState<Self>,
        group: String = "CommonStates",
        _ setters: (StyleBag<Self, StyleState>) -> StyleBag<Self, StyleState>
    ) -> Modified {
        visualState(visualStateSetting(
            setters(StyleBag<Self, StyleState>(key: nil)).node.props, named: state.name, in: group))
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
    ///   - group: which group of states it belongs to, `CommonStates` unless
    ///     said otherwise.
    public func visualState(
        _ state: VisualState<Self>,
        group: String = "CommonStates"
    ) -> Modified {
        visualState(emptyVisualState(named: state.name, in: group))
    }

    /// Runs when this control enters one of the named states - where a state
    /// can animate rather than only be set.
    ///
    ///     @State private var lift = 1.0
    ///
    ///     Border { Label("Open") }
    ///         .scale($lift)
    ///         .onVisualStateChanged(.pointerOver, .normal) { state in
    ///             try await $lift.journey.move(to: state == .pointerOver ? 1.03 : 1, .eased(120, .cubicOut))
    ///         }
    ///
    /// A control reports only the states it declares, so the states named here
    /// are declared in `CommonStates`, merged with its style's without changing
    /// how it looks. Name only the states it should react to: declaring a
    /// state can change which one it rests in.
    ///
    /// - Parameter perform: what to run, given the state entered.
    public func onVisualStateChanged(
        _ states: VisualState<Self>...,
        perform handler: @escaping ValueEventHandler<VisualState<Self>>
    ) -> Modified {
        modified { node in
            for state in states {
                let already = node.children.contains {
                    $0.type == VisualStateContract.nodeType
                        && $0.visualStateName == state.name
                        && $0.visualStateGroup == "CommonStates"
                }

                guard !already else { continue }

                write(
                    emptyVisualState(named: state.name, in: "CommonStates"),
                    into: &node,
                    resting: Self.restingVisualState.name)
            }

            node.addHandler(VisualElementContract.visualStateChanged.token) {
                // The state's name, as text: an event payload carries no names.
                if let name = EventBuffer.current.value()?.string {
                    try await handler(VisualState<Self>(name))
                }
            }
        }
    }

    /// Writes one state into the control's own list, as children after what
    /// the control lays out.
    /// Design: docs/design/views/styles.md#visual-states
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

/// Collects the styles written in a `StyleSheet`'s closure; `if`, `else` and
/// `for` all work, so a sheet can answer a platform or a form factor.
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

/// The styles an application makes available.
///
/// Written into the application's session, so they apply to the whole
/// application:
///
///     application.styles = StyleSheet {
///         Style<Label>().textColor(AppColors.text)
///         Style<Button>("Danger").background(.firebrick)
///     }
///
/// Writing a new sheet restyles every control.
public struct StyleSheet {
    /// Every style, in writing order, each with what it is based on already
    /// under it - the one storage the two maps below point into.
    var written: [AnyStyle] = []

    /// Where the one every control of a type gets is.
    private var implicit: [NodeType: Int] = [:]

    /// Where the ones asked for by name are.
    private var keyed: [String: Int] = [:]

    /// The styles the closure describes, with every `basedOn` chain flattened.
    ///
    /// Two styles under one key, or two implicit ones for one target, are one:
    /// the LAST wins, as a second assignment to one dictionary key does.
    public init(@StyleBuilder _ content: () -> [AnyStyle]) {
        written = content()

        for (index, style) in written.enumerated() {
            if let key = style.key {
                keyed[key] = index
            } else {
                implicit[style.target] = index
            }
        }

        // Against what was written, so a style may start from one below it.
        let unflattened = written

        for index in written.indices {
            written[index] = StyleSheet.flatten(written[index], from: unflattened, keyed: keyed)
        }
    }

    /// One style with everything it is based on already under it; `chain`
    /// stops a cycle where it began.
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

    /// The style a node wears: the keyed one it asks for where that is for its
    /// type, or else the one every control of its type gets.
    func style(for node: Node) -> AnyStyle? {
        if let key = node.props[VisualElementContract.style.token]?.name, let at = keyed[key],
           written[at].target == node.type {
            return written[at]
        }

        return implicit[node.type].map { written[$0] }
    }

    /// Whether two sheets say the same thing - read once per render, to decide
    /// whether a composed view may still be carried.
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

/// The node as the host will see it: its style's values under its own, and
/// the states of both - the one place a style is applied.
/// Design: docs/design/views/styles.md#applying-a-style
func styled(_ node: Node, with sheet: StyleSheet?) -> Node {
    let style = sheet?.style(for: node)

    // Asked first: assigning nil to a missing key still copies the storage.
    guard style != nil || node.props[VisualElementContract.style.token] != nil else { return node }

    var node = node
    node.props[VisualElementContract.style.token] = nil

    guard let style = style else { return node }

    // The control's own values win, one property at a time.
    if !style.props.isEmpty {
        node.props = style.props.merging(node.props) { _, own in own }
    }

    guard !style.states.isEmpty else { return node }

    // States ride as children after what the control lays out.
    node.states = true

    let laid = node.children.filter { $0.type != .visualState }
    let own = node.children.filter { $0.type == .visualState }

    node.children = laid + merged(style.states, with: own)

    return node
}

/// The states of a control that also has a style: the style's, with the
/// control's written over them one setter at a time.
/// Design: docs/design/views/styles.md#states-on-a-control-over-its-style
func merged(_ base: [Node], with own: [Node]) -> [Node] {
    guard !own.isEmpty else { return base }
    guard !base.isEmpty else { return own }

    var result = base

    for state in own {
        let group = state.visualStateGroup
        let name = state.visualStateName

        if let at = result.firstIndex(where: {
            $0.visualStateGroup == group && $0.visualStateName == name
        }) {
            result[at] = overlaid(result[at], with: state)
        } else {
            result.append(state)
        }
    }

    return result
}

/// One state written over another, one setter at a time; a state that sets
/// nothing changes nothing.
private func overlaid(_ base: Node, with own: Node) -> Node {
    let mine = own.children.first { $0.type == .setters }?.props ?? [:]

    guard !mine.isEmpty else { return base }

    let theirs = base.children.first { $0.type == .setters }?.props ?? [:]

    var result = base
    var setters = Node(contract: SettersContract.self)
    setters.props = theirs.merging(mine) { _, m in m }
    result.children = [setters]

    return result
}

// MARK: - What a style may say
// Design: docs/design/views/tiers.md#two-halves

extension StyleBag: VisualElementProperties {}
extension StyleBag: ViewProperties where Target: View {}
extension StyleBag: LayoutProperties where Target: Layout {}
extension StyleBag: StackBaseProperties where Target: StackBase {}
extension StyleBag: ShapeProperties where Target: Shape {}
extension StyleBag: PaddingElement where Target: PaddingElement {}
extension StyleBag: TextStyleElement where Target: TextStyleElement {}
extension StyleBag: TextElement where Target: TextElement {}
extension StyleBag: FontElement where Target: FontElement {}
extension StyleBag: TintElement where Target: TintElement {}
extension StyleBag: TextAlignmentElement where Target: TextAlignmentElement {}
extension StyleBag: LineHeightElement where Target: LineHeightElement {}
extension StyleBag: DecorableTextElement where Target: DecorableTextElement {}
extension StyleBag: BorderElement where Target: BorderElement {}
extension StyleBag: ImageElement where Target: ImageElement {}
extension StyleBag: InputViewProperties where Target: InputView {}

// And each control's own properties.

extension StyleBag: ActivityIndicatorProperties where Target == ActivityIndicator {}
extension StyleBag: BorderProperties where Target == Border {}
extension StyleBag: ColorBoxProperties where Target == ColorBox {}
extension StyleBag: ButtonProperties where Target == Button {}
extension StyleBag: CheckBoxProperties where Target == CheckBox {}
extension StyleBag: DatePickerProperties where Target == DatePicker {}
extension StyleBag: TextEditorProperties where Target == TextEditor {}
extension StyleBag: TextFieldProperties where Target == TextField {}
extension StyleBag: CanvasProperties where Target == Canvas {}
extension StyleBag: GridProperties where Target == Grid {}
extension StyleBag: ImageProperties where Target == Image {}
extension StyleBag: PositionIndicatorProperties where Target == PositionIndicator {}
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
extension StyleBag: ScrollViewProperties where Target == ScrollView {}
extension StyleBag: SearchFieldProperties where Target == SearchField {}
extension StyleBag: SliderProperties where Target == Slider {}
extension StyleBag: StepperProperties where Target == Stepper {}
extension StyleBag: SwipeViewProperties where Target == SwipeView {}
extension StyleBag: SwitchProperties where Target == Switch {}
extension StyleBag: TimePickerProperties where Target == TimePicker {}
extension StyleBag: TitleBarProperties where Target == TitleBar {}
extension StyleBag: WebViewProperties where Target == WebView {}

// MARK: - What can be styled
// Design: docs/design/views/styles.md#what-can-be-styled

extension Label: StyleTarget {}
extension Button: StyleTarget {}
extension TextField: StyleTarget {}
extension TextEditor: StyleTarget {}
extension Picker: StyleTarget {}
extension DatePicker: StyleTarget {}
extension TimePicker: StyleTarget {}
extension Switch: StyleTarget {}
extension CheckBox: StyleTarget {}
extension RadioButton: StyleTarget {}
extension Slider: StyleTarget {}
extension Stepper: StyleTarget {}
extension SearchField: StyleTarget {}
extension ActivityIndicator: StyleTarget {}
extension ProgressBar: StyleTarget {}
extension Image: StyleTarget {}
extension ColorBox: StyleTarget {}
extension Border: StyleTarget {}
extension Grid: StyleTarget {}
extension ScrollView: StyleTarget {}
extension VStack: StyleTarget {}
extension HStack: StyleTarget {}
extension AbsoluteLayout: StyleTarget {}
extension RefreshView: StyleTarget {}
extension SwipeView: StyleTarget {}
extension Rectangle: StyleTarget {}
extension Ellipse: StyleTarget {}
extension Line: StyleTarget {}
extension Path: StyleTarget {}
extension Polygon: StyleTarget {}
extension Polyline: StyleTarget {}
extension Canvas: StyleTarget {}
extension PositionIndicator: StyleTarget {}
extension WebView: StyleTarget {}
extension Map: StyleTarget {}
extension TitleBar: StyleTarget {}

// A SwipeAction is a menu item, not a view, and has nothing to style.

/// A visual state named `name` in `group`, with no values of its own - how a
/// state a control only has to be able to enter is written.
func emptyVisualState(named name: String, in group: String) -> Node {
    var node = Node(contract: VisualStateContract.self)
    node.write(VisualStateContract.name, Name(name))
    node.write(VisualStateContract.group, Name(group))
    return node
}

/// A visual state with the values in force while the control is in it: its
/// setters, under the state's name and group.
func visualStateSetting(_ values: [Prop: PropValue], named name: String, in group: String) -> Node {
    var setters = Node(contract: SettersContract.self)
    setters.props = values

    var node = emptyVisualState(named: name, in: group)
    node.children = [setters]
    return node
}

extension Node {
    /// The group a visual state's node says it belongs to.
    fileprivate var visualStateGroup: String? { props[VisualStateContract.group.token]?.name }

    /// The name a visual state's node carries.
    fileprivate var visualStateName: String? { props[VisualStateContract.name.token]?.name }
}
