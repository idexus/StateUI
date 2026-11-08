// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A Slider and a Stepper: one number the user moves inside its range. The value is written only where the tree
    /// changed it, so a hand on the thumb or the spin buttons is never argued with.
    static func values(_ registry: Registry<WinUIView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = WinUISliderView()
            slider.onValueChanged = { moved in
                reports.report(RangeElementContract.value, moved, as: RangeElementContract.valueChanged)
            }
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
            slider.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            slider.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            slider.declares(RangeElementContract.valueChanged)
        })
        registry.add(StepperContract.self, create: { reports in
            let stepper = WinUIStepperView()
            stepper.onValueChanged = { [unowned stepper] stepped in
                reports.report(RangeElementContract.value, stepper.landed(stepped), as: RangeElementContract.valueChanged)
            }
            return stepper
        }, members: { stepper in
            stepper.applies(
                RangeElementContract.value, RangeElementContract.minimum, RangeElementContract.maximum,
                StepperContract.step) { view, values in
                view.apply(
                    value: values.shownStep(standing: view.value),
                    minimum: values.ends.minimum,
                    maximum: values.ends.maximum,
                    step: values.step)
            }
            stepper.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            stepper.declares(RangeElementContract.valueChanged)
        })
    }
}
