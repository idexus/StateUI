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
    public func onTapped(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.tapped, handler)
    }

    /// The same, for a double tap or more: `count` taps in a row.
    ///
    ///     Label("Reset").onTapped(count: 2) { taps = 0 }
    public func onTapped(
        count: Int,
        _ handler: @escaping EventHandler
    ) -> Modified {
        // One `modified`: chaining would return `Modified.Modified`.
        modified {
            $0.write(ViewContract.tapCount, count)
            $0.addHandler(ViewContract.tapped.token, handler)
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
    ///   - threshold: how far the finger must travel, in device units.
    public func onSwiped(
        direction: SwipeDirection = .all,
        threshold: Double? = nil,
        _ handler: @escaping ValueEventHandler<SwipeDirection>
    ) -> Modified {
        modified {
            $0.write(ViewContract.swipeDirection, direction)
            $0.describe(ViewContract.swipeThreshold, threshold)
            $0.addHandler(ViewContract.swiped.token) {
                // A payload that does not read leaves the handler alone.
                if let direction = SwipeDirection(EventBuffer.current.value()) {
                    try await handler(direction)
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
    ///             if pan.phase == .running { offsetX = pan.totalX }
    ///         }
    ///
    /// The totals are measured from where the pan began.
    ///
    /// - Parameter touchCount: how many simultaneous pointers the host must
    ///   require. A host that cannot distinguish that count does not recognize
    ///   the gesture when the requested count is unsupported.
    public func onPanUpdated(
        touchCount: Int? = nil,
        _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> Modified {
        modified {
            $0.describe(ViewContract.panTouchCount, touchCount)
            $0.addHandler(ViewContract.panUpdated.token) {
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
    public func onPinchUpdated(_ handler: @escaping ValueEventHandler<PinchUpdate>) -> Modified {
        onEvent(ViewContract.pinchUpdated) { phase, scale, origin in
            try await handler(PinchUpdate(phase: phase, scale: scale, scaleOrigin: origin))
        }
    }

    // MARK: Pointer

    /// Runs when a pointer enters the view.
    ///
    /// A pointer is a mouse, a trackpad or a pen; on a touch-only device these
    /// never fire.
    public func onPointerEntered(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerEntered, handler)
    }

    /// Runs when a pointer leaves the view - the other half of a hover.
    public func onPointerExited(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.pointerExited, handler)
    }

    /// Runs as the pointer moves over the view, with where it is in the view's
    /// own coordinates; a move the platform gives no position for does not run
    /// it.
    public func onPointerMoved(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerMoved) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// Runs when a pointer button goes down over the view, with where it went
    /// down in the view's own coordinates.
    public func onPointerPressed(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerPressed) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    /// Runs when the pointer button comes back up, with where it came up.
    public func onPointerReleased(_ handler: @escaping ValueEventHandler<Point>) -> Modified {
        onEvent(ViewContract.pointerReleased) { point in
            if let point {
                try await handler(point)
            }
        }
    }

    // MARK: Drag and drop

    /// Makes the view draggable, carrying `text` with it.
    ///
    ///     Label(item)
    ///         .draggable(text: item)
    ///
    /// Text is the portable drag payload. `onDragStarting` runs when the drag
    /// starts, too late to decide what is carried: a native drag needs its
    /// payload at once.
    public func draggable(
        text: String,
        canDrag: Bool = true,
        onDragStarting: EventHandler? = nil
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
    public func onDropCompleted(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dropCompleted, handler)
    }

    /// Accepts what is dropped on the view, with the text it carried.
    ///
    ///     VStack { … }
    ///         .onDrop { text in items.append(text) }
    public func onDrop(_ handler: @escaping ValueEventHandler<String>) -> Modified {
        modified {
            $0.write(ViewContract.allowDrop, true)
            $0.addHandler(ViewContract.drop.token) {
                if let text = MemberValues.carried(
                    EventBuffer.current, by: ViewContract.drop.name, as: String.self) {
                    try await handler(text)
                }
            }
        }
    }

    /// Runs while a drag is over the view, before it is let go.
    public func onDragOver(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragOver, handler)
    }

    /// Runs when a drag leaves the view without being let go - the mirror of
    /// `onDragOver`, and where a highlight put up there is taken down.
    public func onDragLeave(_ handler: @escaping EventHandler) -> Modified {
        onEvent(ViewContract.dragLeave, handler)
    }
}
