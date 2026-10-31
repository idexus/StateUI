// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIBarAppearance {
    /// Stands a bar - a navigation bar, a tab bar - on `material`: a clear one shows what is behind it with no line
    /// under it, a blur is UIKit's own in its thickness under its tint, glass is the system's own bar, a color paints
    /// it opaque, a gradient is a picture of it as large as the bar's background, `size`; nothing said leaves the
    /// bar's own.
    /// Design: docs/design/platforms/uikit/pages.md#the-bar
    func stand(on material: HostMaterial, size: CGSize) {
        configureWithDefaultBackground()
        if HostBrush(material.painted).isClear {
            configureWithTransparentBackground()
        } else if material.glass != nil {
            return
        } else if let blur = material.blur {
            backgroundEffect = UIBlurEffect(style: UIKitBackdropView.style(blur))
            backgroundColor = material.paint.flatMap(UIColor.init(stateUI:))
        } else if HostBrush(material.painted).isGradient {
            guard let image = UIKitBrush(material.painted).image(size: size) else { return }
            configureWithOpaqueBackground()
            backgroundImage = image
            backgroundImageContentMode = .scaleToFill
        } else if let color = material.painted.flatMap(UIColor.init(stateUI:)) {
            configureWithOpaqueBackground()
            backgroundColor = color
        }
    }
}
#endif
