// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

extension AppKitRegistrations {
    /// The stacks and the grid: the room a layout leaves around and between
    /// its children. What ARRANGES the children is not here - a layout walks
    /// its own rows, which is the host's work, and a registration describes
    /// one view.
    static func layouts(_ registry: Registry<NSView>) {
        registry.add(VStackContract.self, create: { _ in AppKitStackView(axis: .vertical) }) { stack in
            stack.applies(Self.stackMembers) { view, values in
                view.spacing = CGFloat(values[StackBaseContract.spacing] ?? 0)
                view.padding = Self.edgeInsets(values[PaddingElementContract.padding])
            }
        }

        registry.add(HStackContract.self, create: { _ in AppKitStackView(axis: .horizontal) }) { stack in
            stack.applies(Self.stackMembers) { view, values in
                view.spacing = CGFloat(values[StackBaseContract.spacing] ?? 0)
                view.padding = Self.edgeInsets(values[PaddingElementContract.padding])
            }
        }

        // The host makes the scroll view; its registration takes the members alone.
        // Design: docs/design/platforms/appkit/registrations.md#the-scroll-view
        registry.add(ScrollViewContract.self, madeByHost: AppKitScrollView.self) { scroll in
            scroll.applies([
                ScrollViewContract.orientation,
                ScrollViewContract.verticalScrollBarVisibility,
                ScrollViewContract.horizontalScrollBarVisibility,
                ScrollViewContract.scrollOffset,
                PaddingElementContract.padding,
            ]) { view, values in
                // The offset is written only where the tree moved it.
                // Design: docs/design/platforms/appkit/input.md#scrolling
                let offset = values.changed(ScrollViewContract.scrollOffset)
                    ? values[ScrollViewContract.scrollOffset].map { NSPoint(x: $0.x, y: $0.y) }
                    : nil

                view.apply(
                    orientation: (values[ScrollViewContract.orientation] ?? .vertical).rawValue,
                    padding: Self.edgeInsets(values[PaddingElementContract.padding]),
                    verticalBarVisibility:
                        (values[ScrollViewContract.verticalScrollBarVisibility] ?? .default).rawValue,
                    horizontalBarVisibility:
                        (values[ScrollViewContract.horizontalScrollBarVisibility] ?? .default).rawValue,
                    offset: offset)
            }
            scroll.applies([
                BorderElementContract.shape, BorderElementContract.stroke, BorderElementContract.strokeWidth,
            ]) { view, values in
                view.setBox(
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    strokeWidth: values[BorderElementContract.strokeWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
        }

        registry.add(GridContract.self, create: { _ in AppKitGridView() }) { grid in
            grid.applies([
                GridContract.rows, GridContract.columns,
                GridContract.rowSpacing, GridContract.columnSpacing,
                PaddingElementContract.padding,
            ]) { view, values in
                view.rows = Self.gridLengths(values[GridContract.rows])
                view.columns = Self.gridLengths(values[GridContract.columns])
                view.rowSpacing = CGFloat(values[GridContract.rowSpacing] ?? 0)
                view.columnSpacing = CGFloat(values[GridContract.columnSpacing] ?? 0)
                view.padding = Self.edgeInsets(values[PaddingElementContract.padding])
            }
        }
    }

    /// What both stacks take: the space between their children, and the space
    /// kept inside their own edge.
    private static let stackMembers: [any ContractMember] = [
        StackBaseContract.spacing, PaddingElementContract.padding,
    ]

    /// A row or a column is a kind and an amount, and travels as the two of
    /// them - a LIST OF VALUES, as a render transform does.
    private static func gridLengths(_ value: [GridLength]?) -> [GridLength] {
        value ?? []
    }
}

#endif
