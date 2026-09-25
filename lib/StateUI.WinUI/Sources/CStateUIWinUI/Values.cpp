// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls that hold one number the user moves: a slider over its range,
// and a stepper - WinUI's NumberBox, its spin buttons beside its number - each
// move told through `valueChanged`.

#include "Automation.h"

#include <algorithm>
#include <cmath>

#include <winrt/Windows.Globalization.NumberFormatting.h>

using namespace stateui;
namespace numbers = winrt::Windows::Globalization::NumberFormatting;

extern "C" StateUIObjectRef stateui_winui_slider_make(int64_t view) {
    try {
        controls::Slider slider;
        slider.ValueChanged([view](IInspectable const &, controls::Primitives::RangeBaseValueChangedEventArgs const &args) {
            callbacks.valueChanged(view, args.NewValue());
        });
        return detach(slider);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a slider");
        return nullptr;
    }
}

extern "C" void stateui_winui_slider_set(StateUIObjectRef handle, double value, double minimum, double maximum) {
    try {
        auto slider = borrow<controls::Slider>(handle);
        auto lower = std::min(minimum, maximum);
        auto upper = std::max(minimum, maximum);
        auto step = upper > lower ? (upper - lower) / 10000 : 1;
        if (slider.Minimum() != lower || slider.Maximum() != upper) {
            // Widened first, so neither end clamps the value on its way.
            slider.Minimum(std::min(lower, slider.Minimum()));
            slider.Maximum(std::max(upper, slider.Maximum()));
            // A drag lands on a ten-thousandth of the range; an arrow key moves a hundredth, Page Up a tenth.
            slider.StepFrequency(step);
            slider.SmallChange((upper - lower) / 100);
            slider.LargeChange((upper - lower) / 10);
            slider.Minimum(lower);
            slider.Maximum(upper);
        }
        auto kept = std::min(std::max(value, lower), upper);
        if (slider.Value() != kept) slider.Value(kept);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a slider");
    }
}

extern "C" void stateui_winui_slider_steps(StateUIObjectRef handle, double *steps) {
    try {
        auto slider = borrow<controls::Slider>(handle);
        steps[0] = slider.SmallChange();
        steps[1] = slider.LargeChange();
        steps[2] = slider.StepFrequency();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a slider's steps");
    }
}

extern "C" double stateui_winui_slider_value(StateUIObjectRef handle) {
    try {
        return borrow<controls::Slider>(handle).Value();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a slider");
        return 0;
    }
}


extern "C" StateUIObjectRef stateui_winui_stepper_make(int64_t view) {
    try {
        controls::NumberBox box;
        box.SpinButtonPlacementMode(controls::NumberBoxSpinButtonPlacementMode::Inline);
        box.ValidationMode(controls::NumberBoxValidationMode::InvalidInputOverwritten);
        box.ValueChanged([view](controls::NumberBox const &, controls::NumberBoxValueChangedEventArgs const &args) {
            // An emptied box holds no number: it keeps the one it had.
            if (!std::isnan(args.NewValue())) callbacks.valueChanged(view, args.NewValue());
        });
        return detach(box);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a stepper");
        return nullptr;
    }
}

extern "C" void stateui_winui_stepper_set(
    StateUIObjectRef handle, double value, double minimum, double maximum, double step, int32_t fractionDigits
) {
    try {
        auto box = borrow<controls::NumberBox>(handle);
        box.Minimum(std::min(minimum, maximum));
        box.Maximum(std::max(minimum, maximum));
        // A spin button and an arrow key move one step, Page Up ten.
        box.SmallChange(step);
        box.LargeChange(step * 10);
        // The number in the user's own way of writing it, with as many decimals as the steps take.
        numbers::DecimalFormatter formatter;
        formatter.IntegerDigits(1);
        formatter.FractionDigits(fractionDigits);
        box.NumberFormatter(formatter);
        auto kept = std::clamp(value, box.Minimum(), box.Maximum());
        if (box.Value() != kept) box.Value(kept);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a stepper");
    }
}

extern "C" double stateui_winui_stepper_value(StateUIObjectRef handle) {
    try {
        return borrow<controls::NumberBox>(handle).Value();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a stepper");
        return 0;
    }
}

extern "C" void stateui_winui_value_move(StateUIObjectRef handle, double value) {
    try {
        pattern<provider::IRangeValueProvider>(as<xaml::UIElement>(handle), PatternInterface::RangeValue).SetValue(value);
    } catch (winrt::hresult_error const &error) {
        report(error, "moving a value as the user");
    }
}
