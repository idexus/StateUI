// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// The stacks, the grid and the ZStack: the room a layout leaves around and between its children, the box it
    /// paints, and whether a touch beside its children goes on to what is under it.
    static func layouts(_ registry: Registry<UIView>) {
        registry.add(VStackContract.self, create: { _ in UIKitStackView(axis: .vertical) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.applies(boxMembers) { view, values in applyBox(view, values) }
            stack.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }

        registry.add(HStackContract.self, create: { _ in UIKitStackView(axis: .horizontal) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.applies(boxMembers) { view, values in applyBox(view, values) }
            stack.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }

        registry.add(GridContract.self, create: { _ in UIKitGridView() }) { grid in
            grid.applies([
                GridContract.rows, GridContract.columns,
                GridContract.rowSpacing, GridContract.columnSpacing,
                PaddingElementContract.padding,
            ]) { view, values in
                view.rows = values[GridContract.rows] ?? []
                view.columns = values[GridContract.columns] ?? []
                view.rowSpacing = values[GridContract.rowSpacing] ?? 0
                view.columnSpacing = values[GridContract.columnSpacing] ?? 0
                view.padding = values[PaddingElementContract.padding] ?? Insets(0)
            }
            grid.applies(boxMembers) { view, values in applyBox(view, values) }
            grid.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }

        registry.add(ZStackContract.self, create: { _ in UIKitZStackView() }) { layout in
            layout.property(PaddingElementContract.padding) { view, padding in view.padding = padding ?? Insets(0) }
            layout.applies(boxMembers) { view, values in applyBox(view, values) }
            layout.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }
    }

    /// A ScrollView: its orientation, bars and room, and the offset the tree moves it to. Where the user moves it is
    /// reported by the element, on the display's frames.
    /// Design: docs/design/platforms/uikit/layout.md#scrolling
    static func scrolling(_ registry: Registry<UIView>) {
        registry.add(ScrollViewContract.self, create: { _ in UIKitScrollView() }) { scroll in
            scroll.applies([
                ScrollViewContract.orientation, ScrollViewContract.verticalScrollIndicator,
                ScrollViewContract.horizontalScrollIndicator, ScrollViewContract.scrollOffset,
                PaddingElementContract.padding,
            ]) { view, values in
                view.apply(
                    orientation: values[ScrollViewContract.orientation] ?? .vertical,
                    padding: values[PaddingElementContract.padding] ?? Insets(0),
                    verticalBar: values[ScrollViewContract.verticalScrollIndicator] ?? .automatic,
                    horizontalBar: values[ScrollViewContract.horizontalScrollIndicator] ?? .automatic,
                    offset: values.changed(ScrollViewContract.scrollOffset) ? values[ScrollViewContract.scrollOffset] : nil)
            }
            scroll.applies([
                VisualElementContract.background,
                BorderElementContract.shape, BorderElementContract.stroke, BorderElementContract.lineWidth,
            ]) { view, values in
                // A scroller cuts what it shows to its bounds; a shape cuts it to the shape.
                view.setBox(
                    fill: values[VisualElementContract.background]?.propValue,
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    width: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue,
                    clips: true)
            }
            scroll.raises(ScrollViewContract.scrollXChanged)
            scroll.raises(ScrollViewContract.scrollYChanged)
            scroll.raises(ScrollViewContract.scrollStopped)
        }
    }

    /// What every layout takes of its own box: what fills it, its outline, its shape and its cut.
    private static let boxMembers: [any ContractMember] = [
        BorderElementContract.backdrop, VisualElementContract.background,
        BorderElementContract.stroke, BorderElementContract.lineWidth, BorderElementContract.shape,
        LayoutContract.clipsContent,
    ]

    private static func applyBox<Realized: ElementContract>(_ view: UIKitLayoutView, _ values: ElementValues<Realized>) {
        view.setBox(
            backdrop: values[BorderElementContract.backdrop]?.propValue,
            fill: values[VisualElementContract.background]?.propValue,
            stroke: values[BorderElementContract.stroke]?.propValue,
            width: values[BorderElementContract.lineWidth],
            shape: values[BorderElementContract.shape]?.propValue,
            clips: values[LayoutContract.clipsContent] ?? false)
    }

    /// What both stacks take: the space between their children, and the space inside their own edge.
    private static let stackMembers: [any ContractMember] = [
        StackContract.spacing, PaddingElementContract.padding,
    ]

    private static func applyStack<Realized: ElementContract>(_ view: UIKitStackView, _ values: ElementValues<Realized>) {
        view.spacing = values[StackContract.spacing] ?? 0
        view.padding = values[PaddingElementContract.padding] ?? Insets(0)
    }
}
#endif
