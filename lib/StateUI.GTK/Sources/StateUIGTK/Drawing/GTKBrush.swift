// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A fill: nothing, one colour, or a gradient's stops over a geometry in fractions of what it paints.
/// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
enum GTKBrush: Equatable {
    case none
    case solid(GdkRGBA)
    case linear(from: (Double, Double), to: (Double, Double), stops: [GTKColorStop])
    case radial(center: (Double, Double), radius: Double, stops: [GTKColorStop])

    /// The brush the tree's `value` describes, read by the host layer's rule (`HostBrush`), in GDK's colours.
    init(_ value: HostValue?) {
        switch HostBrush(value) {
        case .none: self = .none
        case .solid(let color): self = GTKBrush.rgba(color).map { .solid($0) } ?? .none
        case .linear(let from, let to, let stops):
            self = .linear(from: (from.x, from.y), to: (to.x, to.y), stops: GTKBrush.stops(stops))
        case .radial(let center, let radius, let stops):
            self = .radial(center: (center.x, center.y), radius: radius, stops: GTKBrush.stops(stops))
        }
    }

    /// A gradient's stops in GDK's colours.
    private static func stops(_ stops: [HostBrush.Stop]) -> [GTKColorStop] {
        stops.compactMap { stop in rgba(stop.color).map { GTKColorStop(offset: stop.offset, color: $0) } }
    }

    /// The brush's colour, or its first stop's - what a line of one colour draws with it.
    var firstColor: GdkRGBA? {
        switch self {
        case .none: nil
        case .solid(let color): color
        case .linear(_, _, let stops), .radial(_, _, let stops): stops.first?.color
        }
    }

    /// A colour as GDK's.
    static func rgba(_ value: HostValue) -> GdkRGBA? {
        guard let channels = value.color else { return nil }
        return GdkRGBA(
            red: Float(channels.red) / 255, green: Float(channels.green) / 255,
            blue: Float(channels.blue) / 255, alpha: Float(channels.alpha) / 255)
    }

    /// Paints `bounds` with the brush.
    func paint(_ snapshot: OpaquePointer, _ bounds: graphene_rect_t) {
        var bounds = bounds
        let (x, y) = (Double(bounds.origin.x), Double(bounds.origin.y))
        let (width, height) = (Double(bounds.size.width), Double(bounds.size.height))
        func point(_ fraction: (Double, Double)) -> graphene_point_t {
            graphene_point_t(x: Float(x + fraction.0 * width), y: Float(y + fraction.1 * height))
        }

        switch self {
        case .none:
            return
        case .solid(var color):
            gtk_snapshot_append_color(snapshot, &color, &bounds)
        case .linear(let from, let to, let stops):
            var start = point(from)
            var end = point(to)
            let native = stops.map(\.native)
            native.withUnsafeBufferPointer {
                gtk_snapshot_append_linear_gradient(snapshot, &bounds, &start, &end, $0.baseAddress, gsize($0.count))
            }
        case .radial(let center, let radius, let stops):
            var middle = point(center)
            let native = stops.map(\.native)
            native.withUnsafeBufferPointer {
                gtk_snapshot_append_radial_gradient(
                    snapshot, &bounds, &middle, Float(radius * width), Float(radius * height), 0, 1,
                    $0.baseAddress, gsize($0.count))
            }
        }
    }

    static func == (lhs: GTKBrush, rhs: GTKBrush) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): true
        case (.solid(let a), .solid(let b)): GTKColorStop.same(a, b)
        case (.linear(let a, let b, let c), .linear(let d, let e, let f)): a == d && b == e && c == f
        case (.radial(let a, let b, let c), .radial(let d, let e, let f)): a == d && b == e && c == f
        default: false
        }
    }
}

/// A gradient's stop: where it stands, from 0 to 1, and its colour.
struct GTKColorStop: Equatable {
    let offset: Double
    let color: GdkRGBA

    var native: GskColorStop { GskColorStop(offset: Float(offset), color: color) }

    static func == (lhs: GTKColorStop, rhs: GTKColorStop) -> Bool {
        lhs.offset == rhs.offset && same(lhs.color, rhs.color)
    }

    /// Whether two colours are the same, channel for channel.
    static func same(_ a: GdkRGBA, _ b: GdkRGBA) -> Bool {
        a.red == b.red && a.green == b.green && a.blue == b.blue && a.alpha == b.alpha
    }
}
