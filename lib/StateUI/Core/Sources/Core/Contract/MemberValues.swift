// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A member's positional values - what an event carries, what an act is handed
/// and what it answers - encoded and decoded against the types its contract
/// declares.
@_spi(Host) public enum MemberValues {
    /// The values, in order.
    /// - Parameter value: the values, as their Swift types.
    /// - Returns: what crosses.
    public static func encode<each Value: HostRepresentable>(_ value: repeat each Value) -> [PropValue] {
        var values: [PropValue] = []

        for item in repeat each value {
            values.append(item.propValue)
        }

        return values
    }

    /// The values a payload holds, as the declared types, or nil where their
    /// count or one kind differs: what crosses is exactly what the declaration
    /// says, or it is refused whole. The one leniency is at the END: an
    /// optional value there may be left out, and reads as nil.
    /// - Parameters:
    ///   - payload: what crossed.
    ///   - type: the declared types, in order.
    /// - Returns: the values, or nil.
    public static func decode<each Value: HostRepresentable>(
        _ payload: [PropValue],
        as type: repeat (each Value).Type
    ) -> (repeat each Value)? {
        guard payload.count <= count(repeat (each Value).self) else { return nil }

        var index = 0

        do {
            return (repeat try take((each Value).self, from: payload, at: &index))
        } catch {
            return nil
        }
    }

    /// How the declared types read - `()`, `Int`, `(Double, Bool)` - for the
    /// report that says a payload was refused.
    /// - Parameter type: the declared types, in order.
    /// - Returns: the declaration, as text.
    public static func describe<each Value>(_ type: repeat (each Value).Type) -> String {
        var names: [String] = []

        for kind in repeat each type {
            names.append(String(describing: kind))
        }

        return names.count == 1 ? names[0] : "(" + names.joined(separator: ", ") + ")"
    }

    /// How what crossed reads, kind by kind: `(number, bool)`.
    static func describe(_ payload: [PropValue]) -> String {
        "(" + payload.map(\.kindName).joined(separator: ", ") + ")"
    }

    /// What an event carried, as the types its contract declares - or nil,
    /// said once, where it carried anything else: a handler never runs on a
    /// guess.
    static func carried<each Value: HostRepresentable>(
        _ payload: [PropValue],
        by event: String,
        as type: repeat (each Value).Type
    ) -> (repeat each Value)? {
        guard let values = decode(payload, as: repeat (each Value).self) else {
            complain("`\(event)` carried \(describe(payload)), and its contract declares "
                + "\(describe(repeat (each Value).self)): the handler did not run.")
            return nil
        }

        return values
    }

    /// An act's answer as the declared types, or the failure a caller throws.
    static func answer<each Value: HostRepresentable>(
        _ reply: [PropValue],
        of act: String,
        as type: repeat (each Value).Type
    ) throws -> (repeat each Value) {
        guard let values = decode(reply, as: repeat (each Value).self) else {
            throw StateUIError(message: "`\(act)` answered \(describe(reply)), and its contract "
                + "declares \(describe(repeat (each Value).self))")
        }

        return values
    }

    /// How many types a declaration names.
    private static func count<each Value>(_ type: repeat (each Value).Type) -> Int {
        var count = 0

        for _ in repeat each type {
            count += 1
        }

        return count
    }

    /// The next value, as the next declared type - or the refusal. Past the
    /// end of the payload only an optional value is read, as nil.
    private static func take<Value: HostRepresentable>(
        _ type: Value.Type,
        from payload: [PropValue],
        at index: inout Int
    ) throws -> Value {
        defer { index += 1 }

        guard index < payload.count else {
            guard let omitted = (Value.self as? any OmissibleValue.Type)?.omitted as? Value else {
                throw Refused()
            }

            return omitted
        }

        guard let value = Value(propValue: payload[index]) else { throw Refused() }

        return value
    }

    /// A value that is not the declared kind.
    private struct Refused: Error {}
}

/// A value that may be left out of the end of a payload - how a host says it has
/// none.
protocol OmissibleValue {
    /// The value a left-out position stands for.
    static var omitted: Self { get }
}

extension Optional: OmissibleValue {
    /// Nil.
    static var omitted: Self { nil }
}

extension PropValue {
    /// Which kind of value this is, for a report that names what arrived.
    fileprivate var kindName: String {
        switch self {
        case .string: "string"
        case .enumeration: "enumeration"
        case .nothing: "nothing"
        case .name: "name"
        case .number: "number"
        case .bool: "bool"
        case .numbers: "numbers"
        case .strings: "strings"
        case .color: "color"
        case .values: "values"
        case .themed: "themed"
        }
    }
}
