// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A material on a state the host carries: its kind, then what it is made of,
// each colour as it stands - the half in force of every pair in it.
// Design: docs/design/core/state.md#a-material-on-a-carried-state

extension Material: LaneValue {
    /// The material as lanes: its kind - 0 none, 1 a colour, 2 a gradient, 3 a
    /// blur, 4 glass - then what that kind is made of, each colour in the standard
    /// theme. The state that carries a material lays it in the theme in force.
    public var carried: StateCarried {
        .lanes(standingLanes(in: .standard))
    }

    /// The material back from its lanes; a pair's half that is none is a pair
    /// of none.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, let value = Self.propValue(lanes: lanes) else { return nil }
        guard value != .nothing else {
            self.init(light: nil, dark: nil)
            return
        }
        self.init(propValue: value)
    }

    /// As wide as the material is.
    public static var lanes: Int { StateValueLanes.own }

    /// A material.
    public static var laneKind: LaneKind { .material }

    /// The lanes of the material in `theme`.
    private func standingLanes(in theme: ThemeInForce) -> [Double] {
        switch kind {
        case .color(let color):
            return [1] + color.standingLanes(in: theme)
        case .gradient(let brush):
            return [2, Double(brush.kind.rawValue), Double(brush.geometry.count)] + brush.geometry
                + brush.stops.flatMap { [$0.offset] + $0.color.standingLanes(in: theme) }
        case .blur(let blur):
            return [3, Double(blur.thickness.rawValue)] + Self.lanes(tint: blur.tint, in: theme)
                + blur.thickness.standIn.standingLanes(in: theme)
        case .glass(let glass):
            return [4, Double(glass.clarity.rawValue), glass.isInteractive ? 1 : 0] + Self.lanes(tint: glass.tint, in: theme)
                + glass.fallback.standIn.standingLanes(in: theme)
        case .pair(let light, let dark):
            let half = theme.scheme == .dark ? dark : light
            return half?.standingLanes(in: theme) ?? [0]
        }
    }

    /// A tint as five lanes: whether there is one, then its colour.
    private static func lanes(tint: Color?, in theme: ThemeInForce) -> [Double] {
        tint.map { [1] + $0.standingLanes(in: theme) } ?? [0, 0, 0, 0, 0]
    }

    /// The value a host reads the lanes as - the material's own, its stand-in
    /// the one laid; nil for lanes that are no material.
    @_spi(Host) public static func propValue(lanes: [Double]) -> PropValue? {
        var at = 0
        func next() -> Double? {
            guard at < lanes.count else { return nil }
            defer { at += 1 }
            return lanes[at]
        }
        func colour() -> PropValue? {
            guard at + 4 <= lanes.count else { return nil }
            defer { at += 4 }
            return Color(carried: .lanes(Array(lanes[at..<at + 4])))?.propValue
        }
        func tint() -> PropValue? {
            guard let has = next(), let colour = colour() else { return nil }
            return has != 0 ? colour : .nothing
        }

        switch next().map({ Int($0.rounded()) }) {
        case 0:
            return .nothing
        case 1:
            return colour()
        case 2:
            guard let brush = next(), let count = next().map({ Int($0.rounded()) }), count >= 0,
                  at + count <= lanes.count
            else { return nil }
            var values: [PropValue] = [.enumeration(Int32(brush.rounded())), .numbers(Array(lanes[at..<at + count]))]
            at += count
            while at < lanes.count {
                guard let offset = next(), let colour = colour() else { return nil }
                values += [.number(offset), colour]
            }
            return .values(values)
        case 3:
            guard let raw = next(), let thickness = Blur.Thickness(rawValue: Int32(raw.rounded())),
                  let tint = tint(), let standIn = colour()
            else { return nil }
            return .values([.enumeration(4), thickness.propValue, tint, standIn])
        case 4:
            guard let raw = next(), let clarity = Glass.Clarity(rawValue: Int32(raw.rounded())),
                  let interactive = next(), let tint = tint(), let standIn = colour()
            else { return nil }
            let fallback = Glass(clarity: clarity, tint: nil, isInteractive: false).fallback
            return .values([
                .enumeration(5), clarity.propValue, tint, .bool(interactive != 0), fallback.propValue, standIn,
            ])
        default:
            return nil
        }
    }
}

extension Material: ThemeWearing {
    /// Whether any part of it turns with the theme or the accent: a pair, a
    /// colour that does, or a blur or glass - whose stand-in is the theme's.
    var wearsTheTheme: Bool {
        switch kind {
        case .color(let color): color.wearsTheTheme
        case .gradient(let brush): brush.stops.contains { $0.color.wearsTheTheme }
        case .blur, .glass, .pair: true
        }
    }

    /// Each pair's half in force, each colour in force.
    func carried(wearing theme: ThemeInForce) -> StateCarried {
        .lanes(standingLanes(in: theme))
    }
}
