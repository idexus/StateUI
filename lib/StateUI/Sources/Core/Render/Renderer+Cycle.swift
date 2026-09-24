// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The renderer's half of the display cycle: the number the host quotes each
// carried state by, the boards, and the host's reports and cycles.
// Design: docs/design/core/cycle.md#state-numbers

extension Renderer {
    /// The board a value belongs to.
    func board(of storage: HostStorage) -> CycleBoard { boards[storage.board] }

    /// The board one clock's cycles run on.
    func board(for sync: Sync) -> CycleBoard {
        boards.first { $0.sync == sync } ?? boards[0]
    }

    /// Forgets an engine on every board - what an element leaving the tree owes.
    func disarm(_ id: Int) {
        for board in boards {
            board.disarm(id)
        }
    }

    /// The number the host quotes this value by, issued once and kept on it.
    /// Design: docs/design/core/cycle.md#state-numbers
    func number(for storage: HostStorage) -> Int32 {
        if let issued = storage.number { return issued }

        let issued = nextNumber
        nextNumber += 1
        storage.number = issued

        guarded.withLock {
            states[issued] = { [weak storage] in storage }
        }

        return issued
    }

    /// Reads one state attachment for a Swift host: the whole image, or nil for an
    /// inward-only, stale or orphaned attachment.
    func hostValue(for binding: HostStateBinding) -> HostStateValue? {
        guard binding.mode != .in,
              let storage = storage(of: binding.state),
              storage.door == binding.kind,
              let bytes = board(of: storage).whole(binding.state)
        else { return nil }

        return StateImage.carried(
            of: bytes,
            lanes: binding.kind == .text ? 0 : StateValueLanes.own)
    }

    /// The first lane of a state a native gesture names by its number, which the
    /// gesture carries on the view.
    func hostGestureValue(state: Int32) -> Double? {
        guard let storage = storage(of: state),
              let bytes = board(of: storage).whole(state),
              case .lanes(let lanes) = StateImage.carried(
                of: bytes, lanes: StateValueLanes.own)
        else { return nil }

        return lanes.first
    }

    /// Writes a gesture's one lane before the host runs the cycle. Keyed by state
    /// number: `panX` and `panY` feed an engine without driving a property.
    func hostMovedGesture(_ value: Double, state: Int32) -> Bool {
        guard value.isFinite, let storage = storage(of: state) else { return false }

        let mask: UInt64 = 1
        board(of: storage).told(
            StateImage.bytes(of: .lanes([value])),
            mask: mask,
            to: storage)
        storage.told?(mask)
        storage.sampleTaken()
        return true
    }

    /// Takes one native control's report into the state's image, for a Swift host.
    /// Text crosses whole and plain values and feeds name every lane; an animated
    /// property reports through its journey instead.
    func hostReported(
        _ value: HostStateValue,
        through binding: HostStateBinding
    ) -> Bool {
        guard binding.mode != .out,
              binding.kind == .text || binding.kind == .plain || binding.kind == .feed,
              let storage = storage(of: binding.state),
              storage.door == binding.kind
        else { return false }

        let mask: UInt64

        switch (binding.kind, value) {
        case (.text, .text):
            mask = ~0

        case (.plain, .lanes(let lanes)), (.feed, .lanes(let lanes)):
            let expected = board(of: storage).read(storage, lanes: StateValueLanes.own)

            guard case .lanes(let current) = expected, current.count == lanes.count else {
                return false
            }

            mask = Self.laneMask(lanes.count)

        default:
            return false
        }

        let board = board(of: storage)
        board.told(StateImage.bytes(of: value), mask: mask, to: storage)

        // After the board has let go: both callbacks may take this renderer's lock.
        storage.told?(mask)
        storage.sampleTaken()
        return true
    }

    /// Takes the parts of a journey a native animation changed; the law, the waiter
    /// and the stop count stay the state's. Reported lanes are never echoed back.
    /// Design: docs/design/core/cycle.md#what-the-host-reports
    func hostReported(
        _ journey: HostJourney,
        updating update: HostJourneyUpdate,
        through binding: HostStateBinding
    ) -> Bool {
        guard binding.mode != .out,
              binding.kind == .property,
              !update.isEmpty,
              let storage = storage(of: binding.state),
              storage.door == binding.kind,
              let bytes = board(of: storage).whole(binding.state)
        else { return false }

        let current = StateImage.carried(of: bytes, lanes: StateValueLanes.own)
        guard let standing = StateUIHost.journey(from: current),
              journey.value.count == standing.value.count,
              journey.destination.count == standing.destination.count,
              journey.velocity.count == standing.velocity.count,
              journey.value.allSatisfy(\.isFinite),
              journey.destination.allSatisfy(\.isFinite),
              journey.velocity.allSatisfy(\.isFinite)
        else { return false }

        let width = standing.value.count
        var lanes = standing.value
            + standing.destination
            + standing.velocity
            + StateLaw.lanes(of: standing.motion)
            + [Double(standing.completion ?? 0), Double(standing.stopped)]
        var mask: UInt64 = 0

        func replace(_ values: [Double], at start: Int) {
            for (offset, value) in values.enumerated() {
                lanes[start + offset] = value
                mask |= HostStorage.bit(of: start + offset)
            }
        }

        if update.contains(.value) { replace(journey.value, at: 0) }
        if update.contains(.destination) { replace(journey.destination, at: width) }
        if update.contains(.velocity) { replace(journey.velocity, at: width * 2) }

        let board = board(of: storage)
        board.told(StateImage.bytes(of: .lanes(lanes)), mask: mask, to: storage)
        storage.told?(mask)
        storage.sampleTaken()
        return true
    }

    /// Runs one board's cycle and takes the typed values it published.
    func hostCycle(sync: Sync, now: Double, reducesMotion: Bool) -> HostCycle {
        let board = board(for: sync)
        let report = board.cycle(now: now, reducesMotion: reducesMotion)
        let changes = board.dirty().compactMap { entry -> HostStateChange? in
            guard let storage = storage(of: entry.number), let kind = storage.door else {
                return nil
            }

            return HostStateChange(
                state: entry.number,
                changed: entry.mask,
                value: StateImage.carried(
                    of: entry.bytes,
                    lanes: kind == .text ? 0 : StateValueLanes.own))
        }

        return HostCycle(changes: changes, continues: report.awake)
    }

    /// A mask naming `count` lanes, including values wider than one word.
    private static func laneMask(_ count: Int) -> UInt64 {
        if count >= 64 { return ~0 }
        if count <= 0 { return 0 }
        return (UInt64(1) << UInt64(count)) - 1
    }

    /// How many boards have anything waiting for a cycle.
    func cycleAwake() -> Int32 {
        Int32(boards.filter { $0.awake }.count)
    }

    /// The last cycle of every board as one line, built only when the host traces.
    func cycleTrace() -> String {
        boards.enumerated().map { index, board in
            let report = board.reported

            return "cycle \(index) latched=\(report.latched) ran=\(report.ran)"
                + " skipped=\(report.skipped) wrote=\(report.written.count)"
                + " awake=\(report.awake ? 1 : 0)"
        }.joined(separator: " | ")
    }

    /// A state by its number, or nil where none rides it any more.
    func storage(of number: Int32) -> HostStorage? {
        let found = guarded.withLock { states[number] }

        guard let storage = found?() else {
            guarded.withLock { states[number] = nil }
            return nil
        }

        return storage
    }

    /// Puts the numbering back to a fresh process's, for the tests, whose
    /// assertions name state numbers. Never while an interface runs.
    func clearStates() {
        let issued = guarded.withLock { () -> [() -> HostStorage?] in
            let held = Array(states.values)
            states.removeAll()
            return held
        }

        for storage in issued {
            storage()?.number = nil
        }

        nextNumber = 1

        for board in boards {
            board.clear()
        }
    }
}
