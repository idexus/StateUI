// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Frames read out of the bytes a connection delivers, in whatever pieces they come.
/// Design: docs/design/tooling/protocol.md#frames
public struct FrameReader: Sendable {
    /// The longest header, in bytes, its blank line included.
    public static let headerLimit = 8 * 1024
    /// The longest body, in bytes.
    public static let bodyLimit = 16 * 1024 * 1024

    private var buffer: [UInt8] = []

    /// A reader that has read nothing.
    public init() {}

    /// The bodies of the frames `bytes` complete, in order.
    ///
    /// - Throws: ``FramingError`` when the bytes cannot be a frame; the connection then ends.
    public mutating func take(_ bytes: some Sequence<UInt8>) throws(FramingError) -> [Data] {
        buffer.append(contentsOf: bytes)
        var bodies: [Data] = []
        while let end = Self.headerEnd(in: buffer) {
            let length = try Self.contentLength(Array(buffer[..<end]))
            let start = end + 4
            guard buffer.count >= start + length else { break }
            bodies.append(Data(buffer[start..<(start + length)]))
            buffer.removeFirst(start + length)
        }
        if Self.headerEnd(in: buffer) == nil, buffer.count > Self.headerLimit { throw .headerTooLong }
        return bodies
    }

    private static func headerEnd(in bytes: [UInt8]) -> Int? {
        let last = min(bytes.count, headerLimit) - 4
        guard last >= 0 else { return nil }
        return (0...last).first { bytes[$0] == 13 && bytes[$0 + 1] == 10 && bytes[$0 + 2] == 13 && bytes[$0 + 3] == 10 }
    }

    private static func contentLength(_ header: [UInt8]) throws(FramingError) -> Int {
        guard header.allSatisfy({ $0 < 128 }) else { throw .malformedHeader("not ASCII") }
        var length: Int?
        for line in String(decoding: header, as: UTF8.self).components(separatedBy: "\r\n") {
            guard let colon = line.firstIndex(of: ":") else { throw .malformedHeader(line) }
            guard line[..<colon].lowercased() == "content-length" else { continue }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard length == nil, (1...9).contains(value.count), value.allSatisfy(\.isASCIIDigit),
                  let number = Int(value)
            else { throw .malformedHeader(line) }
            length = number
        }
        guard let length else { throw .noContentLength }
        guard length <= bodyLimit else { throw .bodyTooLong(length) }
        return length
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { isASCII && isNumber }
}
