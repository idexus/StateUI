// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The six shapes, each one WinUI Path: a rectangle and an ellipse filling
// their room, and a geometry of their own - a line, a path, a polygon, a
// polyline - placed in it by their aspect and moved by their transform.
// Design: docs/design/platforms/winui/drawing.md#the-shapes

#include "Relay.h"

#include <algorithm>
#include <cmath>

#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace stateui;
using winrt::Windows::Foundation::Point;
namespace media = winrt::Microsoft::UI::Xaml::Media;
namespace shapes = winrt::Microsoft::UI::Xaml::Shapes;

namespace {
    Point at(double x, double y) {
        return {static_cast<float>(x), static_cast<float>(y)};
    }

    /// A rectangle from (x0, y0) to (x1, y1), its corners rounded clockwise from the top left.
    media::PathGeometry rounded(double x0, double y0, double x1, double y1, double const *radii) {
        auto limit = std::max(0.0, std::min(x1 - x0, y1 - y0) / 2);
        double r[4];
        for (int index = 0; index < 4; ++index) r[index] = std::clamp(std::isfinite(radii[index]) ? radii[index] : 0, 0.0, limit);

        media::PathFigure figure;
        figure.StartPoint(at(x0 + r[0], y0));
        figure.IsClosed(true);
        auto segments = figure.Segments();
        auto line = [&](double x, double y) {
            media::LineSegment segment;
            segment.Point(at(x, y));
            segments.Append(segment);
        };
        auto corner = [&](double radius, double x, double y) {
            if (radius <= 0) return line(x, y);
            media::ArcSegment segment;
            segment.Point(at(x, y));
            segment.Size({static_cast<float>(radius), static_cast<float>(radius)});
            segment.SweepDirection(media::SweepDirection::Clockwise);
            segments.Append(segment);
        };
        line(x1 - r[1], y0);
        corner(r[1], x1, y0 + r[1]);
        line(x1, y1 - r[2]);
        corner(r[2], x1 - r[2], y1);
        line(x0 + r[3], y1);
        corner(r[3], x0, y1 - r[3]);
        line(x0, y0 + r[0]);
        corner(r[0], x0 + r[0], y0);

        media::PathGeometry geometry;
        geometry.Figures().Append(figure);
        return geometry;
    }

    /// The geometry the flat commands draw: 0 move, 1 line, 2 cubic, 3 quadratic, 4 close.
    media::PathGeometry authored(double const *commands, int32_t count, bool evenOdd) {
        media::PathGeometry geometry;
        geometry.FillRule(evenOdd ? media::FillRule::EvenOdd : media::FillRule::Nonzero);
        media::PathFigure figure{nullptr};
        for (int32_t index = 0; index < count;) {
            auto op = static_cast<int32_t>(commands[index++]);
            auto need = op == 0 || op == 1 ? 2 : op == 2 ? 6 : op == 3 ? 4 : 0;
            if (index + need > count) break;
            auto const *p = commands + index;
            index += need;
            if (op == 0 || !figure) {
                figure = media::PathFigure();
                figure.StartPoint(op == 0 ? at(p[0], p[1]) : at(0, 0));
                figure.IsFilled(true);
                geometry.Figures().Append(figure);
                if (op == 0) continue;
            }
            switch (op) {
            case 1: {
                media::LineSegment segment;
                segment.Point(at(p[0], p[1]));
                figure.Segments().Append(segment);
                break;
            }
            case 2: {
                media::BezierSegment segment;
                segment.Point1(at(p[0], p[1]));
                segment.Point2(at(p[2], p[3]));
                segment.Point3(at(p[4], p[5]));
                figure.Segments().Append(segment);
                break;
            }
            case 3: {
                media::QuadraticBezierSegment segment;
                segment.Point1(at(p[0], p[1]));
                segment.Point2(at(p[2], p[3]));
                figure.Segments().Append(segment);
                break;
            }
            case 4:
                figure.IsClosed(true);
                break;
            }
        }
        return geometry;
    }
}

extern "C" StateUIObjectRef stateui_winui_path_make(void) {
    try {
        shapes::Path path;
        path.Stretch(media::Stretch::None);
        return detach(path);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a shape");
        return nullptr;
    }
}

extern "C" void stateui_winui_path_paint(
    StateUIObjectRef handle, StateUIBrush fill, StateUIBrush stroke, double width, double const *dashes,
    int32_t dashCount, double dashOffset, int32_t cap, int32_t join, double miter
) {
    try {
        auto path = borrow<shapes::Path>(handle);
        path.Fill(brush(fill));
        path.Stroke(brush(stroke));
        path.StrokeThickness(width);
        // Dashes and their offset are outline widths, in WinUI as in StateUI.
        media::DoubleCollection pattern;
        for (int32_t index = 0; index < dashCount; ++index) pattern.Append(dashes[index]);
        path.StrokeDashArray(pattern);
        path.StrokeDashOffset(dashOffset);
        auto ends = cap == 1 ? media::PenLineCap::Round : cap == 2 ? media::PenLineCap::Square : media::PenLineCap::Flat;
        path.StrokeStartLineCap(ends);
        path.StrokeEndLineCap(ends);
        path.StrokeDashCap(ends);
        path.StrokeLineJoin(join == 1 ? media::PenLineJoin::Bevel : join == 2 ? media::PenLineJoin::Round : media::PenLineJoin::Miter);
        // WinUI measures a mitred corner against half the outline's width; StateUI against the whole.
        path.StrokeMiterLimit(miter * 2);
    } catch (winrt::hresult_error const &error) {
        report(error, "painting a shape");
    }
}

extern "C" void stateui_winui_path_draw(
    StateUIObjectRef handle, int32_t kind, double const *radii, double const *commands, int32_t count, bool evenOdd,
    int32_t aspect, double const *transform, double width, double height, double inset
) {
    try {
        auto path = borrow<shapes::Path>(handle);
        if (kind == 0) {
            path.Data(rounded(inset, inset, width - inset, height - inset, radii));
            return;
        }
        if (kind == 1) {
            media::EllipseGeometry ellipse;
            ellipse.Center(at(width / 2, height / 2));
            ellipse.RadiusX(std::max(0.0, width / 2 - inset));
            ellipse.RadiusY(std::max(0.0, height / 2 - inset));
            path.Data(ellipse);
            return;
        }

        // Placed by the aspect - fit, fill, stretch, centre - centred, then moved by the transform.
        auto geometry = authored(commands, count, evenOdd);
        auto box = geometry.Bounds();
        double across = box.Width > 0 ? width / box.Width : 0, down = box.Height > 0 ? height / box.Height : 0;
        double sx = 1, sy = 1;
        if (box.Width > 0 || box.Height > 0) {
            switch (aspect) {
            case 2: sx = box.Width > 0 ? across : 1; sy = box.Height > 0 ? down : 1; break;
            case 3: break;
            case 1: sx = sy = std::max(across, down); break;
            default:
                sx = sy = box.Width > 0 && box.Height > 0 ? std::min(across, down) : std::max(across, down);
            }
        }
        double ox = width / 2 - (box.X + box.Width / 2) * sx, oy = height / 2 - (box.Y + box.Height / 2) * sy;
        winrt::Microsoft::UI::Xaml::Media::Matrix place{sx, 0, 0, sy, ox, oy};
        if (transform) {
            auto a = transform[0], b = transform[1], c = transform[2], d = transform[3];
            place = {sx * a, sx * b, sy * c, sy * d, ox * a + oy * c + transform[4], ox * b + oy * d + transform[5]};
        }
        // WinUI draws nothing of a geometry whose transform is the identity: a geometry left in place takes none.
        bool identity = place.M11 == 1 && place.M12 == 0 && place.M21 == 0 && place.M22 == 1 && place.OffsetX == 0
            && place.OffsetY == 0;
        if (!identity) {
            media::MatrixTransform moved;
            moved.Matrix(place);
            geometry.Transform(moved);
        }
        path.Data(geometry);
    } catch (winrt::hresult_error const &error) {
        report(error, "drawing a shape");
    }
}
