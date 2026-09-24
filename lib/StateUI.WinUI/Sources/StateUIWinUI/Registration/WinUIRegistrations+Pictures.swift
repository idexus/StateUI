// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// A box of colour.
    static func pictures(_ registry: Registry<WinUIView>) {
        registry.add(ColorBoxContract.self, create: { _ in WinUIColorBoxView() }) { box in
            box.applies([ColorBoxContract.color, ColorBoxContract.cornerRadius]) { view, values in
                view.apply(
                    color: values[ColorBoxContract.color]?.propValue,
                    corners: values[ColorBoxContract.cornerRadius]?.propValue)
            }
        }
    }
}
