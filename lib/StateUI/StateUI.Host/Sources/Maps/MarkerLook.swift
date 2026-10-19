// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How a map's marker of a kind is drawn, the same on every host drawing one: its hue and the symbol it wears.
/// Design: docs/design/host/maps.md#a-markers-look
@_spi(Host) public struct MarkerLook: Equatable, Sendable {
    /// A marker's hue, drawn as the platform's own colour of that name.
    public enum Hue: Sendable {
        case red, blue, yellow, purple
    }

    public let hue: Hue

    /// The SF Symbol the marker wears - the icons Apple's platforms ship; none for a plain marker.
    public let sfSymbol: String?

    public init(hue: Hue, sfSymbol: String?) {
        self.hue = hue
        self.sfSymbol = sfSymbol
    }

    /// The look of a marker of `type`.
    public init(_ type: MarkerType) {
        switch type {
        case .generic: self.init(hue: .red, sfSymbol: nil)
        case .place: self.init(hue: .blue, sfSymbol: "building.2.fill")
        case .saved: self.init(hue: .yellow, sfSymbol: "star.fill")
        case .searchResult: self.init(hue: .purple, sfSymbol: "magnifyingglass")
        }
    }
}
