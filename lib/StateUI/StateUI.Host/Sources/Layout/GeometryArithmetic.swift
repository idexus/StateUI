// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The distances a host presents: finite signed values, with no toolkit's pixel limit in the shared geometry.
/// Design: docs/design/host/layout.md#finite-distances
@_spi(Host) public enum GeometryArithmetic {
    /// A finite distance as given; not a number or either infinity contributes no distance.
    public static func distance(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    static func value(_ value: HostValue?, for property: Prop) -> HostValue? {
        guard property == .padding || property == .margin, let numbers = value?.numbers,
              !numbers.allSatisfy(\.isFinite)
        else { return value }
        return .numbers(numbers.map(distance))
    }
}
