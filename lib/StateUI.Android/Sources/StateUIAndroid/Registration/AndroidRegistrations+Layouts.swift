// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension AndroidRegistrations {
    /// The stacks, the grid, the absolute layout and the border: the room a layout leaves around and
    /// between its children, and a border's shape.
    static func layouts(_ registry: Registry<AndroidView>) {
        registry.add(VStackContract.self, create: { _ in AndroidStackView(axis: .vertical) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.property(VisualElementContract.ignoresInput) { view, ignores in view.setIgnoresInput(ignores ?? false) }
        }

        registry.add(HStackContract.self, create: { _ in AndroidStackView(axis: .horizontal) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
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
            grid.property(VisualElementContract.ignoresInput) { view, ignores in view.setIgnoresInput(ignores ?? false) }
        }

        registry.add(AbsoluteLayoutContract.self, create: { _ in AndroidAbsoluteLayoutView() }) { layout in
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
            scroll.raises(ScrollViewContract.scrollXChanged)
            scroll.raises(ScrollViewContract.scrollYChanged)
            scroll.raises(ScrollViewContract.scrollStopped)
        }

        registry.add(BorderContract.self, create: { _ in AndroidBorderView() }) { border in
            border.applies([
                BorderContract.shape, BorderContract.stroke, BorderContract.strokeWidth,
                PaddingElementContract.padding,
            ]) { view, values in
                view.padding = values[PaddingElementContract.padding] ?? Insets(0)
                view.apply(
                    stroke: values[BorderContract.stroke]?.propValue,
                    strokeWidth: values[BorderContract.strokeWidth],
                    shape: AndroidShapeDrawable.Shape(border: values[BorderContract.shape]?.propValue))
            }
            border.property(VisualElementContract.ignoresInput) { view, ignores in view.setIgnoresInput(ignores ?? false) }
        }
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
