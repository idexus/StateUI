// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A picture from the application's resources.
    ///
    /// What crosses is the FILE'S NAME, so the view is handed the name and
    /// resolves it through the picture the host gave it - the resources and
    /// the cache over them are the renderer's, and a registration is made once
    /// for the whole process.
    static func pictures(_ registry: Registry<NSView>) {
        registry.add(ImageContract.self, create: { _ in AppKitImageView() }) { image in
            image.applies([
                ImageContract.source, ImageElementContract.aspect, ImageContract.isAnimating,
            ]) { view, values in
                view.apply(
                    source: values[ImageContract.source],
                    aspect: values[ImageElementContract.aspect] ?? .fit,
                    animationPlaying: values[ImageContract.isAnimating] ?? false)
            }
        }
    }
}

#endif
