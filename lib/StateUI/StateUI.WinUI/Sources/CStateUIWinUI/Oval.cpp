// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An oval as a brush: what a control's own corners cannot draw - a button's
// oval face - painted as its background, filled and outlined.

#include "Relay.h"

#include <algorithm>

#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Composition.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;
namespace composition = winrt::Microsoft::UI::Composition;

namespace {
    /// `argb` keeping `share` of its opacity.
    winrt::Windows::UI::Color faded(uint32_t argb, double share) {
        auto alpha = std::clamp(static_cast<double>(argb >> 24) * share, 0.0, 255.0);
        return {static_cast<uint8_t>(alpha), static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8),
                static_cast<uint8_t>(argb)};
    }

    /// A brush's first color; none for no brush.
    uint32_t firstColor(StateUIBrush const &brush) {
        return brush.kind != StateUIBrushKindNone && brush.count > 0 ? brush.colors[0] : 0u;
    }

    /// An oval `width` by `height`, filled in one color and outlined in another `lineWidth` wide inside its edge,
    /// drawn by the compositor as the brush's surface.
    /// Design: docs/design/platforms/winui/controls.md#an-oval-button
    struct StateUIOval : media::XamlCompositionBrushBaseT<StateUIOval> {
        StateUIOval(winrt::Windows::UI::Color fill, winrt::Windows::UI::Color stroke, float lineWidth, float width,
                    float height)
            : fill(fill), stroke(stroke), lineWidth(lineWidth), width(width), height(height) {}

        void OnConnected() {
            try {
                if (CompositionBrush()) return;
                auto compositor = media::CompositionTarget::GetCompositorForCurrentThread();
                auto geometry = compositor.CreateEllipseGeometry();
                geometry.Center({width / 2, height / 2});
                geometry.Radius({std::max(0.0f, (width - lineWidth) / 2), std::max(0.0f, (height - lineWidth) / 2)});
                auto shape = compositor.CreateSpriteShape(geometry);
                shape.FillBrush(compositor.CreateColorBrush(fill));
                if (lineWidth > 0) {
                    shape.StrokeBrush(compositor.CreateColorBrush(stroke));
                    shape.StrokeThickness(lineWidth);
                }
                auto visual = compositor.CreateShapeVisual();
                visual.Size({width, height});
                visual.Shapes().Append(shape);
                auto surface = compositor.CreateVisualSurface();
                surface.SourceVisual(visual);
                surface.SourceSize({width, height});
                auto painted = compositor.CreateSurfaceBrush(surface);
                painted.Stretch(composition::CompositionStretch::Fill);
                CompositionBrush(painted);
            } catch (...) {
                report("painting an oval");
            }
        }

        void OnDisconnected() {
            try {
                if (auto painted = CompositionBrush()) {
                    painted.Close();
                    CompositionBrush(nullptr);
                }
            } catch (...) {
                report("letting an oval's paint go");
            }
        }

        winrt::Windows::UI::Color const fill;
        winrt::Windows::UI::Color const stroke;
        float const lineWidth;
        float const width;
        float const height;
    };
}

namespace stateui {
    media::Brush oval(StateUIBrush const &fill, StateUIBrush const &stroke, double lineWidth, double share,
                      double width, double height) {
        return winrt::make<StateUIOval>(
            faded(firstColor(fill), share), faded(firstColor(stroke), 1), static_cast<float>(lineWidth),
            static_cast<float>(width), static_cast<float>(height));
    }
}
