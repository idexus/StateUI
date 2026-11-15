// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Any JSON value: what a message carries before its method says what type it is.
public enum JSONValue: Codable, Equatable, Sendable {
    /// `null`.
    case null
    /// `true` or `false`.
    case bool(Bool)
    /// A number; the API's integers stay within what a `Double` holds exactly.
    case number(Double)
    /// A string.
    case string(String)
    /// An array.
    case array([JSONValue])
    /// An object.
    case object([String: JSONValue])

    /// Reads a JSON value.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    /// Writes the JSON value.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let bool): try container.encode(bool)
        case .number(let number): try container.encode(number)
        case .string(let string): try container.encode(string)
        case .array(let array): try container.encode(array)
        case .object(let object): try container.encode(object)
        }
    }

    /// `value` as JSON.
    public init(encoding value: some Encodable) throws {
        self = try ToolingJSON.decoder().decode(JSONValue.self, from: ToolingJSON.encoder().encode(value))
    }

    /// This value read as `type`, nothing in it left unread.
    ///
    /// - Throws: ``StrictDecodingError`` naming what `type` does not have - a field it does not declare, or
    ///   `null` where an optional field is meant to be left out - or the decoder's own error.
    public func decode<Value: Codable>(_ type: Value.Type) throws -> Value {
        let value = try ToolingJSON.decoder().decode(type, from: ToolingJSON.encoder().encode(self))
        let unread = Self.unread(self, against: try JSONValue(encoding: value), at: "")
        guard unread.isEmpty else { throw StrictDecodingError(unread: unread) }
        return value
    }

    /// Design: docs/design/tooling/protocol.md#a-message-is-read-whole
    private static func unread(_ given: JSONValue, against read: JSONValue, at path: String) -> [String] {
        switch (given, read) {
        case (.object(let given), .object(let read)):
            return given.keys.sorted().flatMap { key -> [String] in
                guard let field = read[key] else { return [path + "/" + key] }
                return unread(given[key]!, against: field, at: path + "/" + key)
            }
        case (.array(let given), .array(let read)) where given.count == read.count:
            return zip(given, read).enumerated().flatMap { unread($1.0, against: $1.1, at: path + "/\($0)") }
        default:
            return given == read ? [] : [path.isEmpty ? "/" : path]
        }
    }
}
