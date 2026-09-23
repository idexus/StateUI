// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension AndroidRegistrations {
    /// A Slider: one number the user moves inside its range. The value is written only where
    /// the tree changed it, so a hand on the thumb is never argued with.
    static func values(_ registry: Registry<AndroidView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = AndroidSliderView()
            slider.onValueChanged = { moved in
                reports.report(SliderContract.value, moved, as: SliderContract.valueChanged)
            }
            slider.onDragStarted = { reports.raise(SliderContract.dragStarted) }
            slider.onDragCompleted = { reports.raise(SliderContract.dragCompleted) }
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
            slider.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            slider.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            slider.raises(SliderContract.valueChanged)
            slider.raises(SliderContract.dragStarted)
            slider.raises(SliderContract.dragCompleted)
        })
    }
}
