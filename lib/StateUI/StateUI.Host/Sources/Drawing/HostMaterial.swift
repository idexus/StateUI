// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A material as every host reads what the tree sends: what paints the surface - a colour or a gradient, or the tint
/// over a blur or glass - the blur behind it, the platform's glass, and the colour a host that blurs nothing draws in
/// the blur's place; each host draws the first its toolkit has. A pair still in the value - a registration reading
/// the member as its type encodes it again - is the half of the theme in force.
/// Design: docs/design/types/colour-and-theme.md#a-material
@_spi(Host) public struct HostMaterial: Equatable, Sendable {
    /// The platform's glass, as the tree asks for it.
    public struct Glass: Equatable, Sendable {
        /// Whether the glass is the clearer kind, which lets more through.
        public let isClear: Bool

        /// Whether it answers the user's touch and pointer.
        public let isInteractive: Bool
    }

    /// What paints the surface: its colour or gradient, or the tint over its blur or glass; nil for none.
    public let paint: HostValue?

    /// The blur behind the surface - a blur's own, or the one a host with no glass draws for it; nil for none.
    public let blur: Blur.Thickness?

    /// The glass, where the material is glass.
    public let glass: Glass?

    /// The colour a host that blurs nothing draws for the blur; nil where there is no blur.
    public let standIn: HostValue?

    /// The material the tree's `value` describes - nothing at all for no value.
    @MainActor public init(_ value: HostValue?) {
        let value = value.map(Self.wearing) ?? .nothing
        guard let parts = value.values, let kind = parts.first?.enumeration, kind >= 4 else {
            paint = value == .nothing ? nil : value
            (blur, glass, standIn) = (nil, nil, nil)
            return
        }
        let tint = parts.count > 2 && parts[2] != .nothing ? parts[2] : nil
        if kind == 4, parts.count == 4, let thickness = Blur.Thickness(propValue: parts[1]) {
            (paint, blur, glass, standIn) = (tint, thickness, nil, parts[3])
        } else if kind == 5, parts.count == 6, let clarity = parts[1].enumeration,
                  let thickness = Blur.Thickness(propValue: parts[4]) {
            let glass = Glass(isClear: clarity == 1, isInteractive: parts[3].bool == true)
            (paint, blur, self.glass, standIn) = (tint, thickness, glass, parts[5])
        } else {
            (paint, blur, glass, standIn) = (nil, nil, nil, nil)
        }
    }

    /// Whether the tree says nothing: the platform's own, or no background.
    public var isEmpty: Bool {
        paint == nil && blur == nil
    }

    /// What a host that blurs nothing paints: the paint laid over the stand-in - a colour, or each of a gradient's
    /// colours - the stand-in alone where nothing paints it, the paint alone where there is no blur; nil for none.
    public var painted: HostValue? {
        guard let standIn else { return paint }
        guard let paint else { return standIn }
        if paint.color != nil { return Self.over(paint, standIn) }
        guard let parts = paint.values else { return standIn }
        return .values(parts.map { $0.color != nil ? Self.over($0, standIn) : $0 })
    }

    /// `top` laid over `bottom`, as a colour with an alpha lies over another: what shows through it is tinted by
    /// it in its share.
    static func over(_ top: HostValue, _ bottom: HostValue) -> HostValue {
        guard case .color(let r, let g, let b, let a) = top, case .color(let br, let bg, let bb, let ba) = bottom
        else { return top }
        let alpha = Double(a) / 255, under = Double(ba) / 255 * (1 - alpha)
        let out = alpha + under
        guard out > 0 else { return .color(red: 0, green: 0, blue: 0, alpha: 0) }
        func channel(_ top: UInt8, _ bottom: UInt8) -> UInt8 {
            UInt8(((Double(top) * alpha + Double(bottom) * under) / out).rounded())
        }
        return .color(red: channel(r, br), green: channel(g, bg), blue: channel(b, bb), alpha: UInt8((out * 255).rounded()))
    }

    /// `value` with every pair in it taken as the half the theme in force wears.
    @MainActor static func wearing(_ value: HostValue) -> HostValue {
        switch value {
        case .themed(let light, let dark): wearing(HostThemes.current == .dark ? dark : light)
        case .values(let parts): .values(parts.map(wearing))
        default: value
        }
    }
}
