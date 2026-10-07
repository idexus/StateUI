// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a surface is made of: a colour, a gradient, a blur of what lies behind
/// it, or the platform's glass - the same in both themes, or one for each.
///
///     Text("Total").background(.tomato)
///     VStack { … }.background(.blur(.thin.tint(.indigo.opacity(0.15))))
///     VStack { … }.background(.glass(.regular))
///     window.background = Material(light: nil, dark: .blur(.thick))
///
/// A blur and glass follow the theme as the platform draws them. A platform
/// with no glass draws the blur as clear as the glass; one that blurs nothing,
/// a colour of the theme let through as the blur is, the tint over it.
/// Design: docs/design/types/colour-and-theme.md#a-material
public struct Material: Equatable, Sendable, HostRepresentable {
    /// What the surface is, one kind or a pair.
    indirect enum Kind: Equatable, Sendable {
        case color(Color)
        case gradient(Brush)
        case blur(Blur)
        case glass(Glass)
        case pair(light: Material?, dark: Material?)
    }

    let kind: Kind

    private init(_ kind: Kind) {
        self.kind = kind
    }

    /// One colour - which a colour with an alpha lets what lies behind through.
    public static func color(_ color: Color) -> Material {
        Material(.color(color))
    }

    /// A gradient; a brush of one colour is that colour.
    public static func gradient(_ brush: Brush) -> Material {
        brush.kind == .solidColor ? .color(brush.stops[0].color) : Material(.gradient(brush))
    }

    /// A blur of what lies behind the surface.
    public static func blur(_ blur: Blur) -> Material {
        Material(.blur(blur))
    }

    /// The platform's glass.
    public static func glass(_ glass: Glass) -> Material {
        Material(.glass(glass))
    }

    /// `light` in the light theme and `dark` in the dark one; a nil half is the
    /// platform's own - a window's, a bar's - or no background at all.
    public init(light: Material?, dark: Material?) {
        if case .color(let day)? = light?.kind, case .color(let night)? = dark?.kind, day.dark == nil, night.dark == nil {
            self = .color(Color(light: day, dark: night))
        } else {
            self.init(.pair(light: light, dark: dark))
        }
    }

    /// What a host with no glass draws for this material: glass's blur, as clear as the glass, in its tint; any
    /// other material is itself.
    @_spi(Host) public var withoutGlass: Material {
        guard case .glass(let glass) = kind else { return self }
        return .blur(Blur(thickness: glass.fallback, tint: glass.tint))
    }

    /// A colour as itself and a gradient as its brush - so a colour's channel
    /// is a material's - a blur and glass as their kind, what the kind takes,
    /// and last what stands in for it; a pair as its two halves.
    /// Design: docs/design/types/colour-and-theme.md#a-material
    public var propValue: PropValue {
        switch kind {
        case .color(let color): color.propValue
        case .gradient(let brush): brush.propValue
        case .blur(let blur):
            .values([
                .enumeration(4), blur.thickness.propValue, blur.tint?.propValue ?? .nothing,
                blur.thickness.standIn.propValue,
            ])
        case .glass(let glass):
            .values([
                .enumeration(5), glass.clarity.propValue, glass.tint?.propValue ?? .nothing,
                .bool(glass.isInteractive), glass.fallback.propValue, glass.fallback.standIn.propValue,
            ])
        case .pair(let light, let dark):
            .themed(light: light?.propValue ?? .nothing, dark: dark?.propValue ?? .nothing)
        }
    }

    /// A material back - nil for anything else, and for nothing.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        if case .themed(let light, let dark) = propValue {
            if let color = Color(propValue: propValue) {
                self = .color(color)
            } else {
                self.init(light: Material(propValue: light), dark: Material(propValue: dark))
            }
            return
        }
        if let color = Color(propValue: propValue) {
            self = .color(color)
            return
        }
        if let brush = Brush(propValue: propValue) {
            self = .gradient(brush)
            return
        }
        guard let parts = propValue.values, let kind = parts.first?.enumeration else { return nil }
        switch kind {
        case 4:
            guard parts.count > 2, let thickness = Blur.Thickness(propValue: parts[1]) else { return nil }
            let blur = Blur(thickness: thickness, tint: nil)
            self = .blur(Color(propValue: parts[2]).map(blur.tint) ?? blur)
        case 5:
            guard parts.count > 3, let clarity = Glass.Clarity(propValue: parts[1]) else { return nil }
            self = .glass(Glass(clarity: clarity, tint: Color(propValue: parts[2]), isInteractive: parts[3].bool == true))
        default:
            return nil
        }
    }
}
