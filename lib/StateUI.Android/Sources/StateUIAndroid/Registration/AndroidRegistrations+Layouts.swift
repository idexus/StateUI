// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension AndroidRegistrations {
    /// The stacks, the grid, the absolute layout and the border: the room a layout leaves around and
    /// between its children, and a border's shape.
    static func layouts(_ registry: Registry<AndroidView>) {
        registry.add(VStackContract.self, create: { _ in AndroidStackView(axis: .vertical) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
        }

        registry.add(HStackContract.self, create: { _ in AndroidStackView(axis: .horizontal) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
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
        }

        registry.add(AbsoluteLayoutContract.self, create: { _ in AndroidAbsoluteLayoutView() }) { _ in }

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
