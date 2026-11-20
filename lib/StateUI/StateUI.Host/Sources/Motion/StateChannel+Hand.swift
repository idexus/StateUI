// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One lane of a state a hand holds: which, where the hand holds it, and where it would come to rest let go now.
/// Design: docs/design/host/motion.md#a-lane-a-hand-holds
@_spi(Host) public struct HeldLane: Equatable, Sendable {
    /// The lane's place among the state's numbers.
    public let lane: Int

    /// Where the hand holds it: what is shown.
    public let value: Double

    /// Where it would rest: what the state is told it is going to.
    public let destination: Double

    /// The lane `lane` held at `value`, bound for `destination`.
    public init(lane: Int, value: Double, destination: Double) {
        self.lane = lane
        self.value = value
        self.destination = destination
    }
}

/// One lane of a state a hand lets go: which, where it sets out from, where it goes, and how fast it sets out.
/// Design: docs/design/host/motion.md#a-lane-a-hand-holds
@_spi(Host) public struct ReleasedLane: Equatable, Sendable {
    /// The lane's place among the state's numbers.
    public let lane: Int

    /// Where it sets out from: where the hand left it, or - a lane that stays - where it rests.
    public let from: Double

    /// Where it goes.
    public let destination: Double

    /// How fast it sets out, in units a second.
    public let velocity: Double

    /// The lane `lane` going from `from` to `destination`, setting out at `velocity`.
    public init(lane: Int, from: Double, destination: Double, velocity: Double) {
        self.lane = lane
        self.from = from
        self.destination = destination
        self.velocity = velocity
    }
}

extension StateChannel {
    /// A hand holds `lanes`: each leaves the run it travels in - which goes on with the lanes it keeps - and is
    /// shown where the hand holds it, standing still, bound for where it would rest. A lane the program wrote
    /// while held keeps the program's destination. `defers` says a program's write of one waits for the hand.
    func hold(_ lanes: [HeldLane], defers: Bool, emit: StateChannelEmit) {
        halt(lanes.map(\.lane), as: .superseded, emit: emit)

        var named = false
        for each in lanes where value.indices.contains(each.lane) {
            held[each.lane] = defers
            value[each.lane] = each.value
            velocity[each.lane] = 0
            if deferred[each.lane] == nil, destination[each.lane] != each.destination {
                destination[each.lane] = each.destination
                named = true
            }
        }
        emit(self, named ? .position : .frame, [], .user)
    }

    /// The hand lets `lanes` go: each sets out from where it was left for its destination at its speed, together as
    /// one run under `law` - the state's own where none is given. A lane the program wrote while held goes where
    /// the program sent it instead, under the state's own law, and its write's waiter is answered by that run.
    func release(
        _ lanes: [ReleasedLane], under law: Motion?, now: Double, reducesMotion: Bool, emit: StateChannelEmit
    ) {
        // A lane let go with no hold before it - a wheel's notch - leaves the run it travels in here.
        halt(lanes.map(\.lane), as: .superseded, emit: emit)

        var thrown: [ReleasedLane] = []
        var waiting: [Int] = []
        for each in lanes where value.indices.contains(each.lane) {
            held[each.lane] = nil
            value[each.lane] = each.from
            if let sent = deferred.removeValue(forKey: each.lane) {
                destination[each.lane] = sent
                waiting.append(each.lane)
            } else {
                destination[each.lane] = each.destination
                thrown.append(each)
            }
        }

        if !thrown.isEmpty {
            send(
                thrown.map(\.lane), at: thrown.map(\.velocity), under: law ?? motion, completion: nil, by: .user,
                now: now, reducesMotion: reducesMotion, emit: emit)
        }
        if !waiting.isEmpty {
            let completion = deferredCompletion
            deferredCompletion = nil
            send(
                waiting, at: waiting.map { _ in 0 }, under: motion, completion: completion, by: .animation,
                now: now, reducesMotion: reducesMotion, emit: emit)
        }
    }

    /// The hand loses `lanes` with nothing moved: a program's write of them lands as on any lane.
    func drop(_ lanes: [Int]) {
        for lane in lanes {
            held[lane] = nil
            deferred[lane] = nil
        }
        if deferred.isEmpty { deferredCompletion = nil }
    }

    /// The lanes a hand holds that a program's write naming `changed` takes from it: those whose hand does not
    /// wait for it.
    func interrupted(by changed: UInt64) -> [Int] {
        guard held.values.contains(false) else { return [] }

        let width = value.count
        func names(_ lane: Int) -> Bool { changed & (UInt64(1) << UInt64(min(lane, 63))) != 0 }
        let stops = names((width * 3) + 4)
        return held.keys.sorted().filter { held[$0] == false && (stops || names($0) || names(width + $0)) }
    }
}
