// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What every element takes: its measure and place, which a panel's pass asks
// for, whether it shows, how opaque it is drawn, and a control's enabled state.

#include "Relay.h"

#include <algorithm>
#include <cstring>
#include <optional>

#include <winrt/Microsoft.UI.Composition.h>
#include <winrt/Microsoft.UI.Xaml.Documents.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Media.Media3D.h>
#include <winrt/Windows.UI.ViewManagement.h>

using namespace stateui;
using winrt::Windows::Foundation::Rect;
using winrt::Windows::Foundation::Size;

extern "C" void stateui_winui_fill_place(StateUIObjectRef handle) {
    try {
        auto element = as<xaml::FrameworkElement>(handle);
        element.HorizontalAlignment(xaml::HorizontalAlignment::Stretch);
        element.VerticalAlignment(xaml::VerticalAlignment::Stretch);
    } catch (...) {
        report("filling a place");
    }
}

extern "C" void stateui_winui_replace(StateUIObjectRef handle, StateUIObjectRef replacement) {
    try {
        auto element = as<xaml::FrameworkElement>(handle);
        auto standing = as<xaml::UIElement>(replacement);
        auto parent = element.Parent();
        if (auto panel = parent.try_as<controls::Panel>()) {
            uint32_t index = 0;
            if (panel.Children().IndexOf(element, index)) panel.Children().SetAt(index, standing);
        } else if (auto border = parent.try_as<controls::Border>()) {
            border.Child(standing);
        } else if (auto content = parent.try_as<controls::ContentControl>()) {
            content.Content(standing);
        }
    } catch (...) {
        report("standing an element in another's place");
    }
}

extern "C" void stateui_winui_measure(StateUIObjectRef handle, double width, double height, double *size) {
    try {
        auto element = as<xaml::UIElement>(handle);
        element.Measure(Size(static_cast<float>(width), static_cast<float>(height)));
        auto desired = element.DesiredSize();
        size[0] = desired.Width;
        size[1] = desired.Height;
    } catch (...) {
        report("measuring");
    }
}

extern "C" void stateui_winui_arrange(StateUIObjectRef handle, double x, double y, double width, double height) {
    try {
        as<xaml::UIElement>(handle).Arrange(Rect(
            static_cast<float>(x), static_cast<float>(y), static_cast<float>(width), static_cast<float>(height)));
    } catch (...) {
        report("arranging");
    }
}

extern "C" void stateui_winui_invalidate_measure(StateUIObjectRef handle) {
    try {
        as<xaml::UIElement>(handle).InvalidateMeasure();
    } catch (...) {
        report("invalidating a measure");
    }
}

extern "C" void stateui_winui_set_shown(StateUIObjectRef handle, bool shown) {
    try {
        as<xaml::UIElement>(handle).Visibility(shown ? xaml::Visibility::Visible : xaml::Visibility::Collapsed);
    } catch (...) {
        report("showing");
    }
}

extern "C" void stateui_winui_set_opacity(StateUIObjectRef handle, double opacity) {
    try {
        as<xaml::UIElement>(handle).Opacity(opacity);
    } catch (...) {
        report("setting the opacity");
    }
}

extern "C" void stateui_winui_frame(StateUIObjectRef handle, double *frame) {
    try {
        auto element = as<xaml::UIElement>(handle);
        auto offset = element.ActualOffset();
        auto size = element.ActualSize();
        frame[0] = offset.x;
        frame[1] = offset.y;
        frame[2] = size.x;
        frame[3] = size.y;
    } catch (...) {
        report("reading a frame");
    }
}

extern "C" void stateui_winui_origin(StateUIObjectRef handle, double *origin) {
    origin[0] = origin[1] = 0;
    try {
        auto element = as<xaml::UIElement>(handle);
        if (!element.XamlRoot()) return;
        auto corner = element.TransformToVisual(nullptr).TransformPoint({0, 0});
        origin[0] = corner.X;
        origin[1] = corner.Y;
    } catch (...) {
        report("finding where an element stands in its window");
    }
}

extern "C" void stateui_winui_invalidate_arrange(StateUIObjectRef handle) {
    try {
        as<xaml::UIElement>(handle).InvalidateArrange();
    } catch (...) {
        report("invalidating an arrangement");
    }
}

extern "C" void stateui_winui_set_clip(
    StateUIObjectRef handle, bool cuts, StateUIOutline outline, double radius, double width, double height
) {
    try {
        auto visual = xaml::Hosting::ElementCompositionPreview::GetElementVisual(as<xaml::UIElement>(handle));
        if (!cuts) {
            visual.Clip(nullptr);
            return;
        }
        auto compositor = visual.Compositor();
        auto w = static_cast<float>(width), h = static_cast<float>(height);
        if (outline == StateUIOutlineEllipse) {
            auto ellipse = compositor.CreateEllipseGeometry();
            ellipse.Center({w / 2, h / 2});
            ellipse.Radius({w / 2, h / 2});
            visual.Clip(compositor.CreateGeometricClip(ellipse));
        } else {
            auto rectangle = compositor.CreateRoundedRectangleGeometry();
            auto r = outline == StateUIOutlineRounded ? std::min(static_cast<float>(radius), std::min(w, h) / 2) : 0.0f;
            rectangle.Size({w, h});
            rectangle.CornerRadius({r, r});
            visual.Clip(compositor.CreateGeometricClip(rectangle));
        }
    } catch (...) {
        report("cutting an element to its outline");
    }
}

extern "C" void stateui_winui_set_hit_testable(StateUIObjectRef handle, bool testable) {
    try {
        as<xaml::UIElement>(handle).IsHitTestVisible(testable);
    } catch (...) {
        report("letting clicks through");
    }
}

extern "C" void stateui_winui_set_z_index(StateUIObjectRef handle, int32_t z) {
    try {
        controls::Canvas::SetZIndex(as<xaml::UIElement>(handle), z);
    } catch (...) {
        report("ordering an element among its panel's children");
    }
}

extern "C" void stateui_winui_set_flow_direction(StateUIObjectRef handle, bool rightToLeft) {
    try {
        as<xaml::FrameworkElement>(handle).FlowDirection(
            rightToLeft ? xaml::FlowDirection::RightToLeft : xaml::FlowDirection::LeftToRight);
    } catch (...) {
        report("turning an element's direction");
    }
}

extern "C" void stateui_winui_update_layout(StateUIObjectRef handle) {
    try {
        as<xaml::UIElement>(handle).UpdateLayout();
    } catch (...) {
        report("laying out");
    }
}

extern "C" void stateui_winui_set_transform(
    StateUIObjectRef handle, double translationX, double translationY, double rotation, double scaleX,
    double scaleY, double centerX, double centerY
) {
    try {
        // A composite render transform, which an element whose visual a cut has taken still takes: WinUI refuses
        // such an element its Translation, Rotation, Scale and CenterPoint.
        auto element = as<xaml::UIElement>(handle);
        auto transform = element.RenderTransform().try_as<xaml::Media::CompositeTransform>();
        if (!transform) {
            transform = xaml::Media::CompositeTransform();
            element.RenderTransform(transform);
        }
        transform.CenterX(centerX);
        transform.CenterY(centerY);
        transform.TranslateX(translationX);
        transform.TranslateY(translationY);
        transform.Rotation(rotation);
        transform.ScaleX(scaleX);
        transform.ScaleY(scaleY);
    } catch (...) {
        report("transforming");
    }
}

extern "C" void stateui_winui_set_projection(StateUIObjectRef handle, double const *matrix) {
    try {
        auto element = as<xaml::UIElement>(handle);
        if (!matrix) {
            element.Projection(nullptr);
            return;
        }
        xaml::Media::Media3D::Matrix3D held{
            matrix[0], matrix[1], matrix[2], matrix[3], matrix[4], matrix[5], matrix[6], matrix[7],
            matrix[8], matrix[9], matrix[10], matrix[11], matrix[12], matrix[13], matrix[14], matrix[15]};
        auto projection = element.Projection().try_as<xaml::Media::Matrix3DProjection>();
        if (!projection) {
            projection = xaml::Media::Matrix3DProjection();
            element.Projection(projection);
        }
        projection.ProjectionMatrix(held);
    } catch (...) {
        report("tipping an element");
    }
}

extern "C" bool stateui_winui_projection(StateUIObjectRef handle, double *matrix) {
    try {
        auto projection = as<xaml::UIElement>(handle).Projection().try_as<xaml::Media::Matrix3DProjection>();
        if (!projection) return false;
        auto held = projection.ProjectionMatrix();
        double const read[] = {held.M11, held.M12, held.M13, held.M14, held.M21, held.M22, held.M23, held.M24,
                               held.M31, held.M32, held.M33, held.M34, held.OffsetX, held.OffsetY, held.OffsetZ,
                               held.M44};
        std::memcpy(matrix, read, sizeof read);
        return true;
    } catch (...) {
        report("reading an element's tip");
        return false;
    }
}

extern "C" void stateui_winui_transform(StateUIObjectRef handle, double *values) {
    try {
        double read[] = {0, 0, 0, 1, 1, 0, 0};
        if (auto t = as<xaml::UIElement>(handle).RenderTransform().try_as<xaml::Media::CompositeTransform>()) {
            double const held[] = {t.TranslateX(), t.TranslateY(), t.Rotation(), t.ScaleX(), t.ScaleY(), t.CenterX(),
                                   t.CenterY()};
            std::memcpy(read, held, sizeof read);
        }
        std::memcpy(values, read, sizeof read);
    } catch (...) {
        report("reading a transform");
    }
}

extern "C" double stateui_winui_opacity(StateUIObjectRef handle) {
    try {
        return as<xaml::UIElement>(handle).Opacity();
    } catch (...) {
        report("reading the opacity");
        return 1;
    }
}

extern "C" bool stateui_winui_is_shown(StateUIObjectRef handle) {
    try {
        auto element = as<xaml::UIElement>(handle);
        auto root = element.XamlRoot();
        if (!root) return false;
        auto content = root.Content();
        for (xaml::DependencyObject at = element; at; at = xaml::Media::VisualTreeHelper::GetParent(at)) {
            if (auto each = at.try_as<xaml::UIElement>(); each && each.Visibility() != xaml::Visibility::Visible)
                return false;
            if (at == content) return true;
        }
        return false;
    } catch (...) {
        report("reading whether an element shows");
        return false;
    }
}

extern "C" bool stateui_winui_is_enabled(StateUIObjectRef handle) {
    try {
        auto control = as<IInspectable>(handle).try_as<controls::Control>();
        return !control || control.IsEnabled();
    } catch (...) {
        report("reading whether a control is enabled");
        return false;
    }
}

extern "C" bool stateui_winui_animations_enabled(void) {
    try {
        // One, kept for the process and never destroyed: a fresh UISettings for every reading is a WinRT activation
        // each time.
        static auto &settings = **new std::optional(winrt::Windows::UI::ViewManagement::UISettings());
        return settings.AnimationsEnabled();
    } catch (...) {
        report("reading whether animations are on");
        return true;
    }
}

extern "C" void stateui_winui_set_enabled(StateUIObjectRef handle, bool enabled) {
    try {
        // A view that is no control keeps no enabled state: the host layer holds the user's hand from it.
        if (auto control = as<IInspectable>(handle).try_as<controls::Control>()) control.IsEnabled(enabled);
    } catch (...) {
        report("enabling");
    }
}

namespace {
    /// The theme resources a control's template paints the ground under its whole frame from - its container, or the
    /// field or face it is - each followed by its states' names; none for a control whose own Background is that
    /// ground.
    std::vector<std::wstring> groundResources(IInspectable const &control) {
        std::vector<std::wstring> named;
        if (control.try_as<controls::RadioButton>()) named = {L"RadioButtonBackground"};
        else if (control.try_as<controls::CheckBox>())
            named = {L"CheckBoxBackgroundUnchecked", L"CheckBoxBackgroundChecked", L"CheckBoxBackgroundIndeterminate"};
        else if (control.try_as<controls::ToggleSwitch>()) named = {L"ToggleSwitchContainerBackground"};
        else if (control.try_as<controls::Slider>()) named = {L"SliderContainerBackground"};
        else if (control.try_as<controls::ComboBox>()) named = {L"ComboBoxBackground"};
        else if (control.try_as<controls::CalendarDatePicker>()) named = {L"CalendarDatePickerBackground"};
        else if (control.try_as<controls::TimePicker>()) named = {L"TimePickerButtonBackground"};
        else if (control.try_as<controls::TextBox>() || control.try_as<controls::PasswordBox>() ||
                 control.try_as<controls::AutoSuggestBox>() || control.try_as<controls::NumberBox>())
            named = {L"TextControlBackground"};
        std::vector<std::wstring> states;
        for (auto const &name : named)
            for (auto suffix : {L"", L"PointerOver", L"Pressed", L"Focused", L"Disabled"}) states.push_back(name + suffix);
        return states;
    }
}

extern "C" void stateui_winui_set_background(StateUIObjectRef handle, StateUIBrush background) {
    try {
        auto element = as<IInspectable>(handle);
        auto fill = brush(background);
        if (auto control = element.try_as<controls::Control>()) {
            std::vector<std::pair<std::wstring, xaml::Media::Brush>> brushes;
            for (auto const &name : groundResources(control)) brushes.emplace_back(name, fill);
            writeResources(control, brushes);
            if (fill) control.Background(fill);
            else control.ClearValue(controls::Control::BackgroundProperty());
        } else if (auto panel = element.try_as<controls::Panel>()) {
            if (fill) panel.Background(fill);
            else panel.ClearValue(controls::Panel::BackgroundProperty());
        }
    } catch (...) {
        report("painting a view's background");
    }
}

extern "C" int32_t stateui_winui_text(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        auto object = as<IInspectable>(handle);
        winrt::hstring words;
        if (auto block = wordsOf(object)) {
            // Runs of words are the block's words, in order.
            for (auto const &piece : block.Inlines())
                if (auto run = piece.try_as<winrt::Microsoft::UI::Xaml::Documents::Run>()) words = words + run.Text();
            if (!block.Inlines().Size()) words = block.Text();
        } else if (auto box = object.try_as<controls::TextBox>()) {
            words = box.Text();
        } else if (auto password = object.try_as<controls::PasswordBox>()) {
            words = password.Password();
        } else if (auto search = object.try_as<controls::AutoSuggestBox>()) {
            words = search.Text();
        } else if (auto caption = captionOf(object)) {
            words = caption.Text();
        } else if (auto content = object.try_as<controls::ContentControl>()) {
            words = winrt::unbox_value_or<winrt::hstring>(content.Content(), L"");
        }
        auto bytes = winrt::to_string(words);
        if (utf8 && capacity > 0) {
            auto count = std::min<size_t>(bytes.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, bytes.data(), count);
            utf8[count] = 0;
        }
        return static_cast<int32_t>(bytes.size());
    } catch (...) {
        report("reading the words");
        return 0;
    }
}
