// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The shape a layout's box is, and the brushes it is painted with, built from
// the parts the host hands over.
// Design: docs/design/platforms/winui/drawing.md#a-box-and-its-brush

#include "Figure.h"

#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;
namespace shapes = winrt::Microsoft::UI::Xaml::Shapes;

namespace {
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
        case StateUIBrushKindNone:
            return nullptr;
        case StateUIBrushKindSolid:
            return media::SolidColorBrush(color(brush.count > 0 ? brush.colors[0] : 0));
        case StateUIBrushKindLinear: {
            media::LinearGradientBrush linear;
            linear.StartPoint(point(g[0], g[1]));
            linear.EndPoint(point(g[2], g[3]));
            addStops(linear.GradientStops(), brush);
            return linear;
        }
        case StateUIBrushKindRadial: {
            media::RadialGradientBrush radial;
            radial.Center(point(g[0], g[1]));
            radial.GradientOrigin(point(g[0], g[1]));
            radial.RadiusX(g[2]);
            radial.RadiusY(g[3]);
            addStops(radial.GradientStops(), brush);
            return radial;
        }
        }
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_shape_make(StateUIOutline outline) {
    try {
        if (outline == StateUIOutlineEllipse) return detach(shapes::Ellipse());
        return detach(shapes::Rectangle());
    } catch (...) {
        report("making a shape");
        return nullptr;
    }
}

extern "C" void stateui_winui_shape_set(
    StateUIObjectRef handle, double radius, StateUIBrush fill, StateUIBrush stroke, double lineWidth
) {
    try {
        auto shape = as<shapes::Shape>(handle);
        shape.Fill(brush(fill));
        shape.Stroke(brush(stroke));
        shape.StrokeThickness(lineWidth);
        if (auto rectangle = shape.try_as<shapes::Rectangle>()) {
            rectangle.RadiusX(radius);
            rectangle.RadiusY(radius);
        }
    } catch (...) {
        report("painting a shape");
    }
}
