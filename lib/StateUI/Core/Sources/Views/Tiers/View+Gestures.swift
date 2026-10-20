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
        modified {
            $0.hearsTaps(1)
            $0.addHandler(ViewContract.tapped.token, handler)
        }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onTapped(gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        modified {
            $0.hearsTaps(1)
            $0.addHandler(ViewContract.tapped.token, gate: gate, handler)
        }
    }

    /// The same, for a double tap or more: `count` taps in a row.
    ///
    ///     Text("Reset").onTapped(count: 2) { taps = 0 }
    public func onTapped(count: Int, _ handler: @escaping @MainActor () throws -> Void) -> Modified {
        // One `modified`: chaining would return `Modified.Modified`.
        modified {
            $0.hearsTaps(count)
            $0.addHandler(ViewContract.tapped.token, handler)
        }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onTapped(count: Int, gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        modified {
            $0.hearsTaps(count)
            $0.addHandler(ViewContract.tapped.token, gate: gate, handler)
        }
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
        modified {
            $0.hearsSwipes(direction, threshold: threshold)
            $0.addHandler(ViewContract.swiped.token) {
                // A payload that does not read leaves the handler alone, and so does a direction it did not ask for.
                if let went = SwipeDirection(EventBuffer.current.value()), direction.contains(went) {
                    try handler(went)
                }
            }
        }
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
            $0.hearsSwipes(direction, threshold: threshold)
            $0.addHandler(ViewContract.swiped.token, gate: gate) {
                if let went = SwipeDirection(EventBuffer.current.value()), direction.contains(went) {
                    try await handler(went)
                }
            }
        }
    }

    // MARK: Pan

    /// Writes how far the view has been dragged across into a state, with no
    /// view rebuilt as it moves.
    ///
    ///     @State private var turn = 0.0
    ///
    ///     Rectangle().fill(.transparent).panX($turn)
    ///
    /// The distance `onPanUpdated` reports, for an `.engine(following:)` to
    /// follow frame by frame. A drag moves the value on from where it stood, so
    /// a second drag carries on where the first left off.
    ///
    /// - Parameter state: the state the distance is written into.
    /// - Returns: the view, reporting there.
    public func panX(_ state: Binding<Double>) -> Modified {
        driven(ViewContract.panXChannel.token, by: state)
    }

    /// Writes how far the view has been dragged down into a state, with no view
    /// rebuilt as it moves; see `panX(_:)`.
    ///
    ///     Rectangle().fill(.transparent).panY($turn)
    ///
    /// - Parameter state: the state the distance is written into.
    /// - Returns: the view, reporting there.
    public func panY(_ state: Binding<Double>) -> Modified {
        driven(ViewContract.panYChannel.token, by: state)
    }

    /// Runs as the view is dragged, from the moment it starts until it is let
    /// go.
    ///
    ///     Rectangle().fill(.cornflowerBlue)
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
        modified {
            $0.hearsPans(touchCount)
            $0.addHandler(ViewContract.panUpdated.token) {
                if let (phase, totalX, totalY) = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.panUpdated.name,
                    as: GesturePhase.self, Double.self, Double.self) {
                    try handler(PanUpdate(phase: phase, totalX: totalX, totalY: totalY))
                }
            }
        }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPanUpdated(
        touchCount: Int? = nil,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> Modified {
        modified {
            $0.hearsPans(touchCount)
            $0.addHandler(ViewContract.panUpdated.token, gate: gate) {
                if let (phase, totalX, totalY) = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.panUpdated.name,
                    as: GesturePhase.self, Double.self, Double.self) {
                    try await handler(PanUpdate(phase: phase, totalX: totalX, totalY: totalY))
                }
            }
        }
    }

    // MARK: Pinch

    /// Runs as two fingers move apart or together.
    ///
    /// `scale` is relative - the change since the last report, not since the
    /// pinch began - so a view being pinched multiplies rather than assigns.
    public func onPinchUpdated(_ handler: @escaping @MainActor (PinchUpdate) throws -> Void) -> Modified {
        onEvent(ViewContract.pinchUpdated) { phase, scale, origin in
            try handler(PinchUpdate(phase: phase, scale: scale, scaleOrigin: origin))
        }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPinchUpdated(gate: some Gate, _ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        onEvent(ViewContract.pinchUpdated, gate: gate) { phase, scale, origin in
            try await handler(PinchUpdate(phase: phase, scale: scale, scaleOrigin: origin))
        }
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

    /// Runs when a pointer leaves the view - the other half of a hover.
    public func onPointerExited(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.pointerExited, handler)
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerExited(gate: some Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerExited, gate: gate, handler)
    }

    /// Runs as the pointer moves over the view, with where it is in the view's
    /// own coordinates; a move the platform gives no position for does not run
    /// it.
    public func onPointerMoved(_ handler: @escaping @MainActor (Point) throws -> Void) -> Modified {
        onEvent(ViewContract.pointerMoved) { point in
            if let point {
                try handler(point)
            }
        }
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

    /// Runs when a pointer button goes down over the view, with where it went
    /// down in the view's own coordinates.
    public func onPointerPressed(_ handler: @escaping @MainActor (Point) throws -> Void) -> Modified {
        onEvent(ViewContract.pointerPressed) { point in
            if let point {
                try handler(point)
            }
        }
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

    /// Runs when the pointer button comes back up, with where it came up.
    public func onPointerReleased(_ handler: @escaping @MainActor (Point) throws -> Void) -> Modified {
        onEvent(ViewContract.pointerReleased) { point in
            if let point {
                try handler(point)
            }
        }
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
                $0.addHandler(ViewContract.dragStarting.token, onDragStarting)
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

    /// Accepts what is dropped on the view, with the text it carried.
    ///
    ///     VStack { … }
    ///         .onDrop { text in items.append(text) }
    public func onDrop(_ handler: @escaping @MainActor (String) throws -> Void) -> Modified {
        modified {
            $0.write(ViewContract.allowsDrop, true)
            $0.addHandler(ViewContract.drop.token) {
                if let text = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.drop.name, as: String.self) {
                    try handler(text)
                }
            }
        }
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
        modified {
            $0.takesFiles(types)
            $0.addHandler(ViewContract.filesDropped.token) {
                if let files = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.filesDropped.name, as: [ChosenFile].self)?
                    .filter({ $0.isOne(of: types) }), !files.isEmpty {
                    try handler(files)
                }
            }
        }
    }

    /// The same, with a handler that awaits - reading a file does: its `gate` says what a drop does while a
    /// run is under way.
    public func onDrop(
        files types: [FileType] = [], gate: some Gate, _ handler: @escaping ValueEventHandler<[ChosenFile]>
    ) -> Modified {
        modified {
            $0.takesFiles(types)
            $0.addHandler(ViewContract.filesDropped.token, gate: gate) {
                if let files = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.filesDropped.name, as: [ChosenFile].self)?
                    .filter({ $0.isOne(of: types) }), !files.isEmpty {
                    try await handler(files)
                }
            }
        }
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
}

// What one view hears of a gesture is the sum of what its handlers asked, each hearing its own.
// Design: docs/design/views/modifiers.md#gestures
extension Node {
    /// Listens for `direction` beside the directions it listens for already; a second threshold is said.
    fileprivate mutating func hearsSwipes(_ direction: SwipeDirection, threshold: Double?) {
        let heard = props[ViewContract.swipeDirection.token].flatMap(SwipeDirection.init(propValue:)) ?? []
        write(ViewContract.swipeDirection, heard.union(direction))

        guard let threshold else { return }
        if let said = props[ViewContract.swipeThreshold.token].flatMap(Double.init(propValue:)), said != threshold {
            complain("A view hears swipes of one threshold: \(said) and \(threshold) were asked on it, and the "
                + "last stands.")
        }
        describe(ViewContract.swipeThreshold, threshold)
    }

    /// Hears taps of `count`; a view asked for two counts is said, as it hears one.
    fileprivate mutating func hearsTaps(_ count: Int) {
        let said = props[ViewContract.tapCount.token].flatMap(Int.init(propValue:))
            ?? (events[ViewContract.tapped.token] != nil ? 1 : nil)

        if let said, said != count {
            complain("A view hears taps of one count: \(said) and \(count) were asked on it, and the last "
                + "stands. Put the other on a view of its own.")
        }
        if count != 1 || said != nil { write(ViewContract.tapCount, count) }
    }

    /// Hears pans of `touchCount`, a pan saying none keeping the one said; a view asked for two is said.
    fileprivate mutating func hearsPans(_ touchCount: Int?) {
        guard let touchCount else { return }
        if let said = props[ViewContract.panTouchCount.token].flatMap(Int.init(propValue:)), said != touchCount {
            complain("A view hears pans of one touch count: \(said) and \(touchCount) were asked on it, and "
                + "the last stands. Put the other on a view of its own.")
        }
        describe(ViewContract.panTouchCount, touchCount)
    }

    /// Takes files of `types` beside those it takes already; no types is any file.
    fileprivate mutating func takesFiles(_ types: [FileType]) {
        guard let taken = props[ViewContract.droppedFileTypes.token].flatMap([FileType].init(propValue:)) else {
            return write(ViewContract.droppedFileTypes, types)
        }
        write(ViewContract.droppedFileTypes, taken.isEmpty || types.isEmpty ? [] : taken + types.filter { !taken.contains($0) })
    }
}

extension ChosenFile {
    /// Whether the file is of one of `types` by its extension; no types is any file.
    fileprivate func isOne(of types: [FileType]) -> Bool {
        guard !types.isEmpty else { return true }
        let ending = name.split(separator: ".").count > 1 ? name.split(separator: ".").last.map { $0.lowercased() } : nil
        return types.contains { type in ending.map(type.extensions.contains) ?? false }
    }
}
