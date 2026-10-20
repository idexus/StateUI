// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// The stacks, the grid and the ZStack: the room a layout leaves around and between its children, and the box
    /// it paints.
    static func layouts(_ registry: Registry<WinUIView>) {
        registry.add(VStackContract.self, create: { _ in WinUIStackView(axis: .vertical) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.applies(boxMembers) { view, values in applyBox(view, values) }
        }

        registry.add(HStackContract.self, create: { _ in WinUIStackView(axis: .horizontal) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.applies(boxMembers) { view, values in applyBox(view, values) }
        }

        // A spacer is empty room the stack's arithmetic sizes; a divider in a stack is the theme's line.
        // Design: docs/design/host/layout.md#a-spacer
        registry.add(SpacerContract.self, create: { _ in WinUIStackPartView.spacer() })
        registry.add(DividerContract.self, create: { _ in WinUIStackPartView.divider() })

        registry.add(GridContract.self, create: { _ in WinUIGridView() }) { grid in
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
        }

        registry.add(ZStackContract.self, create: { _ in WinUIZStackView() }) { layout in
            layout.property(PaddingElementContract.padding) { view, padding in view.padding = padding ?? Insets(0) }
            layout.applies(boxMembers) { view, values in applyBox(view, values) }
        }

        // A layout engine stands on the ZStack: its children where its run of placements puts them.
        registry.add(LayoutEngineContract.self, create: { _ in
            let layout = WinUIZStackView()
            layout.engine = true
            return layout
        }) { layout in
            layout.applies(boxMembers) { view, values in applyBox(view, values) }
        }

        // Where the user moves it is reported by the element, on the display's frames.
        // Design: docs/design/platforms/winui/layout.md#scrolling
        registry.add(ScrollViewContract.self, create: { _ in WinUIScrollView() }) { scroll in
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
                // A scroller always cuts what it shows to its bounds; a shape cuts it to the shape.
                view.setBackground(HostMaterial(values[VisualElementContract.background]?.propValue).painted)
                view.setOutline(
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    width: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue,
                    clips: values[BorderElementContract.shape] != nil)
            }
            scroll.raises(ScrollViewContract.scrollStopped)
        }
    }

    /// What every layout takes of its own box: what fills it, its outline, its shape and its cut.
    private static let boxMembers: [any ContractMember] = [
        VisualElementContract.background,
        BorderElementContract.stroke, BorderElementContract.lineWidth, BorderElementContract.shape,
        LayoutContract.clipsContent,
    ]

    private static func applyBox<Realized: ElementContract>(_ view: WinUILayoutView, _ values: ElementValues<Realized>) {
        // A blur's colour stands in for the box's acrylic, its tint over it.
        view.setBackground(HostMaterial(values[VisualElementContract.background]?.propValue).painted)
        view.setOutline(
            stroke: values[BorderElementContract.stroke]?.propValue,
            width: values[BorderElementContract.lineWidth],
            shape: values[BorderElementContract.shape]?.propValue,
            clips: values[LayoutContract.clipsContent] ?? false)
    }

    /// What both stacks take: the space between their children, and the space inside their own edge.
    private static let stackMembers: [any ContractMember] = [
        StackContract.spacing, PaddingElementContract.padding,
    ]

    private static func applyStack<Realized: ElementContract>(_ view: WinUIStackView, _ values: ElementValues<Realized>) {
        view.spacing = values[StackContract.spacing] ?? 0
        view.padding = values[PaddingElementContract.padding] ?? Insets(0)
    }
}
