// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The row of dots under a run of cards, saying how many there are and which
/// one is showing.
///
///     PositionIndicator()
///         .count(cards.count)
///         .position(shown)
///         .indicatorColor(.lightGray)
///         .selectedIndicatorColor(.cornflowerBlue)
///
/// It is joined to a `GalleryView` by shared state: the gallery's
/// `.position($shown)` writes it as the user swipes, and `.position(shown)`
/// here reads it. It serves anything with a place in a sequence.
///
/// StateUI composes it of colour boxes in a row, the same on every platform.
/// Design: docs/design/views/measured-layouts.md#position-indicator
public struct PositionIndicator: ContentView {
    /// Each item's own mark, where the items were given; nil for dots.
    private let marks: Marks?

    private var count: Given<Int> = .value(0)
    private var position = 0
    private var indicatorColor: Given<Color> = .value(Self.dotColor)
    private var selectedIndicatorColor: Given<Color> = .value(Self.currentColor)
    private var indicatorSize: Given<Double> = .value(7)
    private var maximumVisible: Given<Int> = .value(.max)
    private var indicatorsShape: Given<IndicatorShape> = .value(.circle)
    private var hideSingle: Given<Bool> = .value(true)

    /// A row with no dots yet - `count` gives it some.
    public init() {
        marks = nil
    }

    /// Each dot is described as a view of its own and built from the supplied
    /// content closure.
    ///
    ///     PositionIndicator(cards) { _ in
    ///         Image("diamond.png")
    ///     }
    ///     .position(shown)
    ///
    /// The items take the place of `count`, which is derived from them; the
    /// current item's mark stands whole, the others faded.
    public init<Items: RandomAccessCollection, Content: View>(
        _ items: Items,
        @ViewBuilder content: (Items.Element) -> Content
    ) {
        marks = Marks(items.map { content($0).body })
    }

    /// The marks in a row, centred in the room the row is given.
    public var content: some View {
        let shown = Self.shown(
            count: marks?.nodes.count ?? count.current, position: position,
            maximumVisible: maximumVisible.current, hidesSingle: hideSingle.current)
        let current = position
        return HStack {
            ForEach(shown) { place in
                mark(at: place, current: place == current)
            }
        }
        .spacing(indicatorSize.current)
        .horizontalAlignment(.center)
    }

    /// The mark at `place`: the item's own, or a dot in the colour its being
    /// current or not gives it.
    private func mark(at place: Int, current: Bool) -> Mark {
        if let marks {
            return Mark(node: marks.nodes[place]).opacity(current ? 1 : Self.faded)
        }
        let size = indicatorSize.current
        let color = current ? selectedIndicatorColor.current : indicatorColor.current
        let dot = ColorBox(color)
            .cornerRadius(indicatorsShape.current == .circle ? size / 2 : 0)
            .width(size)
            .height(size)
        return Mark(node: dot.body)
    }

    /// The places of the marks shown: none for a lone one hidden; every place
    /// up to `maximumVisible`, and past it a run of that many holding the
    /// position as near its middle as the ends allow.
    static func shown(count: Int, position: Int, maximumVisible: Int, hidesSingle: Bool) -> Range<Int> {
        guard count > 0, !(count == 1 && hidesSingle) else { return 0..<0 }
        let most = min(count, max(1, maximumVisible))
        let first = min(max(0, position - most / 2), count - most)
        return first..<(first + most)
    }

    /// A dot's colour and the current one's, on a light and a dark page.
    static let dotColor = Color(light: Color("#C4C4C4"), dark: Color("#5C5C5C"))
    static let currentColor = Color(light: Color("#3C3C3C"), dark: Color("#E6E6E6"))

    /// How strongly a mark that is not the current one is drawn.
    static let faded = 0.4
}

extension PositionIndicator {
    /// How many dots there are.
    ///
    /// The other way to say it is `PositionIndicator(items) { … }`, which counts
    /// its items itself - one or the other, never both.
    public func count(_ value: Int) -> Self {
        with { $0.count = .value(value) }
    }

    /// Which dot is the current one, counting from 0 - usually the state a
    /// gallery's `position($shown)` writes.
    public func position(_ value: Int) -> Self {
        with { $0.position = value }
    }

    /// The colour of a dot that is not the current one.
    public func indicatorColor(_ value: Color) -> Self {
        with { $0.indicatorColor = .value(value) }
    }

    /// And of the one that is.
    public func selectedIndicatorColor(_ value: Color) -> Self {
        with { $0.selectedIndicatorColor = .value(value) }
    }

    /// How big each dot is, in device units, and how far apart.
    public func indicatorSize(_ value: Double) -> Self {
        with { $0.indicatorSize = .value(value) }
    }

    /// The most dots to draw, however many items there are.
    public func maximumVisible(_ value: Int) -> Self {
        with { $0.maximumVisible = .value(value) }
    }

    /// A dot or a square, for every dot.
    public func indicatorsShape(_ value: IndicatorShape) -> Self {
        with { $0.indicatorsShape = .value(value) }
    }

    /// Whether one lonely dot is hidden rather than drawn. True by default.
    public func hideSingle(_ value: Bool) -> Self {
        with { $0.hideSingle = .value(value) }
    }

    /// `count` from a state, `$x`: the row is built again as it changes.
    public func count(_ state: Binding<Int>) -> Self {
        with { $0.count = .state(state) }
    }

    /// `hideSingle` from a state, `$x`: the row is built again as it changes.
    public func hideSingle(_ state: Binding<Bool>) -> Self {
        with { $0.hideSingle = .state(state) }
    }

    /// `indicatorColor` from a state, `$x`: the row is built again as it
    /// changes, and the dots travel to the new colour.
    public func indicatorColor(_ state: Binding<Color>) -> Self {
        with { $0.indicatorColor = .state(state) }
    }

    /// `indicatorSize` from a state, `$x`: the row is built again as it changes.
    public func indicatorSize(_ state: Binding<Double>) -> Self {
        with { $0.indicatorSize = .state(state) }
    }

    /// `indicatorsShape` from a state, `$x`: the row is built again as it
    /// changes.
    public func indicatorsShape(_ state: Binding<IndicatorShape>) -> Self {
        with { $0.indicatorsShape = .state(state) }
    }

    /// `maximumVisible` from a state, `$x`: the row is built again as it
    /// changes.
    public func maximumVisible(_ state: Binding<Int>) -> Self {
        with { $0.maximumVisible = .state(state) }
    }

    /// `selectedIndicatorColor` from a state, `$x`: the row is built again as
    /// it changes, and the current dot travels to the new colour.
    public func selectedIndicatorColor(_ state: Binding<Color>) -> Self {
        with { $0.selectedIndicatorColor = .state(state) }
    }

    private func with(_ change: (inout Self) -> Void) -> Self {
        var copy = self
        change(&copy)
        return copy
    }
}

/// A value the tree gives as it stands, or from a state the row reads.
private enum Given<Value> {
    case value(Value)
    case state(Binding<Value>)

    var current: Value {
        switch self {
        case .value(let value): value
        case .state(let state): state.wrappedValue
        }
    }
}

/// The items' own marks, behind a class so the walk for state stops here.
private final class Marks {
    let nodes: [Node]

    init(_ nodes: [Node]) {
        self.nodes = nodes
    }
}

/// One mark of the row, as its node.
private struct Mark: View {
    var node: Node
}
