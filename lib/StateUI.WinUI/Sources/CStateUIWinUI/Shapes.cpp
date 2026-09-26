// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The shape a layout's box is, and the brushes it is painted with, built from
// the parts the host hands over; and a ColorBox, a figure of one colour.
// Design: docs/design/platforms/winui/drawing.md#a-box-and-its-brush

#include "Figure.h"

#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;
namespace shapes = winrt::Microsoft::UI::Xaml::Shapes;

namespace {
    winrt::Windows::UI::Color color(uint32_t argb) {
        return {static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8),
                static_cast<uint8_t>(argb)};
    }

    winrt::Windows::Foundation::Point point(double x, double y) {
        return {static_cast<float>(x), static_cast<float>(y)};
    }

    template <typename Stops>
    void addStops(Stops const &stops, StateUIBrush const &brush) {
        for (int32_t index = 0; index < brush.count; ++index) {
            media::GradientStop stop;
            stop.Color(color(brush.colors[index]));
            stop.Offset(brush.offsets[index]);
            stops.Append(stop);
        }
    }
}

namespace stateui {
    media::Brush brush(StateUIBrush const &brush) {
        auto const *g = brush.geometry;
        switch (brush.kind) {
        case 1:
            return media::SolidColorBrush(color(brush.count > 0 ? brush.colors[0] : 0));
        case 2: {
            media::LinearGradientBrush linear;
            linear.StartPoint(point(g[0], g[1]));
            linear.EndPoint(point(g[2], g[3]));
            addStops(linear.GradientStops(), brush);
            return linear;
        }
        case 3: {
            media::RadialGradientBrush radial;
            radial.Center(point(g[0], g[1]));
            radial.GradientOrigin(point(g[0], g[1]));
            radial.RadiusX(g[2]);
            radial.RadiusY(g[2]);
            addStops(radial.GradientStops(), brush);
            return radial;
        }
        default:
            return nullptr;
        }
    }
}

extern "C" StateUIObjectRef stateui_winui_shape_make(StateUIOutline outline) {
    try {
        if (outline == StateUIOutlineEllipse) return detach(shapes::Ellipse());
        return detach(shapes::Rectangle());
    } catch (winrt::hresult_error const &error) {
        report(error, "making a shape");
        return nullptr;
    }
}

extern "C" void stateui_winui_shape_set(
    StateUIObjectRef handle, double radius, StateUIBrush fill, StateUIBrush stroke, double strokeWidth
) {
    try {
        auto shape = as<shapes::Shape>(handle);
        shape.Fill(brush(fill));
        shape.Stroke(brush(stroke));
        shape.StrokeThickness(strokeWidth);
        if (auto rectangle = shape.try_as<shapes::Rectangle>()) {
            rectangle.RadiusX(radius);
            rectangle.RadiusY(radius);
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "painting a shape");
    }
}

extern "C" StateUIObjectRef stateui_winui_color_box_make(int64_t view) {
    try {
        return detach(figure(view));
    } catch (winrt::hresult_error const &error) {
        report(error, "making a colour box");
        return nullptr;
    }
}

extern "C" void stateui_winui_color_box_set(StateUIObjectRef handle, uint32_t fill, double const *corners) {
    try {
        auto box = borrow<controls::Grid>(handle);
        box.Background(media::SolidColorBrush(color(fill)));
        box.CornerRadius({corners[0], corners[1], corners[2], corners[3]});
    } catch (winrt::hresult_error const &error) {
        report(error, "painting a colour box");
    }
}
