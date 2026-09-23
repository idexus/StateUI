// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A value a member holds, and how it crosses the boundary and back - the
// library's own values, lists of them and optional ones.
// Design: docs/design/core/contracts.md#values-that-cross

/// A value a member holds, and how it crosses the boundary and back.
///
/// `Bool`, `Int`, `Double` and `String` are ready, and so is an optional one,
/// whose nil crosses as nothing. An enum over `Int32` is one line, crossing as
/// its member's number:
///
///     enum TrafficSignal: Int32, HostRepresentable { case stop, caution, go }
public protocol HostRepresentable {
    /// The value, as it crosses.
    var propValue: PropValue { get }

    /// The value back from what crossed, or nil where that is another kind.
    /// - Parameter propValue: what the host sent.
    init?(propValue: PropValue)

    /// How a list of these crosses: as a list of values, unless the type has
    /// a leaner form - numbers cross as one run of numbers, text as one list
    /// of text.
    /// - Parameter list: the values, in order.
    static func propValue(of list: [Self]) -> PropValue

    /// A list of these back from what crossed, or nil where it is not one.
    /// - Parameter value: what the host sent.
    static func list(from value: PropValue) -> [Self]?
}

extension HostRepresentable {
    /// A list of values, each in its own form.
    /// - Parameter list: the values, in order.
    public static func propValue(of list: [Self]) -> PropValue {
        .values(list.map(\.propValue))
    }

    /// A list of values, each read back as this type - or nil where one is
    /// another kind.
    /// - Parameter value: what the host sent.
    public static func list(from value: PropValue) -> [Self]? {
        guard case .values(let values) = value else { return nil }

        var list: [Self] = []

        for item in values {
            guard let read = Self(propValue: item) else { return nil }
            list.append(read)
        }

        return list
    }
}

extension Array: HostRepresentable where Element: HostRepresentable {
    /// The list, in the form its values' type gives a list.
    public var propValue: PropValue { Element.propValue(of: self) }

    /// The list back, or nil where what crossed is not a list of these.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let list = Element.list(from: propValue) else { return nil }

        self = list
    }
}

extension Bool: HostRepresentable {
    /// True or false.
    public var propValue: PropValue { .bool(self) }

    /// True or false, or nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .bool(let value) = propValue else { return nil }

        self = value
    }
}

extension Int: HostRepresentable {
    /// A whole number, as every number crosses: a Double.
    public var propValue: PropValue { .number(Double(self)) }

    /// The whole part of a number, or nil for anything else - a number with no
    /// whole part, infinity or not a number, included.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .number(let value) = propValue, value.isFinite,
              let whole = Int(exactly: value.rounded(.towardZero))
        else { return nil }

        self = whole
    }
}

extension Double: HostRepresentable {
    /// The number.
    public var propValue: PropValue { .number(self) }

    /// The number, or nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .number(let value) = propValue else { return nil }

        self = value
    }

    /// Numbers cross as one run of numbers.
    /// - Parameter list: the numbers, in order.
    public static func propValue(of list: [Double]) -> PropValue { .numbers(list) }

    /// The run of numbers, or nil for anything else.
    /// - Parameter value: what the host sent.
    public static func list(from value: PropValue) -> [Double]? { value.numbers }
}

extension String: HostRepresentable {
    /// Text.
    public var propValue: PropValue { .string(self) }

    /// The text, or nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .string(let value) = propValue else { return nil }

        self = value
    }

    /// Texts cross as one list of text.
    /// - Parameter list: the texts, in order.
    public static func propValue(of list: [String]) -> PropValue { .strings(list) }

    /// The list of text, or nil for anything else.
    /// - Parameter value: what the host sent.
    public static func list(from value: PropValue) -> [String]? { value.strings }
}

extension Optional: HostRepresentable where Wrapped: HostRepresentable {
    /// The value, or nothing.
    public var propValue: PropValue { self?.propValue ?? .nothing }

    /// Nil for nothing, the value for its own kind, and no value at all for
    /// any other kind.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        if case .nothing = propValue {
            self = .none
            return
        }

        guard let value = Wrapped(propValue: propValue) else { return nil }

        self = .some(value)
    }
}

extension PropValue: HostRepresentable {
    /// Itself: a member of this type holds any value the boundary carries.
    public var propValue: PropValue { self }

    /// Itself.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        self = propValue
    }
}

extension HostRepresentable where Self: RawRepresentable, RawValue == Int32 {
    /// The member's number: a closed vocabulary crosses as its member.
    public var propValue: PropValue { .enumeration(rawValue) }

    /// The member that number names, or nil for a number it names none of and
    /// for any other kind.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .enumeration(let number) = propValue else { return nil }

        self.init(rawValue: number)
    }
}
