// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What every element takes: its measure and place, which a panel's pass asks
// for, whether it shows, how opaque it is drawn, and a control's enabled state.

#include "Relay.h"

#include <algorithm>
#include <cstring>

#include <winrt/Microsoft.UI.Composition.h>
#include <winrt/Microsoft.UI.Xaml.Documents.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Windows.UI.ViewManagement.h>

using namespace stateui;
using winrt::Windows::Foundation::Rect;
using winrt::Windows::Foundation::Size;

extern "C" void stateui_winui_fill_place(StateUIObjectRef handle) {
    try {
        auto element = as<xaml::FrameworkElement>(handle);
        element.HorizontalAlignment(xaml::HorizontalAlignment::Stretch);
        element.VerticalAlignment(xaml::VerticalAlignment::Stretch);
    } catch (winrt::hresult_error const &error) {
        report(error, "filling a place");
    }
}

extern "C" void stateui_winui_measure(StateUIObjectRef handle, double width, double height, double *size) {
    try {
        auto element = as<xaml::UIElement>(handle);
        element.Measure(Size(static_cast<float>(width), static_cast<float>(height)));
        auto desired = element.DesiredSize();
        size[0] = desired.Width;
        size[1] = desired.Height;
    } catch (winrt::hresult_error const &error) {
        report(error, "measuring");
    }
}

extern "C" void stateui_winui_arrange(StateUIObjectRef handle, double x, double y, double width, double height) {
    try {
        as<xaml::UIElement>(handle).Arrange(Rect(
            static_cast<float>(x), static_cast<float>(y), static_cast<float>(width), static_cast<float>(height)));
    } catch (winrt::hresult_error const &error) {
        report(error, "arranging");
    }
}

extern "C" void stateui_winui_invalidate_measure(StateUIObjectRef handle) {
    try {
        as<xaml::UIElement>(handle).InvalidateMeasure();
    } catch (winrt::hresult_error const &error) {
        report(error, "invalidating a measure");
    }
}

extern "C" void stateui_winui_set_shown(StateUIObjectRef handle, bool shown) {
    try {
        as<xaml::UIElement>(handle).Visibility(shown ? xaml::Visibility::Visible : xaml::Visibility::Collapsed);
    } catch (winrt::hresult_error const &error) {
        report(error, "showing");
    }
}

extern "C" void stateui_winui_set_opacity(StateUIObjectRef handle, double opacity) {
    try {
        as<xaml::UIElement>(handle).Opacity(opacity);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting the opacity");
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
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a frame");
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
    } catch (winrt::hresult_error const &error) {
        report(error, "finding where an element stands in its window");
    }
}

extern "C" void stateui_winui_invalidate_arrange(StateUIObjectRef handle) {
    try {
        as<xaml::UIElement>(handle).InvalidateArrange();
    } catch (winrt::hresult_error const &error) {
        report(error, "invalidating an arrangement");
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
    } catch (winrt::hresult_error const &error) {
        report(error, "cutting an element to its outline");
    }
}

extern "C" void stateui_winui_set_hit_testable(StateUIObjectRef handle, bool testable) {
    try {
        as<xaml::UIElement>(handle).IsHitTestVisible(testable);
    } catch (winrt::hresult_error const &error) {
        report(error, "letting clicks through");
    }
}

extern "C" void stateui_winui_set_z_index(StateUIObjectRef handle, int32_t z) {
    try {
        controls::Canvas::SetZIndex(as<xaml::UIElement>(handle), z);
    } catch (winrt::hresult_error const &error) {
        report(error, "ordering an element among its panel's children");
    }
}

extern "C" void stateui_winui_update_layout(StateUIObjectRef handle) {
    try {
        as<xaml::UIElement>(handle).UpdateLayout();
    } catch (winrt::hresult_error const &error) {
        report(error, "laying out");
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
    } catch (winrt::hresult_error const &error) {
        report(error, "transforming");
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
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a transform");
    }
}

extern "C" double stateui_winui_opacity(StateUIObjectRef handle) {
    try {
        return as<xaml::UIElement>(handle).Opacity();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading the opacity");
        return 1;
    }
}

extern "C" bool stateui_winui_animations_enabled(void) {
    try {
        // One, kept: a fresh UISettings for every reading is a WinRT activation each time.
        static winrt::Windows::UI::ViewManagement::UISettings settings;
        return settings.AnimationsEnabled();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading whether animations are on");
        return true;
    }
}

extern "C" void stateui_winui_set_enabled(StateUIObjectRef handle, bool enabled) {
    try {
        as<controls::Control>(handle).IsEnabled(enabled);
    } catch (winrt::hresult_error const &error) {
        report(error, "enabling");
    }
}

extern "C" int32_t stateui_winui_text(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        auto object = as<IInspectable>(handle);
        winrt::hstring words;
        if (auto block = object.try_as<controls::TextBlock>()) {
            // Runs of words are the block's words, in order.
            for (auto const &piece : block.Inlines())
                if (auto run = piece.try_as<winrt::Microsoft::UI::Xaml::Documents::Run>()) words = words + run.Text();
            if (!block.Inlines().Size()) words = block.Text();
        } else if (auto box = object.try_as<controls::TextBox>()) {
            words = box.Text();
        } else if (auto search = object.try_as<controls::AutoSuggestBox>()) {
            words = search.Text();
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
    } catch (winrt::hresult_error const &error) {
        report(error, "reading the words");
        return 0;
    }
}
