// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout whose children travel to their places by the host layer's rule (`TravellingPlaces`).
/// Design: docs/design/host/motion.md#layout-motion
@MainActor
class WinUITravellingLayout: WinUILayoutView {
    /// Where the children travel to their places.
    let places = TravellingPlaces()

    func beginArrangement(width: Double) {
        places.begin(width: width)
    }

    /// Stands `item` at `place`, or on its way there.
    func place(_ item: WinUILayoutItem, at place: Rect) {
        places.place(item.view, mount: item.mount, at: place, values: item.values, fadeIn: item.fadeIn)
    }
}
