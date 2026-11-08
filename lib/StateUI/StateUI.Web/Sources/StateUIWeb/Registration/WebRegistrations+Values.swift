// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A Slider and a Stepper: one number the user moves inside its range. The value is written only where the
    /// tree changed it, so a hand on the thumb is never argued with.
    static func values(_ registry: Registry<WebDOMView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = WebSliderView()
            slider.onValueChanged = { moved in reports.report(RangeElementContract.value, moved, as: RangeElementContract.valueChanged) }
            slider.listenForHolding(
                pressed: { reports.raise(PressElementContract.pressed) }, released: { reports.raise(PressElementContract.released) })
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
            slider.declares(PressElementContract.pressed)
            slider.declares(PressElementContract.released)
        })
        registry.add(StepperContract.self, create: { reports in
            let stepper = WebStepperView()
            stepper.onValueChanged = { stepped in
                reports.report(RangeElementContract.value, stepped, as: RangeElementContract.valueChanged)
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
