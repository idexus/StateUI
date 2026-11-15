// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A request's identifier, answered back with the type it came with.
public enum RequestID: Codable, Hashable, Sendable {
    /// A string, as the official clients send.
    case string(String)
    /// A number.
    case number(Double)
    /// `null`: a request that sent it, or an answer to a message whose identifier could not be read.
    case null

    /// Reads an identifier.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    /// Writes the identifier.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string): try container.encode(string)
        case .number(let number): try container.encode(number)
        case .null: try container.encodeNil()
        }
    }
}
