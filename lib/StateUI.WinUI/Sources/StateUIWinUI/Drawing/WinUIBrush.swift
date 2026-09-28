// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A brush as the relay takes it, read from a colour or a brush as it crosses.
/// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
struct WinUIBrush: Equatable {
    /// 0 none, 1 solid, 2 linear, 3 radial.
    var kind: Int32 = 0

    /// A line's two points, or a centre and a radius, in fractions of the painted box.
    var geometry: [Double] = [0, 0, 0, 0]

    /// Whether how it paints follows the size of what it paints: a radial gradient's circle does.
    var followsSize: Bool { kind == 3 }
    var colors: [UInt32] = []
    var offsets: [Double] = []

    /// Nothing painted.
    static let none = WinUIBrush()

    init() {}

    /// The brush the tree's `value` describes, read by the host layer's rule (`HostBrush`), in ARGB.
    init(_ value: HostValue?) {
        switch HostBrush(value) {
        case .none: self.init()
        case .solid(let color): self.init(kind: 1, geometry: [0, 0, 0, 0], [(0, color.argb ?? 0)])
        case .linear(let from, let to, let stops):
            self.init(kind: 2, geometry: [from.x, from.y, to.x, to.y], stops.compactMap(Self.stop))
        case .radial(let center, let radius, let stops):
            self.init(kind: 3, geometry: [center.x, center.y, radius, 0], stops.compactMap(Self.stop))
        }
    }

    private init(kind: Int32, geometry: [Double], _ stops: [(offset: Double, argb: UInt32)]) {
        self.kind = kind
        self.geometry = geometry
        colors = stops.map(\.argb)
        offsets = stops.map(\.offset)
    }

    private static func stop(_ stop: HostBrush.Stop) -> (offset: Double, argb: UInt32)? {
        stop.color.argb.map { (stop.offset, $0) }
    }

    /// Runs `body` with the brush as the relay's struct for a box of `size`, its stops held for the call: a radial
    /// gradient's radius per axis, one circle's reach (`HostBrush.reach`) in fractions of each side.
    /// Design: docs/design/platforms/winui/drawing.md#a-box-and-its-brush
    func withRelayBrush<Result>(over size: LayoutSize, _ body: (StateUIBrush) -> Result) -> Result {
        colors.withUnsafeBufferPointer { colors in
            offsets.withUnsafeBufferPointer { offsets in
                var g = geometry
                if followsSize {
                    let reach = HostBrush.reach(of: g[2], width: size.width, height: size.height)
                    (g[2], g[3]) = (size.width > 0 ? reach / size.width : g[2], size.height > 0 ? reach / size.height : g[2])
                }
                return body(StateUIBrush(
                    kind: kind, geometry: (g[0], g[1], g[2], g[3]), count: Int32(colors.count),
                    colors: colors.baseAddress, offsets: offsets.baseAddress))
            }
        }
    }
}
