// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A StateUI layout over a `StateUIViewGroup`: Android asks it to measure and place, and the core's arithmetic answers.
/// Design: docs/design/platforms/android/layout.md#a-layout-is-a-view-group
@MainActor
class AndroidLayoutView: AndroidView {
    /// The sizes measured for the widths offered, kept until something changes them.
    let measurements = MeasurementCache()

    /// The children, in order.
    private(set) var items: [AndroidLayoutItem] = []

    init() {
        super.init { number in
            Java.new(
                JavaAPI.viewGroupHost, JavaAPI.newViewGroupHost,
                .object(AndroidRenderer.context), .long(number))
        }
    }

    /// Puts `items` in the group, in order, where they differ from the children it holds.
    func setItems(_ items: [AndroidLayoutItem]) {
        guard items.count != self.items.count
            || !zip(items, self.items).allSatisfy({ $0.arranges(like: $1) })
        else { return }

        if !Self.same(items.map(\.view), self.items.map(\.view)) {
            let children = Java.array(of: JavaAPI.view, items.map(\.view.reference))
            Java.call(reference, JavaAPI.setChildren, .object(children))
            Java.release(local: children)
        }

        self.items = items
        invalidateMeasurements()
    }

    /// Forgets the kept sizes and asks Android to measure again.
    func invalidateMeasurements() {
        measurements.invalidate()
        requestLayout()
    }

    /// Answers Android's measure: the size in pixels for the specs given.
    func measure(widthSpec: Int32, heightSpec: Int32) -> (width: Int32, height: Int32) {
        let offered = ViewConstants.mode(widthSpec) == ViewConstants.unspecified
            ? nil
            : Double(ViewConstants.size(widthSpec)) / density
        let natural = measurements.size(offering: offered) { contentSize(width: offered) }

        return (resolve(widthSpec, natural.width), resolve(heightSpec, natural.height))
    }

    /// Answers Android's layout: places every child in `width` by `height` pixels.
    func arrange(width: Int32, height: Int32) {
        arrange(in: Rect(x: 0, y: 0, width: Double(width) / density, height: Double(height) / density))
    }

    /// The room the children take for the width offered, in points.
    func contentSize(width: Double?) -> LayoutSize {
        .zero
    }

    /// Places the children in `bounds`, in points.
    func arrange(in bounds: Rect) {}

    /// Whether two lists hold the same views in the same order.
    private static func same(_ left: [AndroidView], _ right: [AndroidView]) -> Bool {
        left.count == right.count && zip(left, right).allSatisfy { $0 === $1 }
    }

    /// A measured extent within what `spec` allows.
    private func resolve(_ spec: Int32, _ natural: Double) -> Int32 {
        switch ViewConstants.mode(spec) {
        case ViewConstants.exactly: ViewConstants.size(spec)
        case ViewConstants.atMost: min(pixels(natural), ViewConstants.size(spec))
        default: pixels(natural)
        }
    }
}
