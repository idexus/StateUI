// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Slider and a Stepper: one number the user moves inside its range. The value is written only where the
    /// tree changed it, so a hand on the thumb is never argued with.
    static func values(_ registry: Registry<UIView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = UIKitSliderView()
            slider.onValueChanged = { moved in reports.report(RangeElementContract.value, moved, as: RangeElementContract.valueChanged) }
            slider.onPressed = { reports.raise(PressElementContract.pressed) }
            slider.onReleased = { reports.raise(PressElementContract.released) }
            return slider
        }, members: { slider in
            slider.applies(RangeElementContract.value, RangeElementContract.minimum, RangeElementContract.maximum) { view, values in
                view.apply(
                    value: values.written(
                        RangeElementContract.value, within: [RangeElementContract.minimum, RangeElementContract.maximum],
                        standing: Double(view.value)),
                    minimum: values.ends.minimum,
                    maximum: values.ends.maximum)
            }
            slider.property(TintElementContract.tint) { view, tint in
                view.minimumTrackTintColor = tint.flatMap { UIColor(stateUI: $0.propValue) }
            }
            slider.property(EnabledElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            slider.declares(RangeElementContract.valueChanged)
            slider.declares(PressElementContract.pressed)
            slider.declares(PressElementContract.released)
        })
        registry.add(StepperContract.self, create: { reports in
            let stepper = UIKitStepperView()
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
            stepper.property(EnabledElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            stepper.declares(RangeElementContract.valueChanged)
        })
    }
}
#endif
