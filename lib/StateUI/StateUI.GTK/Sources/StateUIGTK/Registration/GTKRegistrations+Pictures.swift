// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// An Image: its picture and how it fills its room. A ColorBox: its colour and its corners.
    static func pictures(_ registry: Registry<GTKView>) {
        registry.add(ImageContract.self, create: { _ in GTKImageView() }) { image in
            image.applies([ImageContract.source, ImageElementContract.aspect]) { view, values in
                view.apply(source: values[ImageContract.source], aspect: values[ImageElementContract.aspect] ?? .fit)
            }
        }
        registry.add(ColorBoxContract.self, create: { _ in GTKColorBoxView() }) { box in
            box.applies([ColorBoxContract.color, ColorBoxContract.cornerRadius]) { view, values in
                view.apply(
                    color: values[ColorBoxContract.color]?.propValue,
                    corners: values[ColorBoxContract.cornerRadius]?.propValue)
            }
        }
    }
}
