// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A Slider and a Stepper: one number the user moves inside its range. The value is written only where the
    /// tree changed it, so a hand on the thumb is never argued with.
    static func values(_ registry: Registry<GTKView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = GTKSliderView()
            slider.onValueChanged = { moved in
                reports.report(SliderContract.value, moved, as: SliderContract.valueChanged)
            }
            return slider
        }, members: { slider in
            slider.applies([SliderContract.value, SliderContract.minimum, SliderContract.maximum]) { view, values in
                view.apply(
                    value: values.written(
                        SliderContract.value, within: [SliderContract.minimum, SliderContract.maximum],
                        standing: view.value),
                    minimum: values[SliderContract.minimum] ?? 0,
                    maximum: values[SliderContract.maximum] ?? 1)
            }
            slider.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            slider.raises(SliderContract.valueChanged)
        })
        registry.add(StepperContract.self, create: { reports in
            let stepper = GTKStepperView()
            stepper.onValueChanged = { stepped in
                reports.report(StepperContract.value, stepped, as: StepperContract.valueChanged)
            }
            return stepper
        }, members: { stepper in
            stepper.applies([
                StepperContract.value, StepperContract.minimum, StepperContract.maximum, StepperContract.step,
            ]) { view, values in
                view.apply(
                    value: values.written(
                        StepperContract.value, within: [StepperContract.minimum, StepperContract.maximum],
                        standing: view.value),
                    minimum: values[StepperContract.minimum] ?? 0,
                    maximum: values[StepperContract.maximum] ?? 100,
                    step: values[StepperContract.step] ?? 1)
            }
            stepper.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            stepper.raises(StepperContract.valueChanged)
        })
    }
}
