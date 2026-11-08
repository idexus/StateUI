// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A picture from the application's resources.
    static func pictures(_ registry: Registry<AndroidView>) {
        registry.add(ImageContract.self, create: { _ in AndroidImageView() }) { image in
            image.applies(ImageContract.source, ContentModeElementContract.contentMode) { view, values in
                view.apply(
                    picture: HostPicture(values[ImageContract.source], dark: false),
                    aspect: values[ContentModeElementContract.contentMode] ?? .fit)
            }
        }
    }
}
