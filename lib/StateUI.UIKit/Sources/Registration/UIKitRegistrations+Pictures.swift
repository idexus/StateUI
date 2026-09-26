// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// An Image - one of the application's pictures, filling its room as its aspect says - and a ColorBox: one colour
    /// with its corners rounded.
    static func pictures(_ registry: Registry<UIView>) {
        registry.add(ImageContract.self, create: { _ in UIKitImageView() }) { image in
            image.applies([ImageContract.source, ImageElementContract.aspect]) { view, values in
                view.apply(source: values[ImageContract.source], aspect: values[ImageElementContract.aspect] ?? .fit)
            }
        }
        registry.add(ColorBoxContract.self, create: { _ in UIKitColorBoxView() }) { box in
            box.applies([ColorBoxContract.color, ColorBoxContract.cornerRadius]) { view, values in
                view.apply(
                    color: values[ColorBoxContract.color]?.propValue,
                    corners: values[ColorBoxContract.cornerRadius]?.propValue)
            }
        }
    }
}
#endif
