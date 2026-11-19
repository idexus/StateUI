// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a layout's own run reads and writes of the journey it moves: the lanes as they stand, each part laid alone.
// Design: docs/design/core/journeys.md#where-a-run-shows-it

extension Journey {
    /// The storage, its journey image - made now if nothing has yet - and the lanes
    /// as they stand, read without recording: what every write of the run starts from.
    private func walking() -> (State<Value>.Storage, JourneyLanes<Value>)? {
        guard storage.walkedImage() != nil, let lanes = storage.journeyLanes else { return nil }

        return (storage, lanes)
    }

    /// Where the host walks the value, whatever a run shows: what the run moving it
    /// works out its own place from.
    var walked: Value { walking()?.1.value ?? storage.value }

    /// Where the value stands: where a run shows it, else where the host walks it.
    var standing: Value { storage.shown?.value ?? walked }

    /// Where the value is going: the state's own, read without recording.
    var going: Value { storage.value }

    /// How fast the lanes go, per second; nought where nothing animates them.
    var speed: Value { walking()?.1.velocity ?? JourneyLanes<Value>.still }

    /// The run `owner` shows the value at `value` while it moves it; nil once it rests.
    func show(_ value: Value?, by owner: ObjectIdentifier) {
        storage.show(value, by: owner)
    }

    /// Lays where the value stands and leaves the destination, so the host goes on from there.
    func lay(standing value: Value) {
        guard HandlerRun.admits("a journey's value") else { return }
        guard let (storage, standing) = walking() else { return storage.write(value) }

        var lanes = standing

        lanes.value = value
        storage.lay([.value], of: lanes)
        storage.presentationMoved()
    }

    /// Lays the lanes' speed: a kick the host's animation sets out with.
    func lay(speed velocity: Value) {
        guard HandlerRun.admits("a journey's velocity"), let (storage, standing) = walking() else { return }

        var lanes = standing

        lanes.velocity = velocity
        storage.lay([.velocity], of: lanes)
        storage.presentationMoved()
    }

    /// Puts one part of the value there at once, as `snap(to:)` does the whole: the other lanes go on as they were.
    /// Design: docs/design/core/journeys.md#one-part-at-once
    func snap(_ part: WritableKeyPath<Value, Double>, to target: Double) {
        guard HandlerRun.admits("a snap") else { return }
        guard let (storage, standing) = walking() else {
            var landed = storage.value
            landed[keyPath: part] = target
            guard storage.admits(landed) else { return }

            storage.snap(landed)
            return storage.askForRender()
        }

        var lanes = standing

        lanes.value[keyPath: part] = target
        lanes.destination[keyPath: part] = target
        lanes.velocity[keyPath: part] = 0
        guard storage.admits(lanes.destination) else { return }

        storage.lay([.value, .destination, .velocity], of: lanes)
        storage.moved(to: lanes.destination)
    }
}
