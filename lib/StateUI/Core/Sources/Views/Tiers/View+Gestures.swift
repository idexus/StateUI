// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The gestures a view hears.
// Design: docs/design/views/modifiers.md#gestures

extension View {
    // MARK: Tap

    /// Runs when the view is tapped by the platform's native recognizer.
    ///
    ///     HStack { … }
    ///         .onTapped { path.append(.details(id)) }
    ///
    /// The whole view answers, not a button inside it.
    public func onTapped(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.tapped, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onTapped(gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.tapped, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onTapped(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onTapped(_ handler: @escaping EventHandler) -> Modified {
        fatalError("unavailable")
    }

    /// The same, for a double tap or more: `count` taps in a row.
    ///
    ///     Text("Reset").onTapped(count: 2) { taps = 0 }
    public func onTapped(count: Int, _ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onTapped(count: count, gate: .none) { try handler() }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onTapped(count: Int, gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        // One `modified`: chaining would return `Modified.Modified`.
        modified {
            $0.write(ViewContract.tapCount, count)
            $0.addHandler(ViewContract.tapped.token, gate: gate, handler)
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onTapped(count: count, gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onTapped(count: Int, _ handler: @escaping EventHandler) -> Modified {
        fatalError("unavailable")
    }

    // MARK: Swipe

    /// Runs when the view is swiped, with the one dominant direction it went.
    ///
    ///     VStack { … }
    ///         .onSwiped(direction: [.left, .right]) { direction in
    ///             if direction == .left { items.removeLast() }
    ///         }
    ///
    /// - Parameters:
    ///   - direction: which ways to listen for. A view that listens for nothing
    ///     recognizes nothing, so the default is every direction.
    ///   - threshold: how far a swipe must travel to count, in device units.
    ///   - handler: what to run, given the direction the swipe went.
    public func onSwiped(
        direction: SwipeDirection = .all,
        threshold: Double? = nil,
        _ handler: @escaping @MainActor (SwipeDirection) throws -> Void
    ) -> Modified {
        onSwiped(direction: direction, threshold: threshold, gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onSwiped(
        direction: SwipeDirection = .all,
        threshold: Double? = nil,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<SwipeDirection>
    ) -> Modified {
        modified {
            $0.write(ViewContract.swipeDirection, direction)
            $0.describe(ViewContract.swipeThreshold, threshold)
            $0.addHandler(ViewContract.swiped.token, gate: gate) {
                // A payload that does not read leaves the handler alone.
                if let direction = SwipeDirection(EventBuffer.current.value()) {
                    try await handler(direction)
                }
            }
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onSwiped(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onSwiped(
        direction: SwipeDirection = .all,
        threshold: Double? = nil,
        _ handler: @escaping ValueEventHandler<SwipeDirection>
    ) -> Modified {
        fatalError("unavailable")
    }

    // MARK: Pan

    /// Writes how far the view has been dragged across into a state, with no
    /// view rebuilt as it moves.
    ///
    ///     @State private var turn = 0.0
    ///
    ///     ColorBox(.transparent).panX($turn)
    ///
    /// The distance `onPanUpdated` reports, for an `.engine(following:)` to
    /// follow frame by frame. A drag moves the value on from where it stood, so
    /// a second drag carries on where the first left off.
    ///
    /// - Parameter value: the state the distance is written into.
    /// - Returns: the view, reporting there.
    public func panX(_ value: Binding<Double>) -> Modified {
        driven(ViewContract.panXChannel.token, by: value)
    }

    /// Writes how far the view has been dragged down into a state, with no view
    /// rebuilt as it moves; see `panX(_:)`.
    ///
    ///     ColorBox(.transparent).panY($turn)
    ///
    /// - Parameter value: the state the distance is written into.
    /// - Returns: the view, reporting there.
    public func panY(_ value: Binding<Double>) -> Modified {
        driven(ViewContract.panYChannel.token, by: value)
    }

    /// Runs as the view is dragged, from the moment it starts until it is let
    /// go.
    ///
    ///     ColorBox(.cornflowerBlue)
    ///         .translationX(offsetX)
    ///         .onPanUpdated { pan in
    ///             if pan.phase == .changed { offsetX = pan.totalX }
    ///         }
    ///
    /// The totals are measured from where the pan began.
    ///
    /// - Parameters:
    ///   - touchCount: how many simultaneous pointers the host must require. A
    ///     host that cannot distinguish that count does not recognize the
    ///     gesture when the requested count is unsupported.
    ///   - handler: what to run on each update, given where the pan stands.
    public func onPanUpdated(
        touchCount: Int? = nil,
        _ handler: @escaping @MainActor (PanUpdate) throws -> Void
    ) -> Modified {
        onPanUpdated(touchCount: touchCount, gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPanUpdated(
        touchCount: Int? = nil,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> Modified {
        modified {
            $0.describe(ViewContract.panTouchCount, touchCount)
            $0.addHandler(ViewContract.panUpdated.token, gate: gate) {
                if let (phase, totalX, totalY) = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.panUpdated.name,
                    as: GesturePhase.self, Double.self, Double.self) {
                    try await handler(PanUpdate(phase: phase, totalX: totalX, totalY: totalY))
                }
            }
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPanUpdated(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPanUpdated(
        touchCount: Int? = nil,
        _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> Modified {
        fatalError("unavailable")
    }

    // MARK: Pinch

    /// Runs as two fingers move apart or together.
    ///
    /// `scale` is relative - the change since the last report, not since the
    /// pinch began - so a view being pinched multiplies rather than assigns.
    public func onPinchUpdated(_ handler: @escaping @MainActor (PinchUpdate) throws -> Void) -> Modified {
        onPinchUpdated(gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPinchUpdated(gate: some Gate, _ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        onEvent(ViewContract.pinchUpdated, gate: gate) { phase, scale, origin in
            try await handler(PinchUpdate(phase: phase, scale: scale, scaleOrigin: origin))
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPinchUpdated(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPinchUpdated(_ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        fatalError("unavailable")
    }

    // MARK: Pointer

    /// Runs when a pointer enters the view.
    ///
    /// A pointer is a mouse, a trackpad or a pen; on a touch-only device these
    /// never fire.
    public func onPointerEntered(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.pointerEntered, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerEntered(gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerEntered, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPointerEntered(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPointerEntered(_ handler: @escaping EventHandler) -> Modified {
        fatalError("unavailable")
    }

    /// Runs when a pointer leaves the view - the other half of a hover.
    public func onPointerExited(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.pointerExited, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerExited(gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerExited, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPointerExited(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPointerExited(_ handler: @escaping EventHandler) -> Modified {
        fatalError("unavailable")
    }

    /// Runs as the pointer moves over the view, with where it is in the view's
    /// own coordinates; a move the platform gives no position for does not run
    /// it.
    public func onPointerMoved(_ handler: @escaping @MainActor (Point) throws -> Void) -> Modified {
        onPointerMoved(gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerMoved(gate: some Gate, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerMoved, gate: gate) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPointerMoved(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPointerMoved(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        fatalError("unavailable")
    }

    /// Runs when a pointer button goes down over the view, with where it went
    /// down in the view's own coordinates.
    public func onPointerPressed(_ handler: @escaping @MainActor (Point) throws -> Void) -> Modified {
        onPointerPressed(gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerPressed(gate: some Gate, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerPressed, gate: gate) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPointerPressed(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPointerPressed(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        fatalError("unavailable")
    }

    /// Runs when the pointer button comes back up, with where it came up.
    public func onPointerReleased(_ handler: @escaping @MainActor (Point) throws -> Void) -> Modified {
        onPointerReleased(gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerReleased(gate: some Gate, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerReleased, gate: gate) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPointerReleased(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPointerReleased(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        fatalError("unavailable")
    }

    // MARK: Drag and drop

    /// Makes the view draggable, carrying `text` with it.
    ///
    ///     Text(item)
    ///         .draggable(text: item)
    ///
    /// Text is the portable drag payload. `onDragStarting` runs when the drag
    /// starts, too late to decide what is carried: a native drag needs its
    /// payload at once.
    public func draggable(
        text: String,
        canDrag: Bool = true,
        onDragStarting: (@MainActor () throws -> Void)? = nil
    ) -> Modified {
        modified {
            $0.write(ViewContract.dragText, text)
            $0.write(ViewContract.canDrag, canDrag)

            if let onDragStarting = onDragStarting {
                $0.addHandler(ViewContract.dragStarting.token, gate: .none) { try onDragStarting() }
            }
        }
    }

    /// Runs when a drag that started here ends, wherever it ended.
    public func onDragEnded(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.dragEnded, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onDragEnded(gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragEnded, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onDragEnded(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onDragEnded(_ handler: @escaping EventHandler) -> Modified {
        fatalError("unavailable")
    }

    /// Accepts what is dropped on the view, with the text it carried.
    ///
    ///     VStack { … }
    ///         .onDrop { text in items.append(text) }
    public func onDrop(_ handler: @escaping @MainActor (String) throws -> Void) -> Modified {
        onDrop(gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onDrop(gate: some Gate, _ handler: @escaping ValueEventHandler<String>) -> Modified {
        modified {
            $0.write(ViewContract.allowsDrop, true)
            $0.addHandler(ViewContract.drop.token, gate: gate) {
                if let text = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.drop.name, as: String.self) {
                    try await handler(text)
                }
            }
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onDrop(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onDrop(_ handler: @escaping ValueEventHandler<String>) -> Modified {
        fatalError("unavailable")
    }

    /// Accepts files the user drops on the view from the system - of
    /// `types`, any file where none is given - with those dropped.
    ///
    ///     Text("Drop a report here")
    ///         .onDrop(files: [FileType("Text", extensions: ["txt"])], gate: .ignoreWhileRunning) { files in
    ///             notes = String(decoding: try await files[0].read(), as: UTF8.self)
    ///         }
    ///
    /// A dropped file reads and launches as one the user opened
    /// (`ChosenFile`); files of other kinds are not taken.
    public func onDrop(
        files types: [FileType] = [], _ handler: @escaping @MainActor ([ChosenFile]) throws -> Void
    ) -> Modified {
        onDrop(files: types, gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits - reading a file does: its `gate` says what a drop does while a
    /// run is under way.
    public func onDrop(
        files types: [FileType] = [], gate: some Gate, _ handler: @escaping ValueEventHandler<[ChosenFile]>
    ) -> Modified {
        modified {
            $0.write(ViewContract.droppedFileTypes, types)
            $0.addHandler(ViewContract.filesDropped.token, gate: gate) {
                if let files = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.filesDropped.name, as: [ChosenFile].self) {
                    try await handler(files)
                }
            }
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onDrop(files: types, gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onDrop(files types: [FileType] = [], _ handler: @escaping ValueEventHandler<[ChosenFile]>) -> Modified {
        fatalError("unavailable")
    }

    /// Runs while a drag is over the view, before it is let go.
    public func onDragOver(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.dragOver, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onDragOver(gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragOver, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onDragOver(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onDragOver(_ handler: @escaping EventHandler) -> Modified {
        fatalError("unavailable")
    }

    /// Runs when a drag leaves the view without being let go - the mirror of
    /// `onDragOver`, and where a highlight put up there is taken down.
    public func onDragLeave(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.dragLeave, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onDragLeave(gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragLeave, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onDragLeave(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onDragLeave(_ handler: @escaping EventHandler) -> Modified {
        fatalError("unavailable")
    }
}
