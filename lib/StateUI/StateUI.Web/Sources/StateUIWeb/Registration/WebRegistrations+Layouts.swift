// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// The stacks, the grid and the ZStack: the room a layout leaves around and between its children, and the box it
    /// paints.
    static func layouts(_ registry: Registry<WebDOMView>) {
        registry.add(VStackContract.self, create: { _ in WebLayoutView(arrangement: .stack(.vertical)) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.applies(boxMembers) { view, values in applyBox(view, values) }
            stack.property(LayoutContract.letsInputThrough) { view, lets in view.setLetsInputThrough(lets ?? false) }
        }

        registry.add(HStackContract.self, create: { _ in WebLayoutView(arrangement: .stack(.horizontal)) }) { stack in
            stack.applies(stackMembers) { view, values in applyStack(view, values) }
            stack.applies(boxMembers) { view, values in applyBox(view, values) }
            stack.property(LayoutContract.letsInputThrough) { view, lets in view.setLetsInputThrough(lets ?? false) }
        }

        registry.add(GridContract.self, create: { _ in WebLayoutView(arrangement: .grid) }) { grid in
            grid.applies([
                GridContract.rows, GridContract.columns, GridContract.rowSpacing, GridContract.columnSpacing,
                PaddingElementContract.padding,
            ]) { view, values in
                view.setTracks(rows: values[GridContract.rows] ?? [], columns: values[GridContract.columns] ?? [])
                view.setGridSpacing(rows: values[GridContract.rowSpacing] ?? 0, columns: values[GridContract.columnSpacing] ?? 0)
                view.setPadding(values[PaddingElementContract.padding])
            }
            grid.applies(boxMembers) { view, values in applyBox(view, values) }
            grid.property(LayoutContract.letsInputThrough) { view, lets in view.setLetsInputThrough(lets ?? false) }
        }

        registry.add(ZStackContract.self, create: { _ in WebLayoutView(arrangement: .layers) }) { layers in
            layers.property(PaddingElementContract.padding) { view, padding in view.setPadding(padding) }
            layers.applies(boxMembers) { view, values in applyBox(view, values) }
            layers.property(LayoutContract.letsInputThrough) { view, lets in view.setLetsInputThrough(lets ?? false) }
        }
        // Where the user moves it is reported by the element, on the display's frames.
        // Design: docs/design/platforms/web/layout.md#scrolling
        registry.add(ScrollViewContract.self, create: { _ in WebScrollView() }) { scroll in
            scroll.applies([
                ScrollViewContract.orientation, ScrollViewContract.verticalScrollIndicator,
                ScrollViewContract.horizontalScrollIndicator, ScrollViewContract.scrollOffset,
                PaddingElementContract.padding,
            ]) { view, values in
                let orientation = values[ScrollViewContract.orientation] ?? .vertical
                let bars = orientation == .horizontal
                    ? values[ScrollViewContract.horizontalScrollIndicator] : values[ScrollViewContract.verticalScrollIndicator]
                view.apply(
                    orientation: orientation, bars: bars ?? .automatic,
                    offset: values.changed(ScrollViewContract.scrollOffset) ? values[ScrollViewContract.scrollOffset] : nil)
                view.setPadding(values[PaddingElementContract.padding])
            }
            scroll.applies(scrollerBoxMembers) { view, values in
                // A scroller cuts what it shows to its bounds always.
                view.setBox(
                    fill: values[VisualElementContract.background]?.propValue,
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    lineWidth: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue,
                    clips: false)
            }
            scroll.raises(ScrollViewContract.scrollXChanged)
            scroll.raises(ScrollViewContract.scrollYChanged)
            scroll.raises(ScrollViewContract.scrollStopped)
        }
    }

    /// What a scroller takes of its own box: what fills it, its outline and its shape.
    private static let scrollerBoxMembers: [any ContractMember] = [
        VisualElementContract.background,
        BorderElementContract.stroke, BorderElementContract.lineWidth, BorderElementContract.shape,
    ]

    /// What every layout takes of its own box: what fills it, its outline, its shape and its cut.
    private static let boxMembers: [any ContractMember] = [
        BorderElementContract.backdrop, VisualElementContract.background,
        BorderElementContract.stroke, BorderElementContract.lineWidth, BorderElementContract.shape,
        LayoutContract.clipsContent,
    ]

    private static func applyBox<Realized: ElementContract>(_ view: WebLayoutView, _ values: ElementValues<Realized>) {
        view.setBox(
            backdrop: values[BorderElementContract.backdrop]?.propValue,
            fill: values[VisualElementContract.background]?.propValue,
            stroke: values[BorderElementContract.stroke]?.propValue,
            lineWidth: values[BorderElementContract.lineWidth],
            shape: values[BorderElementContract.shape]?.propValue,
            clips: values[LayoutContract.clipsContent] ?? false)
    }

    /// What both stacks take: the space between their children, and the space inside their own edge.
    private static let stackMembers: [any ContractMember] = [
        StackContract.spacing, PaddingElementContract.padding,
    ]

    private static func applyStack<Realized: ElementContract>(_ view: WebLayoutView, _ values: ElementValues<Realized>) {
        view.setSpacing(values[StackContract.spacing] ?? 0)
        view.setPadding(values[PaddingElementContract.padding])
    }
}
