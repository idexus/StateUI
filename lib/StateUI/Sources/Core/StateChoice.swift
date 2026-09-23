// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A choice the host can be handed as a channel: an alignment, a keyboard, a line
/// break, a set of flags. This library's own.
///
///     @State private var side = Alignment.start
///
///     Label("Where am I?").horizontalAlignment($side)
///
///     side = .center                  // the host moves it; nothing is rebuilt
///
/// One lane holding the member's number, resolved by the host as a described
/// property is. A choice has no half way, so it is set as it stands.
public protocol StateChoice: StateValue, RawRepresentable where RawValue == Int32 {}

extension StateChoice {
    /// The member's number, as its one lane.
    public var carried: StateCarried { .lanes([Double(rawValue)]) }

    /// And back - or nothing, where those bytes name no member of this type.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried,
              let first = lanes.first,
              let made = Self(rawValue: Int32(first.rounded()))
        else { return nil }

        self = made
    }

    /// One.
    public static var lanes: Int { 1 }

    /// A choice is in no group of values a motion can be about: it has no
    /// half-way to be caught at.
    public static var moving: MotionValues { [] }
}
