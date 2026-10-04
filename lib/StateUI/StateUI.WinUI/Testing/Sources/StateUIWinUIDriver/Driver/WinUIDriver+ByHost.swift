// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance

/// What the WinUI driver reads by the host's own rather than WinUI's.
extension WinUIDriver {
    func byHost(_ ability: String) -> String? {
        let direction = "read layoutDirection of "
        if ability.hasPrefix(direction), Self.standsLeftToRight.contains(String(ability.dropFirst(direction.count))) {
            return "the direction the host lays it out in: in WinUI it stands left to right, where a layout told right "
                + "to left would mirror its places again and a drawing would be turned"
        }
        if ability.hasPrefix("read rotationX of ") || ability.hasPrefix("read rotationY of ") {
            return "the host's own tip, checked against the projection it laid on the element"
        }
        return nil
    }

    /// The elements whose views stand left to right in WinUI whatever their direction (`WinUIView.directionHolder`):
    /// the layouts, the drawings, and a web view, whose page says its own.
    static let standsLeftToRight: Set<String> = [
        "ActivityIndicator", "Canvas", "ColorBox", "Ellipse", "Grid", "HStack", "Image", "Line", "Path", "Polygon",
        "Polyline", "Rectangle", "ScrollView", "VStack", "WebView", "ZStack",
    ]
}
