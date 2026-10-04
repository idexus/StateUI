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
                reports.report(SliderContract.value, moved, as: SliderContract.valueChanged)
            }
            slider.onPressed = { reports.raise(SliderContract.pressed) }
            slider.onReleased = { reports.raise(SliderContract.released) }
            return slider
        }, members: { slider in
            slider.applies([
                SliderContract.value, SliderContract.minimum, SliderContract.maximum,
                TintElementContract.tint, VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    value: values.written(
                        SliderContract.value, within: [SliderContract.minimum, SliderContract.maximum],
                        standing: view.doubleValue),
                    minimum: values[SliderContract.minimum] ?? 0,
                    maximum: values[SliderContract.maximum] ?? 1,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            slider.raises(SliderContract.valueChanged)
            slider.raises(SliderContract.pressed)
            slider.raises(SliderContract.released)
        })

        registry.add(StepperContract.self, create: { reports in
            let stepper = AppKitStepperView()
            stepper.onValueChanged = { stepped in
                reports.report(StepperContract.value, stepped, as: StepperContract.valueChanged)
            }
            return stepper
        }, members: { stepper in
            stepper.applies([
                StepperContract.value, StepperContract.minimum, StepperContract.maximum,
                StepperContract.step, VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    value: values.written(
                        StepperContract.value, within: [StepperContract.minimum, StepperContract.maximum],
                        standing: view.doubleValue),
                    minimum: values[StepperContract.minimum] ?? 0,
                    maximum: values[StepperContract.maximum] ?? 100,
                    step: values[StepperContract.step] ?? 1,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            stepper.raises(StepperContract.valueChanged)
        })
    }
}

#endif
