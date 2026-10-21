// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A color as one number, the way a relay beneath a host takes it.
@_spi(Host) extension PropValue {
    /// The color as ARGB, eight bits a channel, alpha highest; nil for a value that is no color.
    public var argb: UInt32? {
        guard let channels = color else { return nil }
        return UInt32(channels.alpha) << 24 | UInt32(channels.red) << 16
            | UInt32(channels.green) << 8 | UInt32(channels.blue)
    }
}
