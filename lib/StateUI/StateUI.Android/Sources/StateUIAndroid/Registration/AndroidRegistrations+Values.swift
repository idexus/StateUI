// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A slider and a stepper: one number the user moves inside its range, written as the host layer decides
    /// (`ElementValues.written`).
    static func values(_ registry: Registry<AndroidView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = AndroidSliderView()
            slider.onValueChanged = { moved in
                reports.report(RangeElementContract.value, moved, as: RangeElementContract.valueChanged)
            }
            slider.onPressed = { reports.raise(PressElementContract.pressed) }
            slider.onReleased = { reports.raise(PressElementContract.released) }
            return slider
        }, members: { slider in
            slider.applies(RangeElementContract.value, RangeElementContract.minimum, RangeElementContract.maximum) { view, values in
                view.apply(
                    value: values.written(
                        RangeElementContract.value, within: [RangeElementContract.minimum, RangeElementContract.maximum],
                        standing: view.value),
                    minimum: values.ends.minimum,
                    maximum: values.ends.maximum)
            }
            slider.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            slider.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            slider.declares(RangeElementContract.valueChanged)
            slider.declares(PressElementContract.pressed)
            slider.declares(PressElementContract.released)
        })

        registry.add(StepperContract.self, create: { reports in
            let stepper = AndroidStepperView()
            stepper.onValueChanged = { stepped in
                reports.report(RangeElementContract.value, stepped, as: RangeElementContract.valueChanged)
            }
            return stepper
        }, members: { stepper in
            stepper.applies(
                RangeElementContract.value, RangeElementContract.minimum, RangeElementContract.maximum, StepperContract.step,
                EnabledElementContract.isEnabled) { view, values in
                view.apply(
                    value: values.shownStep(standing: view.value),
                    minimum: values.ends.minimum,
                    maximum: values.ends.maximum,
                    step: values.step,
                    enabled: values[EnabledElementContract.isEnabled] ?? true)
            }
            stepper.declares(RangeElementContract.valueChanged)
        })
    }
}
