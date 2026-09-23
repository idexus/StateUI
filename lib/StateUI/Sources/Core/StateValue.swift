// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a value must be to ride a state the host carries, and how the library's
// own values lie on the image.
// Design: docs/design/core/state.md#carried-state

/// A value that can ride a state - how it lies on the image, and back. This
/// library's own. A type of the application's own joins by saying the same: a
/// `Rect` is four lanes in the order it names its fields, a `String` its bytes.
public protocol StateValue: Equatable, Sendable {
    /// The value, as the image holds it.
    var carried: StateCarried { get }

    /// The value that image stands for, or nil where it stands for none - a
    /// lane count that does not match, or text where numbers were expected.
    init?(carried: StateCarried)

    /// How many lanes one value takes; nought for text, and
    /// `StateValueLanes.own` for a value as wide as whatever is on the state.
    static var lanes: Int { get }

    /// Which of a view's values this one is where the property alone cannot say - a
    /// colour. Everything else answers nothing.
    static var moving: MotionValues { get }
}

extension StateValue {
    /// Nothing: the property this value drives says which group it is in.
    public static var moving: MotionValues { [] }
}

/// The lane counts that are not a count. This library's own.
enum StateValueLanes {
    /// A value as wide as the image holds - a run of placements; readers ask the bytes.
    static let own = -1
}

extension Double: StateValue {
    /// One lane, which is the number itself.
    public var carried: StateCarried { .lanes([self]) }

    /// And back, unchanged.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = lanes[0]
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Int: StateValue {
    /// A whole number takes one lane, as itself.
    public var carried: StateCarried { .lanes([Double(self)]) }

    /// The nearest whole number to what the lane holds.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = Int(lanes[0].rounded())
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Bool: StateValue {
    /// Nought or one.
    public var carried: StateCarried { .lanes([self ? 1 : 0]) }

    /// Anything but nought is true.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = lanes[0] != 0
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Point: StateValue {
    /// Across, then down.
    public var carried: StateCarried { .lanes([x, y]) }

    /// A point from those two lanes.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 2 else { return nil }

        self.init(x: lanes[0], y: lanes[1])
    }

    /// Two.
    public static var lanes: Int { 2 }
}

extension Rect: StateValue {
    /// Left, top, width, height - the order the type names its own fields in.
    public var carried: StateCarried { .lanes([x, y, width, height]) }

    /// A rectangle from those four lanes.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        self.init(lanes[0], lanes[1], lanes[2], lanes[3])
    }

    /// Four.
    public static var lanes: Int { 4 }
}

extension Insets: StateValue {
    /// Left, top, right, bottom.
    public var carried: StateCarried { .lanes([left, top, right, bottom]) }

    /// Insets from those four lanes.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        self.init(lanes[0], lanes[1], lanes[2], lanes[3])
    }

    /// Four.
    public static var lanes: Int { 4 }
}

extension Color: StateValue {
    /// Red, green, blue and alpha, each from nought to one. A colour pair crosses as
    /// the half in force (`State.Storage.wearThemedPair()`).
    public var carried: StateCarried {
        let half = dark.flatMap { StandardEnvironment.app.$requestedTheme.standing == .dark ? $0 : nil } ?? light

        return .lanes([
            Double(half.red) / 255,
            Double(half.green) / 255,
            Double(half.blue) / 255,
            Double(half.alpha) / 255,
        ])
    }

    /// A colour from those four lanes, each held to the range a channel has
    /// and rounded to the eight bits a channel is kept in.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        func channel(_ value: Double) -> UInt8 {
            UInt8(min(max((value * 255).rounded(), 0), 255))
        }

        self.init(Rgba(
            red: channel(lanes[0]),
            green: channel(lanes[1]),
            blue: channel(lanes[2]),
            alpha: channel(lanes[3])))
    }

    /// Four.
    public static var lanes: Int { 4 }

    /// A colour, which is what only the value can say.
    public static var moving: MotionValues { .colour }
}

extension String: StateValue {
    /// Its own bytes.
    public var carried: StateCarried { .text(self) }

    /// The text, where that is what the image held.
    public init?(carried: StateCarried) {
        guard case .text(let text) = carried else { return nil }

        self = text
    }

    /// None: text is dirty or it is not.
    public static var lanes: Int { 0 }
}
