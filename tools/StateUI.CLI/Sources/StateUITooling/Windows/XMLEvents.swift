// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A well-formed XML document read as its elements' events, in order: elements and their attributes, text with its
/// references, character data; declarations and comments skipped. A document that leaves an element open, closes one
/// it did not open, or holds anything but one root is refused.
/// Design: docs/design/tooling/winui-heads.md#the-manifest
enum XMLEvents {
    enum Event: Equatable {
        case start(name: String, attributes: [String: String])
        case text(String)
        case end(name: String)
    }

    /// Why a document is not XML.
    struct Refusal: Error, Equatable {
        let reason: String
    }

    static func read(_ data: Data) throws -> [Event] {
        var cursor = Cursor(bytes: Array(data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data[...]))
        var events: [Event] = []
        var open: [String] = []
        var rootRead = false
        while !cursor.atEnd {
            if !cursor.isAt("<") {
                let text = try decode(cursor.take(until: "<"))
                guard !open.isEmpty || text.allSatisfy(\.isWhitespace) else { throw Refusal(reason: "text outside the root") }
                if !open.isEmpty { events.append(.text(text)) }
            } else if cursor.skip("<?") {
                _ = try cursor.through("?>")
            } else if cursor.skip("<!--") {
                _ = try cursor.through("-->")
            } else if cursor.skip("<![CDATA[") {
                let text = try cursor.through("]]>")
                guard !open.isEmpty else { throw Refusal(reason: "character data outside the root") }
                events.append(.text(text))
            } else if cursor.skip("<!") {
                _ = try cursor.through(">")
            } else if cursor.skip("</") {
                let name = try cursor.through(">").trimmingCharacters(in: .whitespaces)
                guard open.last == name else { throw Refusal(reason: "</\(name)> where \(open.last.map { "<\($0)>" } ?? "nothing") is open") }
                open.removeLast()
                events.append(.end(name: name))
            } else {
                cursor.skip("<")
                guard !(open.isEmpty && rootRead) else { throw Refusal(reason: "a second root") }
                let (name, attributes, closed) = try startTag(&cursor)
                events.append(.start(name: name, attributes: attributes))
                if closed { events.append(.end(name: name)) } else { open.append(name) }
                rootRead = true
            }
        }
        guard rootRead else { throw Refusal(reason: "no root") }
        if let unclosed = open.last { throw Refusal(reason: "<\(unclosed)> is never closed") }
        return events
    }

    /// A start tag's name, attributes and whether it closes itself, the cursor past its `>`.
    private static func startTag(_ cursor: inout Cursor) throws -> (String, [String: String], Bool) {
        let name = cursor.take { !$0.isWhitespace && $0 != "/" && $0 != ">" }
        guard !name.isEmpty else { throw Refusal(reason: "a tag with no name") }
        var attributes: [String: String] = [:]
        while true {
            _ = cursor.take(\.isWhitespace)
            if cursor.skip("/>") { return (name, attributes, true) }
            if cursor.skip(">") { return (name, attributes, false) }
            let attribute = cursor.take { !$0.isWhitespace && $0 != "=" && $0 != "/" && $0 != ">" }
            _ = cursor.take(\.isWhitespace)
            guard !attribute.isEmpty, cursor.skip("=") else { throw Refusal(reason: "<\(name)> holds a broken attribute") }
            _ = cursor.take(\.isWhitespace)
            let quote = cursor.skip("\"") ? "\"" : cursor.skip("'") ? "'" : nil
            guard let quote, attributes[attribute] == nil else { throw Refusal(reason: "<\(name)>'s \(attribute) is not one quoted value") }
            attributes[attribute] = try decode(try cursor.through(quote))
        }
    }

    /// `text` with its references - the five predefined and the numeric ones - as the characters they stand for.
    private static func decode(_ text: String) throws -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = text[...]
        while let ampersand = rest.firstIndex(of: "&") {
            result += rest[..<ampersand]
            guard let semicolon = rest[ampersand...].firstIndex(of: ";") else { throw Refusal(reason: "an unfinished reference") }
            let name = rest[rest.index(after: ampersand)..<semicolon]
            let named = ["lt": "<", "gt": ">", "amp": "&", "quot": "\"", "apos": "'"][String(name)]
            let code = name.hasPrefix("#x") ? UInt32(name.dropFirst(2), radix: 16) : name.hasPrefix("#") ? UInt32(name.dropFirst(), radix: 10) : nil
            guard let character = named ?? code.flatMap(Unicode.Scalar.init).map({ String(Character($0)) }) else {
                throw Refusal(reason: "&\(name); is no reference")
            }
            result += character
            rest = rest[rest.index(after: semicolon)...]
        }
        return result + rest
    }

    /// A document's bytes read forward.
    private struct Cursor {
        let bytes: [UInt8]
        var position = 0

        var atEnd: Bool { position >= bytes.count }

        func isAt(_ prefix: String) -> Bool { bytes[position...].starts(with: prefix.utf8) }

        @discardableResult
        mutating func skip(_ prefix: String) -> Bool {
            guard isAt(prefix) else { return false }
            position += prefix.utf8.count
            return true
        }

        /// What stands before `end`, the cursor past it.
        mutating func through(_ end: String) throws -> String {
            let marker = Array(end.utf8)
            var index = position
            while index + marker.count <= bytes.count {
                if bytes[index..<index + marker.count].elementsEqual(marker) {
                    defer { position = index + marker.count }
                    return String(decoding: bytes[position..<index], as: UTF8.self)
                }
                index += 1
            }
            throw Refusal(reason: "no \(end) ends what opened at byte \(position)")
        }

        /// What stands before `end` or the document's end, the cursor at it.
        mutating func take(until end: Character) -> String {
            take { $0 != end }
        }

        /// The characters from here that `accept` takes, the cursor past them.
        mutating func take(_ accept: (Character) -> Bool) -> String {
            let start = position
            while position < bytes.count, bytes[position] >= 0x80 || accept(Character(Unicode.Scalar(bytes[position]))) {
                position += 1
            }
            return String(decoding: bytes[start..<position], as: UTF8.self)
        }
    }
}
