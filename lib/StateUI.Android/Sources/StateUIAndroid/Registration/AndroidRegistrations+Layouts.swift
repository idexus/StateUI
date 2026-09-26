// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// The stacks, the grid, the ZStack and the scroller: the room a layout leaves around and between its
    /// children, and the box it paints.
    static func layouts(_ registry: Registry<AndroidView>) {
        registry.add(VStackContract.self, create: { _ in AndroidStackView(axis: .vertical) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.applies(boxMembers) { view, values in applyBox(view, values) }
            stack.property(VisualElementContract.ignoresInput) { view, ignores in view.setIgnoresInput(ignores ?? false) }
        }

        registry.add(HStackContract.self, create: { _ in AndroidStackView(axis: .horizontal) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.applies(boxMembers) { view, values in applyBox(view, values) }
            stack.property(VisualElementContract.ignoresInput) { view, ignores in view.setIgnoresInput(ignores ?? false) }
        }

        registry.add(GridContract.self, create: { _ in AndroidGridView() }) { grid in
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
            grid.property(VisualElementContract.ignoresInput) { view, ignores in view.setIgnoresInput(ignores ?? false) }
        }

        registry.add(ZStackContract.self, create: { _ in AndroidZStackView() }) { layout in
            layout.property(PaddingElementContract.padding) { view, padding in view.padding = padding ?? Insets(0) }
            layout.applies(boxMembers) { view, values in applyBox(view, values) }
            layout.property(VisualElementContract.ignoresInput) { view, ignores in view.setIgnoresInput(ignores ?? false) }
        }

        // Where the user moves it is reported by the element, on the display's frames.
        // Design: docs/design/platforms/android/layout.md#scrolling
        registry.add(ScrollViewContract.self, create: { _ in AndroidScrollView() }) { scroll in
            scroll.applies([
                ScrollViewContract.orientation, ScrollViewContract.verticalScrollBarVisibility,
                ScrollViewContract.horizontalScrollBarVisibility, ScrollViewContract.scrollOffset,
                PaddingElementContract.padding,
            ]) { view, values in
                view.apply(
                    orientation: values[ScrollViewContract.orientation] ?? .vertical,
                    padding: values[PaddingElementContract.padding] ?? Insets(0),
                    verticalBar: values[ScrollViewContract.verticalScrollBarVisibility] ?? .default,
                    horizontalBar: values[ScrollViewContract.horizontalScrollBarVisibility] ?? .default,
                    offset: values.changed(ScrollViewContract.scrollOffset) ? values[ScrollViewContract.scrollOffset] : nil)
            }
            scroll.applies([
                BorderElementContract.shape, BorderElementContract.stroke, BorderElementContract.strokeWidth,
            ]) { view, values in
                // A scroller always cuts what it shows to its bounds; a shape cuts it to the shape.
                view.setOutline(AndroidLayoutView.Outline(
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    width: values[BorderElementContract.strokeWidth],
                    shape: values[BorderElementContract.shape]?.propValue,
                    clips: values[BorderElementContract.shape] != nil))
            }
            scroll.raises(ScrollViewContract.scrollXChanged)
            scroll.raises(ScrollViewContract.scrollYChanged)
            scroll.raises(ScrollViewContract.scrollStopped)
        }
    }

    /// What every layout takes of its own box: its outline, its shape and its cut.
    private static let boxMembers: [any ContractMember] = [
        BorderElementContract.stroke, BorderElementContract.strokeWidth, BorderElementContract.shape,
        LayoutContract.clipsContent,
    ]

    private static func applyBox<Realized: ElementContract>(_ view: AndroidLayoutView, _ values: ElementValues<Realized>) {
        view.setOutline(AndroidLayoutView.Outline(
            stroke: values[BorderElementContract.stroke]?.propValue,
            width: values[BorderElementContract.strokeWidth],
            shape: values[BorderElementContract.shape]?.propValue,
            clips: values[LayoutContract.clipsContent] ?? false))
    }

    /// What both stacks take: the space between their children, and the space inside their own edge.
    private static let stackMembers: [any ContractMember] = [
        StackBaseContract.spacing, PaddingElementContract.padding,
    ]

    private static func applyStack<Realized: ElementContract>(
        _ view: AndroidStackView, _ values: ElementValues<Realized>
    ) {
        view.spacing = values[StackBaseContract.spacing] ?? 0
        view.padding = values[PaddingElementContract.padding] ?? Insets(0)
    }
}
