// The two channels the HOST writes - an act's reply and an event's payload -
// read back by the library's own decoder in Core/Wire.swift.
//
// The direction is the reverse of every other fixture's: the runtime WRITES
// these bytes and this side reads them. The fixtures under fixtures/payloads
// are still authored here, with the library's own append helpers - the same
// value encoding every channel shares - and the C# side then asserts that its
// WRITER produces exactly these bytes for the same values. Writer and reader
// meet in the file, so neither can drift alone.

import XCTest
import StateUIWireProbe
@testable import StateUI

final class HostChannelTests: XCTestCase {
    // MARK: - The fixtures

    /// Every reply shape the host sends, one file each: the bytes are the
    /// contract the C# writer is held to, the sidecar is what review reads.
    func testEveryReplyShapeIsWrittenDown() throws {
        try check(reply(ok: true, []), against: "payloads/reply-void")
        try check(reply(ok: true, [.bool(true)]), against: "payloads/reply-bool")
        try check(
            reply(ok: true, [.numbers([14, 45, 44, 123])]),
            against: "payloads/reply-clock")
        try check(
            reply(ok: true, [.string("Europe/Warsaw")]),
            against: "payloads/reply-text")
        try check(
            reply(ok: false, [.string("a focus act has to say which view it is for")]),
            against: "payloads/reply-failure")
    }

    /// And every payload shape an event carries.
    func testEveryPayloadShapeIsWrittenDown() throws {
        try check(payload([.string("Hello, world")]), against: "payloads/event-text")
        try check(payload([.bool(true)]), against: "payloads/event-toggle")
        try check(payload([.number(12.5)]), against: "payloads/event-number")
        try check(payload([.numbers([0, 2])]), against: "payloads/event-selection")
        try check(payload([.numbers([])]), against: "payloads/event-selection-empty")
        try check(
            payload([
                .enumeration(GestureStatus.running.rawValue), .number(12.5), .number(-3),
            ]),
            against: "payloads/event-pan")
        try check(
            payload([.numbers([10, 20, 300, 400, 110, 220, 110, 176])]),
            against: "payloads/event-frame")
        try check(
            payload([
                .enumeration(WebNavigationResult.success.rawValue),
                .enumeration(WebNavigationEvent.newPage.rawValue),
                .string("https://example.com/a,b"),
            ]),
            against: "payloads/event-navigated")
    }

    /// And the standard environment's pushes - the one buffer that carries a
    /// DOMAIN byte, the providers being a closed vocabulary both sides of
    /// this repository spell. One member-heavy domain and one string-heavy one
    /// cover every value kind the seven domains use.
    func testEveryEnvironmentShapeIsWrittenDown() throws {
        try check(
            environment(1, [
                .number(0.87),
                .enumeration(BatteryState.charging.rawValue),
                .enumeration(BatteryPowerSource.ac.rawValue),
                .enumeration(EnergySaverStatus.on.rawValue),
            ]),
            against: "payloads/environment-battery")
        try check(
            environment(4, [
                .string("pl"), .string("PL"), .string("pl-PL"),
                .string("Europe/Warsaw"), .bool(true),
                .enumeration(Weekday.monday.rawValue), .bool(true),
            ]),
            against: "payloads/environment-locale")
    }

    /// An environment push round-trips, and a truncated one is refused whole
    /// at every cut - the family rule, on the newest member.
    func testAnEnvironmentPushRoundTripsAndRefusesTruncation() {
        let whole = environment(3, [
            .number(1206), .number(2622), .number(3),
            .enumeration(DisplayOrientation.portrait.rawValue),
            .enumeration(DisplayRotation.rotation0.rawValue),
            .number(120),
        ])

        let decoded = Wire.decodeEnvironment(whole)
        XCTAssertEqual(decoded?.domain, 3)
        XCTAssertEqual(decoded?.payload.count, 6)

        for cut in 0..<whole.count {
            XCTAssertNil(Wire.decodeEnvironment(Array(whole.prefix(cut))))
        }

        XCTAssertNil(Wire.decodeEnvironment(whole + [0]))
    }

    /// And the host-raised event - the one buffer that carries a NAME,
    /// because no element stands behind it: the application registered the
    /// raise in C# and subscribes here with `HostEvents.on`.
    func testEveryHostEventShapeIsWrittenDown() throws {
        try check(
            hostEvent("Gallery.BatteryChanged", [.number(0.87), .bool(true)]),
            against: "payloads/host-event")
        try check(
            hostEvent("Gallery.Ping", []),
            against: "payloads/host-event-empty")
    }

    // MARK: - Round trips

    /// Every kind of value survives the trip through the payload channel -
    /// encoded with the library's appenders, decoded with its reader.
    ///
    /// EVERY kind, and the second half of the test is what holds the word to
    /// its meaning: the tags the list writes are compared against the ten
    /// `Wire.value` reads, so an arm nothing round-trips is an arm that could
    /// be dropped from the reader and leave this passing. Four of the ten are
    /// what the binary wire brought - a colour, a value list, a member and a
    /// nothing - and three of those the host really sends: a stopped colour
    /// flight, the connection profiles, a gesture's status.
    func testAPayloadRoundTripsEveryKindOfValue() {
        let values: [PropValue] = [
            .bool(false),
            .bool(true),
            .number(12.5),
            .number(-0.0),
            .string("zażółć, \"gęślą\" jaźń 🙂"),
            .numbers([1, 2.5, -3]),
            .strings(["a", "b,c", ""]),
            .color(red: 0x33, green: 0x66, blue: 0xCC, alpha: 0xFF),
            .values([.enumeration(2), .number(0.5), .nothing]),
            .enumeration(GestureStatus.running.rawValue),
            .nothing,
        ]

        XCTAssertEqual(Wire.decodePayload(payload(values)), values)

        // The tag is the first byte of a value, so what the list covers can be
        // counted rather than eyeballed. A property token (7) and a name (11)
        // are not among the ten: their numbers belong to the session
        // dictionary THIS side writes, so the host has nothing to number one
        // against and never sends one.
        var tags: Set<UInt8> = []

        for value in values {
            var bytes: [UInt8] = []
            bytes.value(value)
            tags.insert(bytes[0])
        }

        XCTAssertEqual(
            tags, [1, 2, 3, 4, 5, 6, 8, 9, 10, 12],
            "a kind the reader has an arm for and this list does not exercise")

        // A signed zero needs its own look: PropValue's Equatable is the
        // synthesized one and -0.0 == 0.0, so the list above would pass just as
        // well with the sign bit dropped on the way.
        guard case .number(let zero) = Wire.decodePayload(payload([.number(-0.0)]))?.first else {
            return XCTFail("a signed zero did not come back as a number")
        }

        XCTAssertEqual(zero.sign, .minus)
    }

    /// A NaN crosses as its own bits and comes back a NaN: eight bytes of a
    /// double say everything a double can be, so nothing is substituted for it
    /// on either channel.
    ///
    /// The two sides differ in what they do with it AFTERWARDS, and that is
    /// deliberate: this reader carries a non-finite through, while the HOST's
    /// typed accessors refuse one, so a value nobody could act on is stopped
    /// where it would have been acted on rather than at the wire.
    func testANaNCrossesAsItself() {
        let decoded = Wire.decodePayload(payload([.number(.nan)]))

        guard case .number(let number) = decoded?.first else {
            return XCTFail("a NaN did not come back as a number")
        }

        XCTAssertTrue(number.isNaN)
    }

    /// Both arms of a reply, decoded by the reader `answered` uses.
    ///
    /// The text is length-prefixed in BYTES, so a scalar that would fuse with
    /// whatever stood beside it - a leading combining mark - crosses untouched
    /// and comes back its own scalar. That is the reply channel's own check:
    /// the payload channel has one, and the two readers are separate code.
    func testAReplyRoundTripsBothArms() {
        XCTAssertEqual(
            Wire.decodeReply(reply(ok: true, [.string("\u{0301}żółw"), .number(2)])),
            .finished([.string("\u{0301}żółw"), .number(2)]))

        XCTAssertEqual(
            Wire.decodeReply(reply(ok: false, [.string("no view called 'email'")])),
            .failed("no view called 'email'"))
    }

    /// No bytes at all IS a payload - the event with nothing to say, which
    /// the host sends as a null pointer, allocating nothing.
    func testAnEmptyBufferIsTheEmptyPayload() {
        XCTAssertEqual(Wire.decodePayload([]), [])
    }

    /// A host event round-trips its name and its values - the reader the
    /// dispatch export uses.
    func testAHostEventRoundTripsNameAndValues() {
        let decoded = Wire.decodeHostEvent(
            hostEvent("Gallery.ConnectivityChanged", [.bool(false), .string("wifi")]))

        XCTAssertEqual(decoded?.name, "Gallery.ConnectivityChanged")
        XCTAssertEqual(decoded?.payload, [.bool(false), .string("wifi")])
    }

    /// A truncated host event is refused whole at every cut - the family
    /// rule, on the newest member.
    func testATruncatedHostEventIsRefusedAtEveryCut() {
        let whole = hostEvent("Gallery.BatteryChanged", [.number(0.5), .bool(true)])

        for cut in 0..<whole.count {
            XCTAssertNil(Wire.decodeHostEvent(Array(whole.prefix(cut))))
        }

        XCTAssertNotNil(Wire.decodeHostEvent(whole))
        XCTAssertNil(Wire.decodeHostEvent(whole + [0]))
    }

    // MARK: - Refusals, deterministic to the byte

    /// A truncated buffer is refused WHOLE at every possible cut - never a
    /// partial answer, never a crash. This is the determinism the channel
    /// promises: the only two outcomes are the values or nil.
    func testATruncatedPayloadIsRefusedAtEveryCut() {
        let whole = payload([
            .number(1), .string("text"), .numbers([1, 2]), .bool(true),
        ])

        for cut in 1..<whole.count {
            XCTAssertNil(
                Wire.decodePayload(Array(whole.prefix(cut))),
                "a payload cut to \(cut) of \(whole.count) bytes was not refused")
        }

        XCTAssertNotNil(Wire.decodePayload(whole))
    }

    /// The same, for a reply - and a truncated reply is what the dispatch
    /// entry turns into a failure, so the handler waiting on it still runs.
    func testATruncatedReplyIsRefusedAtEveryCut() {
        let whole = reply(ok: true, [.string("Europe/Warsaw"), .numbers([1, 2, 3])])

        for cut in 0..<whole.count {
            XCTAssertNil(Wire.decodeReply(Array(whole.prefix(cut))))
        }

        XCTAssertNotNil(Wire.decodeReply(whole))
    }

    /// Bytes past the counted values are a framing error, not extra data.
    func testTrailingBytesAreRefused() {
        XCTAssertNil(Wire.decodePayload(payload([.bool(true)]) + [0]))
        XCTAssertNil(Wire.decodeReply(reply(ok: true, []) + [7]))
    }

    /// A buffer from another format version is refused whole - the startup
    /// handshake makes this unreachable in a running app, and the refusal is
    /// what makes it survivable anyway.
    func testAnotherVersionsBytesAreRefused() {
        var other = payload([.bool(true)])
        other[0] = 1

        XCTAssertNil(Wire.decodePayload(other))
        XCTAssertNil(Wire.decodeReply(other))
    }

    /// A failure carries exactly one value, the reason as text - anything
    /// else is not a reply.
    func testAMalformedFailureIsRefused() {
        XCTAssertNil(Wire.decodeReply(reply(ok: false, [])))
        XCTAssertNil(Wire.decodeReply(reply(ok: false, [.number(7)])))
        XCTAssertNil(Wire.decodeReply(reply(ok: false, [.string("a"), .string("b")])))
    }

    // MARK: - Support

    /// A payload's bytes, written with the library's own append helpers.
    private func payload(_ values: [PropValue]) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(Wire.version)
        out.u8(UInt8(values.count))
        for value in values { out.value(value) }
        return out
    }

    /// A host event's bytes: the name ahead of the same value list.
    private func hostEvent(_ name: String, _ values: [PropValue]) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(Wire.version)
        out.string(name)
        out.u8(UInt8(values.count))
        for value in values { out.value(value) }
        return out
    }

    /// An environment push's bytes: the domain ahead of the same value list.
    private func environment(_ domain: UInt8, _ values: [PropValue]) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(Wire.version)
        out.u8(domain)
        out.u8(UInt8(values.count))
        for value in values { out.value(value) }
        return out
    }

    /// A reply's bytes, likewise.
    private func reply(ok: Bool, _ values: [PropValue]) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(Wire.version)
        out.u8(ok ? 1 : 0)
        out.u8(UInt8(values.count))
        for value in values { out.value(value) }
        return out
    }

    /// A payload fixture: the bytes, the probe's sidecar, and the decoder's
    /// round trip in one check.
    private func check(
        _ bytes: [UInt8],
        against name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let sidecar = if name.contains("reply") {
            WireProbe.dumpReply(bytes)
        } else if name.contains("host-event") {
            WireProbe.dumpHostEvent(bytes)
        } else if name.contains("environment") {
            WireProbe.dumpEnvironment(bytes)
        } else {
            WireProbe.dumpPayload(bytes)
        }

        try Fixtures.check(bytes, sidecar: sidecar, against: name, file: file, line: line)
    }
}
