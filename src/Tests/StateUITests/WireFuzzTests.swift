// Trying to BREAK the decoders rather than to read them.
//
// The four channels the HOST writes and this side reads - an act's reply, an
// event's payload, an event the host raised by name, an environment push -
// and the hydration a kept state starts from. Every buffer, every truncation,
// every single-byte change, and every buffer through every decoder, because a
// decoder handed a shape that is not its own must answer nil exactly as it
// answers a mangled one.
//
// The statement is sharper here than on the C# side, because the failure is:
// an index past the end of a Swift array is a TRAP, which takes the process
// down rather than raising something a caller could answer. So what is claimed
// is that a decoder always RETURNS - and the suite dying where it stands IS
// the failure. The attempt COUNTS are asserted so that a loop which stopped
// early cannot pass as a loop which found nothing.

import Foundation
import XCTest
@testable import StateUI

final class WireFuzzTests: XCTestCase {
    /// A buffer to break, and the decoder whose shape it really is.
    private struct Sample {
        let name: String
        let bytes: [UInt8]
        let read: @Sendable ([UInt8]) -> Bool
    }

    /// Every decoder, by the name a failure would have to be traced back to.
    /// Each answers whether it read the buffer, which is what makes the wrong
    /// shape and the mangled buffer one statement.
    private static let decoders: [(name: String, read: @Sendable ([UInt8]) -> Bool)] = [
        ("decodePayload", { Wire.decodePayload($0) != nil }),
        ("decodeReply", { Wire.decodeReply($0) != nil }),
        ("decodeHostEvent", { Wire.decodeHostEvent($0) != nil }),
        ("decodeEnvironment", { Wire.decodeEnvironment($0) != nil }),
        ("decodePersistent", { Wire.decodePersistent($0) != nil }),
    ]

    /// What a single byte is changed by: every bit, the low bit alone, and the
    /// high bit alone - enough to reach a length's top byte, a tag and a count.
    private static let changes: [UInt8] = [0xFF, 0x01, 0x80]

    /// The payload fixtures, each paired with its own decoder, plus a
    /// hydration buffer - which has no fixture of its own because no message
    /// carries it, and would otherwise be the one channel nothing here breaks.
    private func corpus() throws -> [Sample] {
        let root = Fixtures.directory.appendingPathComponent("payloads")
        var samples: [Sample] = []

        for name in try FileManager.default
            .contentsOfDirectory(atPath: root.path)
            .filter({ $0.hasSuffix(".bin") })
            .sorted()
        {
            let bytes = [UInt8](try Data(contentsOf: root.appendingPathComponent(name)))
            let read: @Sendable ([UInt8]) -> Bool

            if name.hasPrefix("host-event") {
                read = { Wire.decodeHostEvent($0) != nil }
            } else if name.hasPrefix("environment") {
                read = { Wire.decodeEnvironment($0) != nil }
            } else if name.hasPrefix("reply") {
                read = { Wire.decodeReply($0) != nil }
            } else {
                read = { Wire.decodePayload($0) != nil }
            }

            samples.append(Sample(name: name, bytes: bytes, read: read))
        }

        var hydration: [UInt8] = []
        hydration.u8(Wire.version)
        hydration.u16(2)
        hydration.string("test.count")
        hydration.value(.number(4))
        hydration.string("test.loud")
        hydration.value(.bool(true))

        samples.append(Sample(
            name: "hydration", bytes: hydration,
            read: { Wire.decodePersistent($0) != nil }))

        // A corpus that quietly emptied would leave every test here passing
        // while breaking nothing.
        XCTAssertGreaterThan(samples.count, 10)

        return samples
    }

    /// Every buffer the host writes, read whole by its own decoder - the floor
    /// the two tests below stand on, since a corpus of buffers that no decoder
    /// accepts would be broken in every direction already.
    func testEveryPayloadIsReadWholeByItsOwnDecoder() throws {
        for sample in try corpus() {
            XCTAssertTrue(sample.read(sample.bytes), "\(sample.name) did not read whole")
        }
    }

    /// A decoder handed a buffer of somebody else's shape answers rather than
    /// trapping. Nothing sends one - the host writes each channel into its own
    /// entry point - so this is about what happens when something does.
    func testEveryDecoderAnswersForAShapeThatIsNotItsOwn() throws {
        var attempts = 0

        for sample in try corpus() {
            for decoder in Self.decoders {
                _ = decoder.read(sample.bytes)
                attempts += 1
            }
        }

        XCTAssertEqual(attempts, try corpus().count * Self.decoders.count)
    }

    /// A buffer that stops early is refused, wherever it stops. Every proper
    /// prefix of every buffer: each decoder bounds-checks its way forward AND
    /// requires the last value to end at the last byte, so no prefix reads as
    /// a smaller, plausible payload.
    ///
    /// An EMPTY buffer is the exception and not a truncation at all: it is
    /// what the host crosses for an event with nothing to say, which is why
    /// `decodePayload` answers it with an empty list.
    func testEveryProperPrefixOfEveryPayloadIsRefused() throws {
        for sample in try corpus() {
            for length in 1..<sample.bytes.count {
                XCTAssertFalse(
                    sample.read(Array(sample.bytes.prefix(length))),
                    "\(sample.name) cut to \(length) of \(sample.bytes.count) bytes was read")
            }
        }
    }

    /// A length no buffer could hold is refused rather than believed. It
    /// crosses UNSIGNED and four bytes wide, and is compared that way: `Int`
    /// is 32 bits on a 32-bit target, so the widest lengths do not fit the one
    /// a length is finally used as. Nothing writes such a length; this is what
    /// happens when something does.
    func testALengthNoBufferCouldHoldIsRefused() {
        var buffer: [UInt8] = []
        buffer.u8(Wire.version)
        buffer.u16(1)
        buffer.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])

        XCTAssertNil(Wire.decodePersistent(buffer))
    }

    /// Every single-byte change in every buffer is answered - read or refused,
    /// and the tree that comes out of a changed value is nobody's business.
    /// What is claimed is only that the decoder returns at all.
    func testEverySingleByteChangeIsAnsweredRatherThanTrapped() throws {
        let samples = try corpus()
        var attempts = 0
        var expected = 0

        for sample in samples {
            expected += sample.bytes.count * Self.changes.count

            for at in sample.bytes.indices {
                for change in Self.changes {
                    var changed = sample.bytes
                    changed[at] ^= change
                    _ = sample.read(changed)
                    attempts += 1
                }
            }
        }

        XCTAssertEqual(attempts, expected)
    }
}
