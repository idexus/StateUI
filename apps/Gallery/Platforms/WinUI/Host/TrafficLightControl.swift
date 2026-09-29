// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI

/// Three lamps in a housing, one lit at a time - a XAML Border of three Ellipses the gallery's relay makes, which
/// knows nothing of StateUI.
///
/// `register()`, at the end of this file, adds it for `TrafficLightContract`, and that registration is the whole
/// bridge. The Swift half is Sources/Samples/Interop/TrafficLight.swift.
@MainActor
final class TrafficLightControl: WinUIControl {
    let element: OpaquePointer

    /// A lamp was tapped; the argument is its index, top to bottom. The control does not switch itself: it reports,
    /// and whoever owns the state decides.
    var onLampTapped: ((Int) -> Void)?

    /// Which lamp is lit.
    var signal = TrafficSignal.stop {
        didSet { if signal != oldValue { gallery_traffic_light_set_signal(element, signal.rawValue) } }
    }

    private let number: Int64

    init() {
        number = GalleryControls.reserve()
        element = gallery_traffic_light_make(number)!
        GalleryControls.hold(self, as: number)
    }

    isolated deinit {
        GalleryControls.forget(number)
        gallery_winui_release(element)
    }

    /// The relay says lamp `index` was tapped.
    func tapped(_ index: Int) {
        onLampTapped?(index)
    }
}

// MARK: - Registration

extension TrafficLightControl {
    /// Adds the light for `TrafficLightContract`: `create` makes the control once per element and wires the tap it
    /// reports, and `property` puts the described signal on it. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightControl in
            let light = TrafficLightControl()
            light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
            return light
        }) { light in
            light.property(TrafficLightContract.signal) { control, signal in
                control.signal = signal ?? .stop
            }
            light.raises(TrafficLightContract.lampTapped)
        }
    }
}
