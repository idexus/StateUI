// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The children a layout engine stands: each view in a holder the run places, and the scroll that lies over them.
// Design: docs/design/views/layout-engine.md#the-element

extension LayoutEngine.Run {
    /// One view inside the holder the run places, so the author's own properties on the view are never overwritten
    /// by a frame of arithmetic; a shade is the holder's second child.
    func wrapped(_ slot: LayoutEngine.Slot) -> ModifiedContent {
        let holder = Grid { BuiltViews(nodes: [make(slot.item)] + (mask.map { [$0] } ?? [])) }

        // Under a scroll the views take no touches: the scroller over them takes every one.
        if scrolls { return ModifiedContent(node: holder.ignoresInput(true).node) }

        // A holder lets input through where its view is not: the layout's own empty room is the layout's to answer.
        guard let tapped else { return ModifiedContent(node: holder.letsInputThrough(true).node) }

        let item = slot.item
        return ModifiedContent(node: holder.onTapped(gate: tapped.gate) { try await tapped.run(item) }.node)
    }

    /// The scroll over the views: an empty scroller whose offset is the phase.
    /// Design: docs/design/views/layout-engine.md#the-hand
    func scroller() -> ModifiedContent {
        let run = self

        return ModifiedContent(node: GeometryReader { room in
            let scroll = ScrollView { run.content(in: room) }
                .orientation(run.across ? .horizontal : .vertical)
                .horizontalScrollIndicator(.never)
                .verticalScrollIndicator(.never)
                .scrollOffset(run.states.scrolled.projectedValue)
                .onScrollStopped { run.settle() }

            // The drag is heard on the scroller, which stands still while its content slides under the hand.
            if run.drags {
                scroll.onPanUpdated { pan in run.drag(pan) }
            } else {
                scroll
            }
        }
        .onFrameChanged { run.framed($0) }
        .node)
    }

    /// The scroller's content: nothing to see, only a length - the room plus how far the run goes beyond it. Across
    /// the axis it is one unit, or the room where a tap has to land on it; a size worked out from the measured room
    /// does not travel.
    func content(in room: Rect) -> ModifiedContent {
        let wide = across ? max(room.width, 1) + reach : (tapped == nil ? 1 : max(room.width, 1))
        let tall = across ? (tapped == nil ? 1 : max(room.height, 1)) : max(room.height, 1) + reach
        let run = self

        guard let tapped else {
            return ModifiedContent(node: Rectangle(.transparent)
                .width(wide)
                .height(tall)
                .motion(.none)
                .reporting(laid: states.length.projectedValue)
                .node)
        }

        let stack = PlacedStack {
            ForEach(Array(0...self.items.count), id: \.self) { box in run.box(box, tapped: tapped) }
        }
        let placed = stack.setValue(ViewContract.area.token, on: states.boxes.projectedValue, mode: .out, kind: .placement)

        return ModifiedContent(node: placed
            .width(wide)
            .height(tall)
            .motion(.none, .size)
            .reporting(laid: states.length.projectedValue)
            .node)
    }

    /// One box of the scroller's content: its length first, then one under each view, where a tap on it lands.
    func box(_ index: Int, tapped: ValueHandler<Items.Element>) -> Rectangle {
        var tap: Handler?
        if index > 0 {
            let item = items[index - 1]
            let run = tapped.run
            tap = Handler(run: { try await run(item) }, gate: tapped.gate)
        }

        return Rectangle(.transparent).motion(.none).tapping(tap)
    }
}

extension VisualElement where Modified == Self {
    /// The element reporting where it is laid out onto `state`, where one was given.
    func reporting(laid state: Binding<Rect>?) -> Self {
        state.map { frame($0) } ?? self
    }
}

extension Rectangle {
    /// The box answering a tap, where one was asked for.
    func tapping(_ handler: Handler?) -> Rectangle {
        guard let handler else { return self }

        return onTapped(gate: handler.gate, handler.run)
    }
}

