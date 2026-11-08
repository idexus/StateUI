// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A picture from the application's folder.
    static func pictures(_ registry: Registry<WinUIView>) {
        registry.add(ImageContract.self, create: { _ in WinUIImageView() }) { image in
            image.applies(ImageContract.source, ContentModeElementContract.contentMode) { view, values in
                view.apply(
                    picture: HostPicture(values[ImageContract.source], dark: false),
                    aspect: values[ContentModeElementContract.contentMode] ?? .fit)
            }
        }
    }
}
