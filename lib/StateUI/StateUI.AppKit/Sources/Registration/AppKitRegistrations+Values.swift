// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A slider and a stepper: one number the user moves, inside the range its element describes, written as the host
    /// layer decides (`ElementValues.written`).
    static func values(_ registry: Registry<NSView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = AppKitSliderView()
            slider.onValueChanged = { moved in
                reports.report(RangeElementContract.value, moved, as: RangeElementContract.valueChanged)
            }
            slider.onPressed = { reports.raise(PressElementContract.pressed) }
            slider.onReleased = { reports.raise(PressElementContract.released) }
            return slider
        }, members: { slider in
            slider.applies(
                RangeElementContract.value, RangeElementContract.minimum, RangeElementContract.maximum, TintElementContract.tint,
                EnabledElementContract.isEnabled) { view, values in
                view.apply(
                    value: values.written(
                        RangeElementContract.value, within: [RangeElementContract.minimum, RangeElementContract.maximum],
                        standing: view.doubleValue),
                    minimum: values.ends.minimum,
                    maximum: values.ends.maximum,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    enabled: values[EnabledElementContract.isEnabled] ?? true)
            }
            slider.declares(RangeElementContract.valueChanged)
            slider.declares(PressElementContract.pressed)
            slider.declares(PressElementContract.released)
        })

        registry.add(StepperContract.self, create: { reports in
            let stepper = AppKitStepperView()
            stepper.onValueChanged = { stepped in
                reports.report(RangeElementContract.value, stepped, as: RangeElementContract.valueChanged)
            }
            return stepper
        }, members: { stepper in
            stepper.applies(
                RangeElementContract.value, RangeElementContract.minimum, RangeElementContract.maximum, StepperContract.step,
                EnabledElementContract.isEnabled) { view, values in
                view.apply(
                    value: values.shownStep(standing: view.doubleValue),
                    minimum: values.ends.minimum,
                    maximum: values.ends.maximum,
                    step: values.step,
                    enabled: values[EnabledElementContract.isEnabled] ?? true)
            }
            stepper.declares(RangeElementContract.valueChanged)
        })
    }
}

#endif
