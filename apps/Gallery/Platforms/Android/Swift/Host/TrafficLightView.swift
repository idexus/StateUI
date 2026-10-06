// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import GalleryUI
import StateUIAndroid

// listing: InteropControlSample.Android.swift
/// Three lamps in a dark housing, one lit: the gallery's own Java view, com.stateui.gallery.TrafficLightView, which
/// knows nothing of StateUI. The Swift half is Sources/Samples/Interop/TrafficLight.swift.
@MainActor
final class TrafficLightView: AndroidControl {
    let view: JavaObject

    /// A lamp was tapped; the argument is its index, top to bottom. The light does not switch itself: it reports,
    /// and whoever owns the state decides.
    var onLampTapped: ((Int) -> Void)?

    /// Which lamp is lit.
    var signal = TrafficSignal.stop {
        didSet { if signal != oldValue { Java.call(view.reference, Self.setSignal, .int(signal.rawValue)) } }
    }

    private let number: Int64

    private static let viewClass = Java.findClass("com/stateui/gallery/TrafficLightView")
    private static let make = Java.method(viewClass, "<init>", "(Landroid/content/Context;J)V")
    private static let setSignal = Java.method(viewClass, "setSignal", "(I)V")

    init() {
        number = GalleryControls.reserve()
        view = Java.new(Self.viewClass, Self.make, .object(StateUIAndroid.context), .long(number))
        Java.call(view.reference, Self.setSignal, .int(signal.rawValue))
        GalleryControls.hold(self, as: number)
    }

    isolated deinit {
        GalleryControls.forget(number)
    }

    /// The view says lamp `index` was tapped.
    /// It reaches here through a native method of the gallery's, GalleryNatives.lampTapped, by this control's number.
    func tapped(_ index: Int) {
        onLampTapped?(index)
    }
}

extension TrafficLightView {
    /// Adds the light for `TrafficLightContract`: `create` makes the control once per element and wires the tap it
    /// reports, and `property` puts the described signal on it. Said once, as the library loads.
    @MainActor
    static func register() {
        StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
            let light = TrafficLightView()
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
// listing: end
