// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A backdrop as every host reads what the tree sends: the platform's glass, where the tree asks for glass, the
/// material a host with no glass draws in its place, and the colour a host with no materials draws - each host
/// draws the first its toolkit has. The colour may come as a pair - a registration reading the member as its type
/// encodes it again - and is then the half of the theme in force.
/// Design: docs/design/types/colour-and-theme.md#a-backdrop
@_spi(Host) public struct HostBackdrop: Equatable, Sendable {
    /// The platform's glass, as the tree asks for it.
    public struct Glass: Equatable, Sendable {
        /// Whether the glass is the clearer kind, which lets more through.
        public let isClear: Bool

        /// The colour it is tinted with, as the tree gives it; nil for none.
        public let tint: HostValue?

        /// Whether it answers the user's touch and pointer.
        public let isInteractive: Bool
    }

    /// The glass, where the tree asks for glass; nil for a material.
    public let glass: Glass?

    /// The material: the one asked for, or the glass's in its place.
    public let material: Material

    /// The colour a host with no materials draws in the material's place.
    public let standIn: HostValue

    /// The backdrop the tree's `value` describes; nil for none.
    @MainActor public init?(_ value: HostValue?) {
        guard let parts = value?.values, let kind = parts.first?.enumeration else { return nil }
        switch kind {
        case 1:
            guard parts.count == 3, let material = Material(propValue: parts[1]), let standIn = Self.colour(parts[2])
            else { return nil }
            glass = nil
            self.material = material
            self.standIn = standIn
        case 2:
            guard parts.count == 6, let clarity = parts[1].enumeration, let material = Material(propValue: parts[4]),
                  let standIn = Self.colour(parts[5])
            else { return nil }
            glass = Glass(isClear: clarity == 1, tint: Self.colour(parts[2]), isInteractive: parts[3].bool == true)
            self.material = material
            self.standIn = standIn
        default:
            return nil
        }
    }

    /// What a host with no materials paints for the box: `fill` laid over the stand-in - its colour, or each of
    /// its gradient's colours, laid over it - and the stand-in alone where nothing fills the box.
    public func painted(under fill: HostValue?) -> HostValue {
        guard let fill else { return standIn }
        if fill.color != nil { return Self.over(fill, standIn) }
        guard let parts = fill.values else { return standIn }
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

    /// `value` as one colour: itself, or the half of a pair the theme in force wears; nil for no colour.
    @MainActor private static func colour(_ value: HostValue) -> HostValue? {
        if value.color != nil { return value }
        guard case .themed(let light, let dark) = value else { return nil }
        return colour(HostThemes.current == .dark ? dark : light)
    }
}
