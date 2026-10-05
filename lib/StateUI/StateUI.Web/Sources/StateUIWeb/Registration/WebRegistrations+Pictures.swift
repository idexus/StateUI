// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// An Image: the picture it shows, and how it fits its room; a ColorBox: its colour and its corners.
    static func pictures(_ registry: Registry<WebDOMView>) {
        registry.add(ImageContract.self, create: { _ in WebImageView() }) { image in
            image.applies([ImageContract.source, ImageElementContract.contentMode]) { view, values in
                view.apply(source: values[ImageContract.source], aspect: values[ImageElementContract.contentMode] ?? .fit)
            }
        }
        registry.add(ColorBoxContract.self, create: { _ in WebColorBoxView() }) { box in
            box.applies([ColorBoxContract.color, ColorBoxContract.cornerRadius]) { view, values in
                view.apply(color: values[ColorBoxContract.color]?.propValue, corners: values[ColorBoxContract.cornerRadius])
            }
        }
    }
}
