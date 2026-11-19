// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/cycle.md#three-copies-of-a-value
/// What a carried state's value is, across every render - the bytes both sides
/// read, kept as three copies: the image the running cycle works on, the last
/// completed cycle's, and a write waiting to be latched.
@MainActor
final class HostStorage: NamedState {
    /// What the cycle running now is working on.
    var image: [UInt8]

    /// The last completed cycle's, which is what everything outside reads.
    var published: [UInt8]

    /// A write made outside a cycle, waiting to be latched.
    var pending: [UInt8]?

    /// Which of that write's lanes actually changed.
    var pendingMask: UInt64 = 0

    /// Which lanes were written since they were last read; bit 63 is every lane from 63 on.
    var dirty: UInt64 = 0

    /// The readings asked for of this value, in the order asked, each known weakly with its target.
    /// Design: docs/design/core/journeys.md#readings
    var samplings: [(target: ObjectIdentifier, held: WeakSampling)] = []

    /// How many times the value was written, equal bytes included - what an engine following the state compares.
    /// On a journey's image a write is one of its destination: a frame of where it stands moves the sample instead.
    /// Design: docs/design/core/cycle.md#what-wakes-an-engine
    var stamp: Int = 0

    /// How many host reports laid anything on it.
    var reports: Int = 0

    /// How many times the value's bytes changed - a journey's destination lanes - which a conversion compares.
    /// Design: docs/design/core/journeys.md#conversions
    var targetRevision: Int = 0

    /// The lanes whose change is a change of the state's value: a journey's destination, else every lane.
    var targetMask: UInt64 { journeyWidth == nil ? ~0 : destinationMask }

    /// The number the host quotes it back by, once anything has asked.
    var number: Int32?

    /// How many consumers the host carries it for - a property of a live element showing it, an engine following
    /// its journey, a reading of it; nought is a state with no channel, whatever its number.
    /// Design: docs/design/core/state.md#a-state-nobody-wears
    var consumers = 0

    /// Whether the host has a channel for it, as the last walk settled: a consumer stood when the walk ended.
    /// Design: docs/design/core/journeys.md#a-channels-life
    private(set) var hasChannel = false

    /// How many channels were opened for it: a first consumer after none is a channel of a new generation.
    private(set) var generation = 0

    /// How wide the value of a journey's image is, in lanes; nil for an image that is the value itself.
    var journeyWidth: Int?

    /// The host's last report of where the value stands, whole and of one frame; nil with no channel.
    /// Design: docs/design/core/journeys.md#the-sample
    private(set) var sample: HostSample?

    /// What hears that the sample changed, came or went.
    var presented: (() -> Void)?

    /// What hears that the channel closed with its last consumer.
    var closed: (() -> Void)?

    /// What the author calls it - the reflection walk's, as a state's is.
    var origin: String?

    /// Which of the host's doors the value goes through, which says where its law lies.
    var door: StateKind?

    /// What the host is told the lanes are read as; nil for text.
    var laneKind: LaneKind?

    /// What `.inherited` means on this state: the application's motion, as the differ last read it.
    /// Design: docs/design/core/journeys.md#which-motion
    var inherited: Motion = .inherited

    /// What runs after the host wrote this value, handed the lanes it wrote.
    var told: ((UInt64, WriteOrigin) -> Void)?

    /// Whether any build read the journey off this image.
    /// Design: docs/design/core/journeys.md#two-reader-sets
    var readAtBuild = false

    init(_ bytes: [UInt8]) {
        image = bytes
        published = bytes
    }

    /// Its number leaves the renderer's table with it, which nothing else would sweep.
    isolated deinit {
        if let number {
            Renderer.shared.states[number] = nil
        }
    }

    /// The lanes of a journey's destination; nought for an image that is the value itself.
    var destinationMask: UInt64 {
        guard let journeyWidth else { return 0 }

        return (journeyWidth..<(journeyWidth * 2)).reduce(into: UInt64(0)) { $0 |= Self.bit(of: $1) }
    }

    /// Takes the host's report of where the value stands; the same report again is no change.
    func took(_ sample: HostSample) {
        guard hasChannel, self.sample != sample else { return }

        self.sample = sample
        presented?()
        if !samplings.isEmpty { sampleTaken(at: Renderer.shared.board.frameTime) }
    }

    /// Settles the channel after a walk: opened with a first consumer, a new generation; closed with the last one
    /// gone, its sample with it. Answers whether the channel closed.
    /// Design: docs/design/core/journeys.md#a-channels-life
    @discardableResult
    func settleChannel() -> Bool {
        if consumers > 0, !hasChannel {
            hasChannel = true
            generation &+= 1
            return false
        }

        guard consumers == 0, hasChannel else { return false }

        hasChannel = false
        if sample != nil {
            sample = nil
            presented?()
        }
        closed?()
        return true
    }

    /// Whether an engine of the application's animates this journey, which the host
    /// only wears.
    var engineAnimates: Bool {
        guard door == .property, let at = StateLaw.within(.property, lanes: published.count / 8) else { return false }

        return StateImage.lane(at, of: published) == StateLaw.custom
    }

    /// The published bytes as the host must read them: an inherited law resolved, and
    /// a `.custom` value handed over as its own destination.
    /// Design: docs/design/core/journeys.md#the-law-on-the-image
    func crossing() -> [UInt8] {
        guard let door = door,
              let at = StateLaw.within(door, lanes: published.count / 8)
        else { return published }

        switch StateImage.lane(at, of: published) {
        case StateLaw.inherited:
            var bytes = published

            StateImage.lay(StateLaw.lanes(of: inherited), at: at, into: &bytes)

            return bytes

        case StateLaw.custom where door == .property:
            // Under `.custom` the engine's value is the host's destination, under no law.
            let width = (published.count / 8 - StateLaw.lanes - 2) / 3
            var bytes = published

            StateImage.lay((0..<width).map { StateImage.lane($0, of: published) }, at: width, into: &bytes)
            StateImage.lay(StateLaw.lanes(of: Motion.none), at: at, into: &bytes)

            return bytes

        default:
            return published
        }
    }

    /// Lays a value into a slot lane by lane, answering which lanes changed - bit for
    /// bit, so -0.0 and a NaN are what they are.
    /// Design: docs/design/core/cycle.md#where-a-write-lands
    nonisolated static func lay(_ bytes: [UInt8], into slot: inout [UInt8]) -> UInt64 {
        if slot.count != bytes.count {
            slot = bytes
            return ~0
        }

        var moved: UInt64 = 0

        for lane in stride(from: 0, to: bytes.count, by: 8) {
            var same = true

            for byte in lane..<min(lane + 8, bytes.count) where slot[byte] != bytes[byte] {
                same = false
                slot[byte] = bytes[byte]
            }

            if !same {
                moved |= bit(of: lane / 8)
            }
        }

        return moved
    }

    /// Lays only the named lanes, answering which of them changed - a host's report.
    nonisolated static func lay(_ bytes: [UInt8], into slot: inout [UInt8], only mask: UInt64) -> UInt64 {
        // A report speaks about lanes, never about shape: what it does not name stands.
        // Design: docs/design/core/cycle.md#what-the-host-reports
        let reach = min(slot.count, bytes.count)
        var moved: UInt64 = 0

        for lane in 0..<((reach + 7) / 8) where mask & bit(of: lane) != 0 {
            var same = true

            for byte in (lane * 8)..<min(lane * 8 + 8, reach) where slot[byte] != bytes[byte] {
                same = false
                slot[byte] = bytes[byte]
            }

            if !same {
                moved |= bit(of: lane)
            }
        }

        return moved
    }

    /// The dirty bit of one lane: its own, or the last for lanes past 63.
    nonisolated static func bit(of lane: Int) -> UInt64 { 1 << UInt64(min(lane, 63)) }
}
