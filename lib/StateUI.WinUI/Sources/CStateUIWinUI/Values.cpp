// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls that hold one number the user moves: a slider over its range,
// and a stepper - WinUI's NumberBox, its spin buttons beside its number - each
// move told through `valueChanged`.

#include "Automation.h"

#include <algorithm>
#include <cmath>
#include <memory>
#include <vector>

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
    } catch (...) {
        report("making a slider");
        return nullptr;
    }
}

extern "C" void stateui_winui_slider_set(
    StateUIObjectRef handle, double value, double lower, double upper, double key, double page, double drag
) {
    try {
        auto slider = borrow<controls::Slider>(handle);
        if (slider.Minimum() != lower || slider.Maximum() != upper) {
            // Widened first, so neither end clamps the value on its way.
            slider.Minimum(std::min(lower, slider.Minimum()));
            slider.Maximum(std::max(upper, slider.Maximum()));
            slider.StepFrequency(drag);
            slider.SmallChange(key);
            slider.LargeChange(page);
            slider.Minimum(lower);
            slider.Maximum(upper);
        }
        auto kept = std::min(std::max(value, lower), upper);
        if (slider.Value() != kept) slider.Value(kept);
    } catch (...) {
        report("setting a slider");
    }
}

extern "C" void stateui_winui_slider_steps(StateUIObjectRef handle, double *steps) {
    try {
        auto slider = borrow<controls::Slider>(handle);
        steps[0] = slider.SmallChange();
        steps[1] = slider.LargeChange();
        steps[2] = slider.StepFrequency();
    } catch (...) {
        report("reading a slider's steps");
    }
}

extern "C" double stateui_winui_slider_value(StateUIObjectRef handle) {
    try {
        return borrow<controls::Slider>(handle).Value();
    } catch (...) {
        report("reading a slider");
        return 0;
    }
}


extern "C" StateUIObjectRef stateui_winui_stepper_make(int64_t view) {
    try {
        controls::NumberBox box;
        box.SpinButtonPlacementMode(controls::NumberBoxSpinButtonPlacementMode::Inline);
        box.ValidationMode(controls::NumberBoxValidationMode::InvalidInputOverwritten);
        // Words that say no number leave the number where it was: the box is given it back, and nobody hears it.
        auto restoring = std::make_shared<bool>(false);
        box.ValueChanged([view, restoring](controls::NumberBox const &box, controls::NumberBoxValueChangedEventArgs const &args) {
            if (*restoring) return;
            if (std::isnan(args.NewValue())) {
                *restoring = true;
                if (!std::isnan(args.OldValue())) box.Value(args.OldValue());
                *restoring = false;
                return;
            }
            callbacks.valueChanged(view, args.NewValue());
        });
        return detach(box);
    } catch (...) {
        report("making a stepper");
        return nullptr;
    }
}

extern "C" void stateui_winui_stepper_set(
    StateUIObjectRef handle, double value, double lower, double upper, double step, int32_t fractionDigits
) {
    try {
        auto box = borrow<controls::NumberBox>(handle);
        box.Minimum(lower);
        box.Maximum(upper);
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
    } catch (...) {
        report("setting a stepper");
    }
}

extern "C" double stateui_winui_stepper_value(StateUIObjectRef handle) {
    try {
        return borrow<controls::NumberBox>(handle).Value();
    } catch (...) {
        report("reading a stepper");
        return 0;
    }
}

extern "C" void stateui_winui_stepper_step_as_user(StateUIObjectRef handle, bool up) {
    try {
        // The spin button the box's template holds, pressed as UI Automation presses it.
        std::vector<xaml::DependencyObject> left{as<xaml::DependencyObject>(handle)};
        auto name = up ? L"UpSpinButton" : L"DownSpinButton";
        while (!left.empty()) {
            auto at = left.back();
            left.pop_back();
            if (auto button = at.try_as<xaml::FrameworkElement>(); button && button.Name() == name) {
                pattern<provider::IInvokeProvider>(button, PatternInterface::Invoke).Invoke();
                return;
            }
            for (int32_t index = 0, count = xaml::Media::VisualTreeHelper::GetChildrenCount(at); index < count; ++index)
                left.push_back(xaml::Media::VisualTreeHelper::GetChild(at, index));
        }
        throw winrt::hresult_error(E_FAIL, L"the box has no spin button");
    } catch (...) {
        report("stepping a stepper as the user");
    }
}

extern "C" void stateui_winui_stepper_enter_as_user(StateUIObjectRef handle, char const *utf8) {
    try {
        // The box reads its words as it does when Enter is pressed in it.
        borrow<controls::NumberBox>(handle).Text(text(utf8));
    } catch (...) {
        report("entering words in a stepper as the user");
    }
}

extern "C" void stateui_winui_value_move(StateUIObjectRef handle, double value) {
    try {
        pattern<provider::IRangeValueProvider>(as<xaml::UIElement>(handle), PatternInterface::RangeValue).SetValue(value);
    } catch (...) {
        report("moving a value as the user");
    }
}
