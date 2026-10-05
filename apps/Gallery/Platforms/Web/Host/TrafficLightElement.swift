// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWeb

/// Three lamps in a housing, one lit at a time: the gallery's own element, `<gallery-traffic-light>` of
/// Page/traffic-light.js, which knows nothing of StateUI.
///
/// `register()`, at the end of this file, adds it for `TrafficLightContract`, and that registration is the whole
/// bridge. The Swift half is Sources/Samples/Interop/TrafficLight.swift.
@MainActor
final class TrafficLightElement: WebControl {
    let element = WebPageElement(tag: "gallery-traffic-light")

    /// A lamp was tapped; the argument is its index, top to bottom. The control does not switch itself: it reports,
    /// and whoever owns the state decides.
    var onLampTapped: ((Int) -> Void)?

    /// Which lamp is lit.
    var signal = TrafficSignal.stop {
        didSet { if signal != oldValue { element.setAttribute("signal", String(signal.rawValue)) } }
    }

    init() {
        element.setAttribute("signal", String(signal.rawValue))
        element.listen("lamptap") { [weak self] (index: Double) in self?.onLampTapped?(Int(index)) }
    }
}

// MARK: - Registration

extension TrafficLightElement {
    /// Adds the lamps for `TrafficLightContract`. Said once, before the application runs.
    static func register() {
        StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightElement in
            let light = TrafficLightElement()
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
