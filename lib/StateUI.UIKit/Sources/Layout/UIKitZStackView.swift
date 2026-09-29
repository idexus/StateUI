// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ZStack: its children one over another, each in its area (`ZStackArithmetic`), or where an engine's placement
/// run puts it.
/// Design: docs/design/platforms/uikit/drawing.md#a-placed-child
@MainActor
final class UIKitZStackView: UIKitLayoutView {
    /// The placement a state drives, one per child; nil while each child stands in its own area.
    var placement: HostPlacementRun? {
        didSet {
            guard placement != oldValue else { return }
            orderChildren()
            // A run moving on asks only for places: they need no room, so nothing around is measured.
            if let placements = placement?.placements, !placements.isEmpty, oldValue?.placements.isEmpty == false {
                apply(placements)
            } else {
                forgetMeasurements()
                setNeedsLayout()
            }
        }
    }

    /// The room inside the ZStack's own edge.
    var padding = Insets(0) {
        didSet {
            guard padding != oldValue else { return }
            forgetMeasurements()
            setNeedsLayout()
        }
    }

    override func setItems(_ items: [UIKitLayoutItem]) {
        super.setItems(items)
        orderChildren()
    }

    override func contentSize(width: Double?) -> LayoutSize {
        ZStackArithmetic.size(of: items, padding: padding, width: width)
    }

    override func arrange(in bounds: Rect) {
        if let placements = placement?.placements, !placements.isEmpty {
            return apply(placements)
        }
        for item in items {
            item.drawing?.placement = nil
            item.drawing?.placedOpacity = 1
        }
        let places = ZStackArithmetic.places(of: items, in: bounds, padding: padding, direction: direction)
        for (item, place) in zip(items, places) {
            if let place { self.place(item, at: place) }
        }
    }

    /// The children back to front as the run ranks them, or in their order without one: a touch reaches the front
    /// one first.
    private func orderChildren() {
        let order = ZStackArithmetic.drawingOrder(of: items.count, placedBy: placement?.placements ?? [])
        for index in order where index < items.count {
            bringSubviewToFront(items[index].view)
        }
    }

    /// Stands each child where the run says, drawn as it says.
    private func apply(_ placements: [HostPlacement]) {
        let count = min(items.count, placements.count)
        for index in 0..<count {
            let placement = placements[index]
            let item = items[index]
            item.drawing?.placement = placement.drawing
            item.drawing?.placedOpacity = placement.drawnOpacity
            item.placed?.placedFrame = placement.place
            (item.view as? UIKitGridView)?.setShadeOpacity(placement.drawnShade)
        }
        for item in items[count...] {
            item.drawing?.placement = nil
            item.drawing?.placedOpacity = 1
        }
    }
}
#endif
