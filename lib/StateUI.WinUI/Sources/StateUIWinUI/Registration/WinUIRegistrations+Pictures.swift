// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// A picture from the application's folder, and the box of colour beside it.
    static func pictures(_ registry: Registry<WinUIView>) {
        registry.add(ImageContract.self, create: { _ in WinUIImageView() }) { image in
            image.applies([ImageContract.source, ImageElementContract.aspect]) { view, values in
                view.apply(source: values[ImageContract.source], aspect: values[ImageElementContract.aspect] ?? .fit)
            }
        }

        registry.add(ColorBoxContract.self, create: { _ in WinUIColorBoxView() }) { box in
            box.applies([ColorBoxContract.color, ColorBoxContract.cornerRadius]) { view, values in
                view.apply(
                    color: values[ColorBoxContract.color]?.propValue,
                    corners: values[ColorBoxContract.cornerRadius]?.propValue)
            }
        }
    }
}
