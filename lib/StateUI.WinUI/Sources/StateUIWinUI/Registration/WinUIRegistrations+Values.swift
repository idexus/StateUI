// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// A Slider: one number the user moves inside its range. The value is written only where the tree changed
    /// it, so a hand on the thumb is never argued with.
    static func values(_ registry: Registry<WinUIView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = WinUISliderView()
            slider.onValueChanged = { moved in
                reports.report(SliderContract.value, moved, as: SliderContract.valueChanged)
            }
            return slider
        }, members: { slider in
            slider.applies([SliderContract.value, SliderContract.minimum, SliderContract.maximum]) { view, values in
                let moved = values[SliderContract.value]
                view.apply(
                    value: moved,
                    writeValue: values.changed(SliderContract.value) && moved != nil,
                    minimum: values[SliderContract.minimum] ?? 0,
                    maximum: values[SliderContract.maximum] ?? 1)
            }
            slider.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            slider.raises(SliderContract.valueChanged)
        })
    }
}
