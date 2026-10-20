// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A colour's channel as a toolkit holds it: a byte, 0-255, or a fraction of full, 0 to 1.
/// Design: docs/design/types/colour-and-theme.md#as-a-toolkit-holds-it
@_spi(Host) public enum ColorComponent {
    /// The fraction of full `channel` is.
    public static func fraction(_ channel: UInt8) -> Double {
        Double(channel) / 255
    }

    /// The channel nearest `fraction`, held to 0-255; none for what is no number.
    public static func nearest(_ fraction: Double) -> UInt8 {
        fraction.isNaN ? 0 : UInt8((min(max(fraction, 0), 1) * 255).rounded())
    }
}

extension PropValue {
    /// The colour as four fractions of full, as a toolkit draws it; nil for a value that is no colour.
    @_spi(Host) public var fractions: (red: Double, green: Double, blue: Double, alpha: Double)? {
        color.map { (ColorComponent.fraction($0.red), ColorComponent.fraction($0.green),
                     ColorComponent.fraction($0.blue), ColorComponent.fraction($0.alpha)) }
    }
}

extension Color {
    /// A colour a toolkit reports packed in one number: eight bits a channel, alpha highest.
    @_spi(Host) public init(argb: UInt32) {
        self.init(red: Int(argb >> 16 & 255), green: Int(argb >> 8 & 255), blue: Int(argb & 255),
                  alpha: Int(argb >> 24))
    }

    /// A colour a toolkit reports as four fractions of full, each at its nearest channel.
    @_spi(Host) public init(fractions: (red: Double, green: Double, blue: Double, alpha: Double)) {
        self.init(red: Int(ColorComponent.nearest(fractions.red)), green: Int(ColorComponent.nearest(fractions.green)),
                  blue: Int(ColorComponent.nearest(fractions.blue)), alpha: Int(ColorComponent.nearest(fractions.alpha)))
    }
}
