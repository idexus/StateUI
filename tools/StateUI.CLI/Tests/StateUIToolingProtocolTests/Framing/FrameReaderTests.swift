// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import XCTest

final class FrameReaderTests: XCTestCase {
    private func frame(_ body: String, header: String? = nil) -> [UInt8] {
        Array(((header ?? "Content-Length: \(body.utf8.count)") + "\r\n\r\n" + body).utf8)
    }

    /// A frame arriving a byte at a time is read once, whole - its header and a character split alike.
    func testAFrameArrivingAByteAtATimeIsReadWhole() throws {
        var reader = FrameReader()
        var bodies: [Data] = []
        for byte in frame(#"{"name":"żółw 🐢"}"#) { bodies += try reader.take([byte]) }
        XCTAssertEqual(bodies.map { String(decoding: $0, as: UTF8.self) }, [#"{"name":"żółw 🐢"}"#])
    }

    /// The length counts bytes, not characters.
    func testTheLengthCountsBytes() throws {
        var reader = FrameReader()
        let body = "ż🐢"
        XCTAssertEqual(try reader.take(frame(body, header: "Content-Length: 6")), [Data(body.utf8)])
    }

    /// Several frames in one read are each read, in order; a frame begun stays for the next read.
    func testSeveralFramesInOneReadAreEachRead() throws {
        var reader = FrameReader()
        let bytes = frame("[1]") + frame("[2]") + frame("[3]").dropLast(2)
        XCTAssertEqual(try reader.take(bytes), [Data("[1]".utf8), Data("[2]".utf8)])
        XCTAssertEqual(try reader.take(frame("[3]").suffix(2)), [Data("[3]".utf8)])
    }

    /// A header's name is read in any case, and a header other than the length is passed over.
    func testOtherHeadersAndAnyCaseAreRead() throws {
        var reader = FrameReader()
        let header = "content-type: application/vscode-jsonrpc; charset=utf-8\r\nCONTENT-LENGTH:  2"
        XCTAssertEqual(try reader.take(frame("{}", header: header)), [Data("{}".utf8)])
    }

    /// A header that is not one decimal length ends the connection.
    func testAHeaderWithoutOneDecimalLengthIsNoFrame() {
        let headers: [(String, FramingError)] = [
            ("Content-Type: x", .noContentLength),
            ("Content-Length: -2", .malformedHeader("Content-Length: -2")),
            ("Content-Length: 2.0", .malformedHeader("Content-Length: 2.0")),
            ("Content-Length: 2\r\nContent-Length: 2", .malformedHeader("Content-Length: 2")),
            ("Content-Length 2", .malformedHeader("Content-Length 2")),
        ]
        for (header, error) in headers {
            var reader = FrameReader()
            XCTAssertThrowsError(try reader.take(frame("{}", header: header)), header) {
                XCTAssertEqual($0 as? FramingError, error, header)
            }
        }
    }

    /// A header with no end within its limit, and a body past its limit, end the connection.
    func testAFrameBeyondTheLimitsIsNoFrame() {
        var reader = FrameReader()
        XCTAssertThrowsError(try reader.take(Array(repeating: UInt8(ascii: "x"), count: FrameReader.headerLimit + 1))) {
            XCTAssertEqual($0 as? FramingError, .headerTooLong)
        }
        var other = FrameReader()
        let length = FrameReader.bodyLimit + 1
        XCTAssertThrowsError(try other.take(Array("Content-Length: \(length)\r\n\r\n".utf8))) {
            XCTAssertEqual($0 as? FramingError, .bodyTooLong(length))
        }
    }

    /// A frame written is a frame read.
    func testAFrameWrittenIsAFrameRead() throws {
        let message = OutgoingMessage.notification(method: "operation/event", params: .object(["text": .string("żółw")]))
        var reader = FrameReader()
        let bodies = try reader.take(Frame.encode(message))
        XCTAssertEqual(bodies, [try ToolingJSON.encoder().encode(message)])
    }
}
