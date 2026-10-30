// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// The stacks and the grid: the room a layout leaves around and between
    /// its children. What ARRANGES the children is not here - a layout walks
    /// its own rows, which is the host's work, and a registration describes
    /// one view.
    static func layouts(_ registry: Registry<NSView>) {
        registry.add(VStackContract.self, create: { _ in AppKitStackView(axis: .vertical) }) { stack in
            stack.applies(LayoutMembers.stackMembers) { view, values in
                view.spacing = CGFloat(values[StackContract.spacing] ?? 0)
                view.padding = values[PaddingElementContract.padding] ?? Insets(0)
            }
        }

        registry.add(HStackContract.self, create: { _ in AppKitStackView(axis: .horizontal) }) { stack in
            stack.applies(LayoutMembers.stackMembers) { view, values in
                view.spacing = CGFloat(values[StackContract.spacing] ?? 0)
                view.padding = values[PaddingElementContract.padding] ?? Insets(0)
            }
            stack.applies(LayoutMembers.rowMembers) { view, values in view.lines = StackArithmetic.Lines(values) }
        }

        // A fill is a box of its own that holds nothing: its material, outline and shape the box's decoration draws,
        // as a layout's.
        // Design: docs/design/host/layout.md#a-fill
        registry.add(FillContract.self, create: { _ in AppKitZStackView() })

        // A space is a box of its own the stack's arithmetic sizes, drawn as a layout's box; a separator in a stack is
        // the toolkit's line.
        // Design: docs/design/host/layout.md#a-space
        registry.add(SpaceContract.self, create: { _ in AppKitZStackView() })
        registry.add(SeparatorContract.self, create: { _ in AppKitSeparatorView() })

        // The host makes the scroll view; its registration takes the members alone.
        // Design: docs/design/platforms/appkit/registrations.md#the-scroll-view
        registry.add(ScrollViewContract.self, madeByHost: AppKitScrollView.self) { scroll in
            scroll.applies(
                ScrollViewContract.orientation, ScrollViewContract.verticalScrollIndicator,
                ScrollViewContract.horizontalScrollIndicator, ScrollViewContract.scrollOffset,
                PaddingElementContract.padding) { view, values in
                // The offset is written only where the tree moved it.
                // Design: docs/design/platforms/appkit/input.md#scrolling
                let offset = values.changed(ScrollViewContract.scrollOffset)
                    ? values[ScrollViewContract.scrollOffset].map { NSPoint(x: $0.x, y: $0.y) }
                    : nil

                view.apply(
                    orientation: (values[ScrollViewContract.orientation] ?? .vertical).rawValue,
                    padding: values[PaddingElementContract.padding] ?? Insets(0),
                    verticalBarVisibility:
                        (values[ScrollViewContract.verticalScrollIndicator] ?? .automatic).rawValue,
                    horizontalBarVisibility:
                        (values[ScrollViewContract.horizontalScrollIndicator] ?? .automatic).rawValue,
                    offset: offset)
            }
            scroll.applies(
                BorderElementContract.shape, BorderElementContract.stroke,
                BorderElementContract.lineWidth) { view, values in
                view.setBox(
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    lineWidth: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
        }

        registry.add(GridContract.self, create: { _ in AppKitGridView() }) { grid in
            grid.applies(
                GridContract.rows, GridContract.columns, GridContract.rowSpacing, GridContract.columnSpacing,
                PaddingElementContract.padding) { view, values in
                view.rows = Self.gridLengths(values[GridContract.rows])
                view.columns = Self.gridLengths(values[GridContract.columns])
                view.rowSpacing = CGFloat(values[GridContract.rowSpacing] ?? 0)
                view.columnSpacing = CGFloat(values[GridContract.columnSpacing] ?? 0)
                view.padding = values[PaddingElementContract.padding] ?? Insets(0)
            }
        }
    }


    /// A row or a column is a kind and an amount, and travels as the two of
    /// them - a LIST OF VALUES, as a render transform does.
    private static func gridLengths(_ value: [GridLength]?) -> [GridLength] {
        value ?? []
    }
}

#endif
