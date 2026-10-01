// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/cycle.md#three-copies-of-a-value
/// What a carried state's value is, across every render - the bytes both sides
/// read, kept as three copies: the image the running cycle works on, the last
/// completed cycle's, and a write waiting to be latched.
public final class HostStorage: @unchecked Sendable, NamedState {
    /// What the cycle running now is working on.
    var image: [UInt8]

    /// The last completed cycle's, which is what everything outside reads.
    var published: [UInt8]

    /// A write made outside a cycle, waiting to be latched.
    var pending: [UInt8]?

    /// Which of that write's lanes actually changed.
    var pendingMask: UInt64 = 0

    /// Which lanes were written since they were last read - bit n is lane n, bit 63
    /// every lane from 63 on.
    var dirty: UInt64 = 0

    /// The readings asked for of this value, by the state each is read into - known
    /// weakly, since a reading belongs to the element that asked for it.
    /// Design: docs/design/core/journeys.md#readings
    var samplings: [ObjectIdentifier: WeakSampling] = [:]

    /// How many times the value was written, equal bytes included - what an engine
    /// following it compares.
    var stamp: Int = 0

    /// The number the host quotes it back by, once anything has asked.
    var number: Int32?

    /// Which board's cycle owns it.
    var board: Int = 0

    /// What the author calls it - the reflection walk's, as a state's is.
    nonisolated(unsafe) var origin: String?

    /// Which of the host's doors the value goes through, which says where its law lies.
    var door: StateKind?

    /// The element's own law - what `.inherited` means here - resolved by the differ.
    /// Design: docs/design/core/identity-and-diffing.md#driven-properties
    var inherited: Motion = .inherited

    /// Which element resolved that law, so a second answering differently is heard.
    var inheritedBy: ElementId?

    /// What runs after the host wrote this value, handed the lanes it wrote - the
    /// state's own ask for a render.
    nonisolated(unsafe) var told: ((UInt64) -> Void)?

    /// Whether any build read the journey off this image.
    /// Design: docs/design/core/journeys.md#two-reader-sets
    nonisolated(unsafe) var readAtBuild = false

    init(_ bytes: [UInt8]) {
        image = bytes
        published = bytes
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
    static func lay(_ bytes: [UInt8], into slot: inout [UInt8]) -> UInt64 {
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

    /// Lays only the named lanes, answering which of them changed - what a host's
    /// report is.
    static func lay(_ bytes: [UInt8], into slot: inout [UInt8], only mask: UInt64) -> UInt64 {
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
    static func bit(of lane: Int) -> UInt64 { 1 << UInt64(min(lane, 63)) }
}
