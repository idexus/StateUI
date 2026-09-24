// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A brush as the relay takes it, read from a colour or a brush as it crosses.
/// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
struct WinUIBrush: Equatable {
    /// 0 none, 1 solid, 2 linear, 3 radial.
    var kind: Int32 = 0

    /// A line's two points, or a centre and a radius, in fractions of the painted box.
    var geometry: [Double] = [0, 0, 0, 0]
    var colors: [UInt32] = []
    var offsets: [Double] = []

    /// Nothing painted.
    static let none = WinUIBrush()

    init() {}

    init(_ value: HostValue?) {
        if let value, let argb = Self.argb(value) {
            self = .solid(argb)
            return
        }
        guard let parts = value?.values, let brush = parts.first?.enumeration else { return }

        if brush == 1 {
            if let argb = parts.value(1).flatMap(Self.argb) { self = .solid(argb) }
            return
        }
        var index = 2
        while index + 1 < parts.count, let offset = parts[index].number, let argb = Self.argb(parts[index + 1]) {
            colors.append(argb)
            offsets.append(min(max(offset, 0), 1))
            index += 2
        }
        kind = Int32(brush)
        let given = parts.value(1)?.numbers ?? []
        let standing: [Double] = brush == 3 ? [0.5, 0.5, 0.5, 0] : [0, 0, 0, 1]
        geometry = (0..<4).map { $0 < given.count ? given[$0] : standing[$0] }
    }

    private static func solid(_ argb: UInt32) -> WinUIBrush {
        var brush = WinUIBrush()
        brush.kind = 1
        brush.colors = [argb]
        brush.offsets = [0]
        return brush
    }

    /// A colour as ARGB.
    static func argb(_ value: HostValue) -> UInt32? {
        guard let channels = value.color else { return nil }

        return UInt32(channels.alpha) << 24 | UInt32(channels.red) << 16
            | UInt32(channels.green) << 8 | UInt32(channels.blue)
    }

    /// Runs `body` with the brush as the relay's struct, its stops held for the call.
    func withRelayBrush<Result>(_ body: (StateUIBrush) -> Result) -> Result {
        colors.withUnsafeBufferPointer { colors in
            offsets.withUnsafeBufferPointer { offsets in
                let g = geometry
                return body(StateUIBrush(
                    kind: kind, geometry: (g[0], g[1], g[2], g[3]), count: Int32(colors.count),
                    colors: colors.baseAddress, offsets: offsets.baseAddress))
            }
        }
    }
}
