// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension GTKRegistrations {
    /// A ColorBox: its colour and its corners.
    static func pictures(_ registry: Registry<GTKView>) {
        registry.add(ColorBoxContract.self, create: { _ in GTKColorBoxView() }) { box in
            box.applies([ColorBoxContract.color, ColorBoxContract.cornerRadius]) { view, values in
                view.apply(
                    color: values[ColorBoxContract.color]?.propValue,
                    corners: values[ColorBoxContract.cornerRadius]?.propValue)
            }
        }
    }
}
