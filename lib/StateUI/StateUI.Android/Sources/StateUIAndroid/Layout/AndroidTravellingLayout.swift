// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout whose children animate to the places a patch gives them.
/// Design: docs/design/host/motion.md#layout-motion
@MainActor
class AndroidTravellingLayout: AndroidLayoutView {
    /// How the children travel to their places, by the host layer's rule.
    let places = TravellingPlaces()

    /// Starts an arrangement `width` points wide, deciding once for every child how it is placed.
    func beginArrangement(width: Double) {
        places.begin(width: width)
    }

    /// Stands `item` at `place`, or on its way there.
    func place(_ item: AndroidLayoutItem, at place: Rect) {
        places.place(item.view, mount: item.mount, at: place, values: item.values, fadeIn: item.fadeIn)
    }
}
