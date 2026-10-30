// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// The stacks, the grid and the ZStack: the room a layout leaves around and between its children, the box it
    /// paints, and whether a click beside its children goes on to what is under it.
    static func layouts(_ registry: Registry<GTKView>) {
        registry.add(VStackContract.self, create: { _ in GTKStackView(axis: .vertical) }) { stack in
            stack.applies(LayoutMembers.stackMembers) { view, values in applyStack(view, values) }
            stack.applies(LayoutMembers.boxMembers) { view, values in applyBox(view, values) }
            stack.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }

        registry.add(HStackContract.self, create: { _ in GTKStackView(axis: .horizontal) }) { stack in
            stack.applies(LayoutMembers.stackMembers) { view, values in applyStack(view, values) }
            stack.applies(LayoutMembers.rowMembers) { view, values in view.lines = StackArithmetic.Lines(values) }
            stack.applies(LayoutMembers.boxMembers) { view, values in applyBox(view, values) }
            stack.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }

        registry.add(GridContract.self, create: { _ in GTKGridView() }) { grid in
            grid.applies(
                GridContract.rows, GridContract.columns, GridContract.rowSpacing, GridContract.columnSpacing,
                PaddingElementContract.padding) { view, values in
                view.rows = values[GridContract.rows] ?? []
                view.columns = values[GridContract.columns] ?? []
                view.rowSpacing = values[GridContract.rowSpacing] ?? 0
                view.columnSpacing = values[GridContract.columnSpacing] ?? 0
                view.padding = values[PaddingElementContract.padding] ?? Insets(0)
            }
            grid.applies(LayoutMembers.boxMembers) { view, values in applyBox(view, values) }
            grid.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }

        // A space is a box of its own the stack's arithmetic sizes, drawn as a layout's box; a separator in a stack is
        // GTK's separator, which the host makes across its stack.
        // Design: docs/design/host/layout.md#a-space
        registry.add(SpaceContract.self, create: { _ in GTKZStackView() }) { space in
            space.applies(LayoutMembers.regionMembers) { view, values in applyBox(view, values) }
        }
        registry.add(SeparatorContract.self, madeByHost: GTKSeparatorView.self) { _ in }

        registry.add(ZStackContract.self, create: { _ in GTKZStackView() }) { layout in
            layout.property(PaddingElementContract.padding) { view, padding in view.padding = padding ?? Insets(0) }
            layout.applies(LayoutMembers.boxMembers) { view, values in applyBox(view, values) }
            layout.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }

        // A fill is a box of its own that holds nothing, drawn as a layout's box.
        // Design: docs/design/host/layout.md#a-fill
        registry.add(FillContract.self, create: { _ in GTKZStackView() }) { fill in
            fill.applies(LayoutMembers.regionMembers) { view, values in applyBox(view, values) }
        }

        // A motion layout stands on the ZStack: its children where its run of placements puts them.
        registry.add(MotionLayoutContract.self, create: { _ in
            let layout = GTKZStackView()
            layout.motionLayout = true
            return layout
        }) { layout in
            layout.applies(LayoutMembers.boxMembers) { view, values in applyBox(view, values) }
            layout.property(LayoutContract.letsInputThrough) { view, lets in view.passesBeside = lets ?? false }
        }

        // Where the user moves it is reported by the element, on the display's frames.
        // Design: docs/design/platforms/gtk/layout.md#scrolling
        registry.add(ScrollViewContract.self, create: { _ in GTKScrollView() }) { scroll in
            scroll.applies(
                ScrollViewContract.orientation, ScrollViewContract.verticalScrollIndicator,
                ScrollViewContract.horizontalScrollIndicator, ScrollViewContract.scrollOffset,
                PaddingElementContract.padding) { view, values in
                view.apply(
                    orientation: values[ScrollViewContract.orientation] ?? .vertical,
                    padding: values[PaddingElementContract.padding] ?? Insets(0),
                    verticalBar: values[ScrollViewContract.verticalScrollIndicator] ?? .automatic,
                    horizontalBar: values[ScrollViewContract.horizontalScrollIndicator] ?? .automatic,
                    offset: values.changed(ScrollViewContract.scrollOffset) ? values[ScrollViewContract.scrollOffset] : nil)
            }
            scroll.applies(
                VisualElementContract.background, BorderElementContract.shape, BorderElementContract.stroke,
                BorderElementContract.lineWidth) { view, values in
                // A scroller cuts what it shows to its bounds; a shape cuts it to the shape.
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


    private static func applyBox<Realized: ElementContract>(_ view: GTKLayoutView, _ values: ElementValues<Realized>) {
        // GTK blurs nothing behind a widget: the material's color stands in, under the fill.
        view.setBackground(HostMaterial(values[VisualElementContract.background]?.propValue).painted)
        view.setOutline(
            stroke: values[BorderElementContract.stroke]?.propValue,
            width: values[BorderElementContract.lineWidth],
            shape: values[BorderElementContract.shape]?.propValue,
            clips: values[LayoutContract.clipsContent] ?? false)
    }


    private static func applyStack<Realized: ElementContract>(_ view: GTKStackView, _ values: ElementValues<Realized>) {
        view.spacing = values[StackContract.spacing] ?? 0
        view.padding = values[PaddingElementContract.padding] ?? Insets(0)
    }
}
