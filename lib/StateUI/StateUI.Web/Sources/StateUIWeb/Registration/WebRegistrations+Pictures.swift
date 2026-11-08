// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// An Image: the picture it shows, and how it fits its room.
    static func pictures(_ registry: Registry<WebDOMView>) {
        registry.add(ImageContract.self, create: { _ in WebImageView() }) { image in
            image.applies(ImageContract.source, ContentModeElementContract.contentMode) { view, values in
                view.apply(
                    picture: HostPicture(values[ImageContract.source], dark: false),
                    aspect: values[ContentModeElementContract.contentMode] ?? .fit)
            }
        }
    }
}
