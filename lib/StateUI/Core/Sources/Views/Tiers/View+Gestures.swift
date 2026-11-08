// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The gestures a view hears.
// Design: docs/design/views/modifiers.md#gestures

extension View {
    // MARK: Tap

    /// Runs when the view is tapped by the platform's native recognizer: `count` taps in a row, one until told
    /// otherwise.
    ///
    ///     HStack { … }
    ///         .onTapped { path.append(.details(id)) }
    ///
    ///     Text("Reset").onTapped(count: 2) { taps = 0 }
    ///
    /// The whole view answers, not a button inside it.
    public func onTapped(count: Int = 1, _ handler: @escaping @MainActor () throws -> Void) -> Modified {
        // One `modified`: chaining would return `Modified.Modified`.
        modified {
            $0.hearsTaps(count)
            $0.addHandler(ViewContract.tapped.token, handler)
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onTapped(count: Int = 1, policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        modified {
            $0.hearsTaps(count)
            $0.addHandler(ViewContract.tapped.token, gate: .own(policy), handler)
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onTapped(count: Int = 1, gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        modified {
            $0.hearsTaps(count)
            $0.addHandler(ViewContract.tapped.token, gate: .shared(gate), handler)
        }
    }

    // MARK: Hold

    /// Runs when the user holds the view down - a finger, a pen or a button
    /// pressed and kept still - once the press has stood still `minimum`, or
    /// as long as the platform's long press where it is nil, the default.
    ///
    ///     Photo(item)
    ///         .onHeld { selection.insert(item.id) }
    ///
    ///     Photo(item).onHeld(minimum: .milliseconds(800)) { showActions(for: item) }
    ///
    /// A press held is the hold's: its release is no tap, and it drags nothing.
    public func onHeld(minimum: Duration? = nil, _ handler: @escaping @MainActor () throws -> Void) -> Modified {
        modified {
            $0.hearsHolds(minimum)
            $0.addHandler(ViewContract.held.token, handler)
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onHeld(minimum: Duration? = nil, policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        modified {
            $0.hearsHolds(minimum)
            $0.addHandler(ViewContract.held.token, gate: .own(policy), handler)
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onHeld(minimum: Duration? = nil, gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        modified {
            $0.hearsHolds(minimum)
            $0.addHandler(ViewContract.held.token, gate: .shared(gate), handler)
        }
    }

    // MARK: Swipe

    /// Runs when the view is swiped, with the one dominant direction it went.
    ///
    ///     VStack { … }
    ///         .onSwiped(directions: [.left, .right]) { direction in
    ///             if direction == .left { items.removeLast() }
    ///         }
    ///
    /// - Parameters:
    ///   - directions: which ways to listen for. A view that listens for nothing
    ///     recognizes nothing, so the default is every direction.
    ///   - threshold: how far a swipe must travel to count, in device units.
    ///   - handler: what to run, given the direction the swipe went.
    public func onSwiped(
        directions: SwipeDirections = .all,
        threshold: Double? = nil,
        _ handler: @escaping @MainActor (SwipeDirection) throws -> Void
    ) -> Modified {
        modified {
            $0.hearsSwipes(directions, threshold: threshold)
            $0.addHandler(ViewContract.swiped.token) {
                // A payload that does not read leaves the handler alone, and so does a direction it did not ask for.
                if let went = EventBuffer.current.value().flatMap(SwipeDirection.init(propValue:)), directions.contains(went) {
                    try handler(went)
                }
            }
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onSwiped(
        directions: SwipeDirections = .all,
        threshold: Double? = nil,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<SwipeDirection>
    ) -> Modified {
        modified {
            $0.hearsSwipes(directions, threshold: threshold)
            $0.addHandler(ViewContract.swiped.token, gate: .own(policy), swiped(directions, handler))
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onSwiped(
        directions: SwipeDirections = .all,
        threshold: Double? = nil,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<SwipeDirection>
    ) -> Modified {
        modified {
            $0.hearsSwipes(directions, threshold: threshold)
            $0.addHandler(ViewContract.swiped.token, gate: .shared(gate), swiped(directions, handler))
        }
    }

    // MARK: Pan

    /// Writes how far the view has been dragged across into a state, with no
    /// view rebuilt as it moves.
    ///
    ///     @State private var turn = 0.0
    ///
    ///     Fill()
    ///         .panX($turn)
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
    ///     Fill()
    ///         .panY($turn)
    ///
    /// - Parameter state: the state the distance is written into.
    /// - Returns: the view, reporting there.
    public func panY(_ state: Binding<Double>) -> Modified {
        driven(ViewContract.panYChannel.token, by: state)
    }

    /// Runs as the view is dragged, from the moment it starts until it is let
    /// go.
    ///
    ///     Rectangle()
    ///         .fill(.cornflowerBlue)
    ///         .translationX(offsetX)
    ///         .onPanUpdated { pan in
    ///             if pan.phase == .changed { offsetX = pan.total.x }
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
            $0.addHandler(ViewContract.panUpdated) { phase, total, velocity, at in
                try handler(PanUpdate(phase: phase, total: total, velocity: velocity, at: at))
            }
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPanUpdated(
        touchCount: Int? = nil, policy: GatePolicy, _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> Modified {
        modified {
            $0.hearsPans(touchCount)
            $0.addHandler(ViewContract.panUpdated, policy: policy, panned(handler))
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPanUpdated(
        touchCount: Int? = nil,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> Modified {
        modified {
            $0.hearsPans(touchCount)
            $0.addHandler(ViewContract.panUpdated, gate: gate, panned(handler))
        }
    }

    // MARK: Pinch

    /// Runs as two fingers move apart or together.
    ///
    /// `scale` is how far they have spread since the pinch began, so a
    /// handler scales what it held when the pinch began; `velocity` is how
    /// fast the scale changes.
    public func onPinchUpdated(_ handler: @escaping @MainActor (PinchUpdate) throws -> Void) -> Modified {
        onEvent(ViewContract.pinchUpdated) { phase, scale, pivot, velocity in
            try handler(PinchUpdate(phase: phase, scale: scale, pivot: pivot, velocity: velocity))
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPinchUpdated(policy: GatePolicy, _ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        onEvent(ViewContract.pinchUpdated, policy: policy) { phase, scale, pivot, velocity in
            try await handler(PinchUpdate(phase: phase, scale: scale, pivot: pivot, velocity: velocity))
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPinchUpdated(gate: Gate, _ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        onEvent(ViewContract.pinchUpdated, gate: gate) { phase, scale, pivot, velocity in
            try await handler(PinchUpdate(phase: phase, scale: scale, pivot: pivot, velocity: velocity))
        }
    }

    // MARK: Rotation

    /// Runs as two fingers turn over the view.
    ///
    ///     Image("dial.png")
    ///         .rotation(angle)
    ///         .onRotationUpdated { turn in
    ///             if turn.phase == .began { turned = angle }
    ///             angle = turned + turn.angle
    ///         }
    ///
    /// `angle` is how far they have turned since they began, in degrees
    /// clockwise, so a handler turns what it held when they began.
    public func onRotationUpdated(_ handler: @escaping @MainActor (RotationUpdate) throws -> Void) -> Modified {
        onEvent(ViewContract.rotationUpdated) { phase, angle, velocity in
            try handler(RotationUpdate(phase: phase, angle: angle, velocity: velocity))
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onRotationUpdated(
        policy: GatePolicy, _ handler: @escaping ValueEventHandler<RotationUpdate>
    ) -> Modified {
        onEvent(ViewContract.rotationUpdated, policy: policy) { phase, angle, velocity in
            try await handler(RotationUpdate(phase: phase, angle: angle, velocity: velocity))
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onRotationUpdated(gate: Gate, _ handler: @escaping ValueEventHandler<RotationUpdate>) -> Modified {
        onEvent(ViewContract.rotationUpdated, gate: gate) { phase, angle, velocity in
            try await handler(RotationUpdate(phase: phase, angle: angle, velocity: velocity))
        }
    }

    // MARK: Pointer

    /// Runs when a pointer enters the view.
    ///
    /// A pointer is a mouse, a trackpad or a pen; on a touch-only device these
    /// never fire.
    public func onPointerEntered(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(HoverElementContract.pointerEntered, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerEntered(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(HoverElementContract.pointerEntered, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPointerEntered(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(HoverElementContract.pointerEntered, gate: gate, handler)
    }

    /// Runs when a pointer leaves the view - the other half of a hover.
    public func onPointerExited(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(HoverElementContract.pointerExited, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerExited(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(HoverElementContract.pointerExited, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPointerExited(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(HoverElementContract.pointerExited, gate: gate, handler)
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

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerMoved(policy: GatePolicy, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerMoved, policy: policy) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPointerMoved(gate: Gate, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
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

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerPressed(policy: GatePolicy, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerPressed, policy: policy) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPointerPressed(gate: Gate, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
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

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPointerReleased(policy: GatePolicy, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerReleased, policy: policy) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPointerReleased(gate: Gate, _ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerReleased, gate: gate) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    // MARK: Drag and drop

    /// The text a drag of the view carries: a view carrying text can be dragged.
    ///
    ///     Text(item)
    ///         .dragText(item)
    ///
    /// Text is the portable drag payload, said before any drag starts: a native drag needs its payload at once.
    public func dragText(_ value: String) -> Modified {
        setValue(ViewContract.dragText, value)
    }

    /// `dragText` from a state, `$x`: the host writes each new text, and no view is rebuilt for it.
    public func dragText(_ state: Binding<String>) -> Modified {
        words(ViewContract.dragText, by: state)
    }

    /// Whether the view carrying `dragText` can be dragged now - true unless said.
    ///
    ///     Text(item).dragText(item).isDraggable(!editing)
    public func isDraggable(_ value: Bool) -> Modified {
        setValue(ViewContract.isDraggable, value)
    }

    /// `isDraggable` from a state, `$x`: the host sets each new value as it stands, and no view is rebuilt for it.
    public func isDraggable(_ state: Binding<Bool>) -> Modified {
        twin(ViewContract.isDraggable, by: state)
    }

    /// Runs as a drag of the view starts - too late to change what it carries.
    public func onDragStarting(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.dragStarting, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onDragStarting(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragStarting, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDragStarting(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragStarting, gate: gate, handler)
    }

    /// Runs when a drag that started here ends, wherever it ended.
    public func onDragEnded(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.dragEnded, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onDragEnded(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragEnded, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDragEnded(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragEnded, gate: gate, handler)
    }

    /// Accepts what is dropped on the view, with the text it carried.
    ///
    ///     VStack { … }
    ///         .onDropped { text in items.append(text) }
    public func onDropped(_ handler: @escaping @MainActor (String) throws -> Void) -> Modified {
        modified {
            $0.write(ViewContract.allowsDrop, true)
            $0.addHandler(ViewContract.dropped.token) {
                if let text = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.dropped.name, as: String.self) {
                    try handler(text)
                }
            }
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onDropped(policy: GatePolicy, _ handler: @escaping ValueEventHandler<String>) -> Modified {
        modified {
            $0.write(ViewContract.allowsDrop, true)
            $0.addHandler(ViewContract.dropped.token, gate: .own(policy)) {
                if let text = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.dropped.name, as: String.self) {
                    try await handler(text)
                }
            }
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDropped(gate: Gate, _ handler: @escaping ValueEventHandler<String>) -> Modified {
        modified {
            $0.write(ViewContract.allowsDrop, true)
            $0.addHandler(ViewContract.dropped.token, gate: .shared(gate)) {
                if let text = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.dropped.name, as: String.self) {
                    try await handler(text)
                }
            }
        }
    }

    /// Accepts files the user drops on the view from the system - of
    /// `types`, any file where the list is empty - with those dropped.
    ///
    ///     Text("Drop a report here")
    ///         .onDropped(files: [FileType("Text", extensions: ["txt"])], policy: .ignoreWhileRunning) { files in
    ///             notes = String(decoding: try await files[0].read(), as: UTF8.self)
    ///         }
    ///
    /// A dropped file reads and launches as one the user opened
    /// (`ChosenFile`); files of other kinds are not taken. `files:` is always
    /// written, so a drop of files never reads as a drop of words.
    public func onDropped(
        files types: [FileType], _ handler: @escaping @MainActor ([ChosenFile]) throws -> Void
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

    /// The same, with a handler that awaits - reading a file does: its `policy` says what a drop does while a
    /// run is under way.
    public func onDropped(
        files types: [FileType], policy: GatePolicy, _ handler: @escaping ValueEventHandler<[ChosenFile]>
    ) -> Modified {
        modified {
            $0.takesFiles(types)
            $0.addHandler(ViewContract.filesDropped.token, gate: .own(policy), dropped(types, handler))
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDropped(
        files types: [FileType], gate: Gate, _ handler: @escaping ValueEventHandler<[ChosenFile]>
    ) -> Modified {
        modified {
            $0.takesFiles(types)
            $0.addHandler(ViewContract.filesDropped.token, gate: .shared(gate), dropped(types, handler))
        }
    }

    /// Runs as a drag comes over the view, before it is let go - where a highlight goes up.
    public func onDragEntered(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.dragEntered, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onDragEntered(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragEntered, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDragEntered(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragEntered, gate: gate, handler)
    }

    /// Runs when a drag leaves the view without being let go - the mirror of
    /// `onDragEntered`, and where a highlight put up there is taken down.
    public func onDragExited(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(ViewContract.dragExited, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onDragExited(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragExited, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onDragExited(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragExited, gate: gate, handler)
    }
}

// What one view hears of a gesture is the sum of what its handlers asked, each hearing its own.
// Design: docs/design/views/modifiers.md#gestures
extension Node {
    /// Listens for `directions` beside the directions it listens for already; a second threshold is said.
    fileprivate mutating func hearsSwipes(_ directions: SwipeDirections, threshold: Double?) {
        let heard = props[ViewContract.swipeDirections.token].flatMap(SwipeDirections.init(propValue:)) ?? []
        write(ViewContract.swipeDirections, heard.union(directions))

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

    /// Waits `minimum` for a hold, a hold saying none keeping the one said; a view asked for two is said.
    fileprivate mutating func hearsHolds(_ minimum: Duration?) {
        guard let minimum else { return }
        let milliseconds = Double(Motion.milliseconds(of: minimum))
        if let said = props[ViewContract.holdDuration.token].flatMap(Double.init(propValue:)), said != milliseconds {
            complain("A view waits one time for a hold: \(said) and \(milliseconds) milliseconds were asked on it, "
                + "and the last stands.")
        }
        write(ViewContract.holdDuration, milliseconds)
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

/// What an awaiting swipe's handler runs: `handler`, given the way the swipe went, where `directions` names it.
@MainActor
private func swiped(
    _ directions: SwipeDirections, _ handler: @escaping ValueEventHandler<SwipeDirection>
) -> EventHandler {
    {
        if let went = EventBuffer.current.value().flatMap(SwipeDirection.init(propValue:)), directions.contains(went) {
            try await handler(went)
        }
    }
}

/// What an awaiting pan's handler runs: `handler`, given where the pan stands.
private func panned(
    _ handler: @escaping ValueEventHandler<PanUpdate>
) -> ValueEventHandler<GesturePhase, Point, Point, Point> {
    { phase, total, velocity, at in try await handler(PanUpdate(phase: phase, total: total, velocity: velocity, at: at)) }
}

/// What an awaiting drop's handler runs: `handler`, given the dropped files of `types`, where there are any.
@MainActor
private func dropped(_ types: [FileType], _ handler: @escaping ValueEventHandler<[ChosenFile]>) -> EventHandler {
    {
        if let files = MemberValues.carried(
            EventBuffer.current, by: ViewContract.filesDropped.name, as: [ChosenFile].self)?
            .filter({ $0.isOne(of: types) }), !files.isEmpty {
            try await handler(files)
        }
    }
}
