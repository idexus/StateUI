// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A ground as the relay takes it - a split view's pane's, a sheet's card's: WinUI's own, a color, or the in-app
/// acrylic - a blur at its thickness, in its color, the tint over the theme's.
/// Design: docs/design/platforms/winui/pages.md#a-split-view
struct WinUIGround: Equatable {
    var kind: StateUIGround = .own
    var argb: UInt32 = 0
    var opacity: Float = 0
    var tintOpacity: Float = 0

    /// The ground `material` is, the color `page` standing in for none. `over` the page, a color the page would show
    /// through stands as the in-app acrylic WinUI lays there, tinted in it as far as it is opaque.
    /// Design: docs/design/platforms/winui/pages.md#a-split-view
    @MainActor init(_ material: HostMaterial, page: UInt32? = nil, over: Bool = false) {
        if let thickness = material.blur, let color = material.painted.flatMap({ HostBrush($0).firstColor })?.argb {
            let acrylic = WinUIWindow.acrylic(thickness)
            (kind, argb, opacity, tintOpacity) = (.acrylic, color, acrylic.opacity, acrylic.tintOpacity)
        } else if let color = material.paint.flatMap({ HostBrush($0).firstColor })?.argb ?? page {
            (kind, argb) = (.color, color)
            if over, color >> 24 < 255 {
                let acrylic = WinUIWindow.acrylic(.regular)
                (kind, opacity, tintOpacity) = (.acrylic, acrylic.opacity, Float(color >> 24) / 255)
            }
        }
    }
}
