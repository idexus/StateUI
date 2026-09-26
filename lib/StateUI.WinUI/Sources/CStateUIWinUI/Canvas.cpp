// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A canvas: StateUI's drawing replayed with Direct2D, which WinUI itself draws
// with, into the SurfaceImageSource the canvas is painted with - again for each
// size and scale it is shown at, and for a surface that lost what it held. A
// press on it is followed from down to up, the pointer held.
// Design: docs/design/platforms/winui/drawing.md#a-canvas

#include "Figure.h"

#include <algorithm>
#include <cmath>
#include <numbers>
#include <string>
#include <vector>

#include <d2d1_1.h>
#include <d3d11.h>
#include <dwrite.h>
#include <microsoft.ui.xaml.media.dxinterop.h>

#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.Imaging.h>

using namespace stateui;
using winrt::Windows::Foundation::Point;
using winrt::Windows::Foundation::Size;
namespace input = winrt::Microsoft::UI::Xaml::Input;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    /// The instructions' kinds, as StateUI numbers them.
    enum Kind : int32_t {
        FillColor, StrokeColor, TextColor, StrokeWidth, FontSize, Alpha, DrawLine, DrawRectangle, DrawRoundedRectangle,
        DrawEllipse, DrawArc, DrawPath, FillRectangle, FillRoundedRectangle, FillEllipse, FillArc, FillPath, DrawText,
        Translate, Rotate, Scale, SaveState, RestoreState,
    };

    /// What every canvas draws with: Direct2D's device, made at the first drawing and again after Windows takes it
    /// away, and how many there have been; what writes text, in the system's family and the user's language.
    struct Devices {
        winrt::com_ptr<ID2D1Factory1> factory;
        winrt::com_ptr<IDWriteFactory> words;
        winrt::com_ptr<ID2D1Device> device;
        uint32_t made = 0;
        std::wstring family;
        wchar_t language[LOCALE_NAME_MAX_LENGTH] = L"";
    } devices;

    void prepare() {
        if (!devices.factory) {
            D2D1_FACTORY_OPTIONS options{};
            winrt::check_hresult(D2D1CreateFactory(
                D2D1_FACTORY_TYPE_SINGLE_THREADED, __uuidof(ID2D1Factory1), &options, devices.factory.put_void()));
            winrt::check_hresult(DWriteCreateFactory(
                DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown **>(devices.words.put())));
            // Segoe UI Variable where Windows has it, Segoe UI before.
            winrt::com_ptr<IDWriteFontCollection> fonts;
            UINT32 index = 0;
            BOOL found = FALSE;
            if (SUCCEEDED(devices.words->GetSystemFontCollection(fonts.put())))
                fonts->FindFamilyName(L"Segoe UI Variable Text", &index, &found);
            devices.family = found ? L"Segoe UI Variable Text" : L"Segoe UI";
            GetUserDefaultLocaleName(devices.language, LOCALE_NAME_MAX_LENGTH);
        }
        if (devices.device) return;

        winrt::com_ptr<ID3D11Device> direct3D;
        auto make = [&](D3D_DRIVER_TYPE driver) {
            direct3D = nullptr;
            return D3D11CreateDevice(nullptr, driver, nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT, nullptr, 0,
                                     D3D11_SDK_VERSION, direct3D.put(), nullptr, nullptr);
        };
        // Where the graphics card gives no device, Windows' own rasterizer draws.
        if (FAILED(make(D3D_DRIVER_TYPE_HARDWARE))) winrt::check_hresult(make(D3D_DRIVER_TYPE_WARP));
        winrt::check_hresult(devices.factory->CreateDevice(direct3D.as<IDXGIDevice>().get(), devices.device.put()));
        devices.made += 1;
    }

    /// Whether drawing failed for a device Windows took away: a driver updated or reset, the card removed.
    bool lost(HRESULT result) {
        return result == DXGI_ERROR_DEVICE_REMOVED || result == DXGI_ERROR_DEVICE_RESET || result == D2DERR_RECREATE_TARGET;
    }

    /// A drawing as the host lays it out: kinds and whole numbers, numbers, and text.
    struct Drawing {
        std::vector<int32_t> ints;
        std::vector<double> numbers;
        std::vector<std::wstring> words;
    };

    /// Reads a drawing's lists in order, and stops for good at a record either list cannot finish.
    struct Reader {
        Drawing const &drawing;
        size_t at = 0, number = 0;
        bool whole = true;

        bool more() const { return whole && at < drawing.ints.size(); }

        int32_t integer() {
            if (at < drawing.ints.size()) return drawing.ints[at++];
            whole = false;
            return 0;
        }

        /// The next `count` numbers; null once the list runs out.
        double const *numbers(size_t count) {
            if (!whole || number + count > drawing.numbers.size()) {
                whole = false;
                return nullptr;
            }
            number += count;
            return drawing.numbers.data() + number - count;
        }
    };

    /// What an instruction may change, kept by saveState and put back by restoreState.
    struct Pen {
        D2D1_COLOR_F fill = D2D1::ColorF(D2D1::ColorF::Black);
        D2D1_COLOR_F stroke = D2D1::ColorF(D2D1::ColorF::Black);
        D2D1_COLOR_F text = D2D1::ColorF(D2D1::ColorF::Black);
        float width = 1, size = 14, alpha = 1;
        D2D1::Matrix3x2F transform = D2D1::Matrix3x2F::Identity();
    };

    D2D1_COLOR_F colour(int32_t argb) {
        auto value = static_cast<uint32_t>(argb);
        return D2D1::ColorF(((value >> 16) & 0xFF) / 255.0f, ((value >> 8) & 0xFF) / 255.0f, (value & 0xFF) / 255.0f,
                            (value >> 24) / 255.0f);
    }

    D2D1_POINT_2F point(double x, double y) {
        return D2D1::Point2F(static_cast<float>(x), static_cast<float>(y));
    }

    /// The box four numbers give: its left, top, width and height.
    D2D1_RECT_F box(double const *at) {
        return D2D1::RectF(static_cast<float>(at[0]), static_cast<float>(at[1]), static_cast<float>(at[0] + at[2]),
                           static_cast<float>(at[1] + at[3]));
    }

    /// Part of the ellipse the box `at` holds, from `at[4]` to `at[5]` degrees - 0 to the right, the way `clockwise`
    /// says down the screen - its ends joined where `closed`, and through its middle where it is a wedge.
    winrt::com_ptr<ID2D1PathGeometry> arc(double const *at, bool clockwise, bool closed, bool wedge) {
        double start = at[4], end = at[5];
        if (clockwise && end < start) end += 360 * std::ceil((start - end) / 360);
        if (!clockwise && end > start) end -= 360 * std::ceil((end - start) / 360);
        double sweep = std::clamp(end - start, -360.0, 360.0);
        double rx = at[2] / 2, ry = at[3] / 2, cx = at[0] + rx, cy = at[1] + ry;
        auto on = [&](double degrees) {
            double radians = degrees * std::numbers::pi / 180;
            return point(cx + rx * std::cos(radians), cy + ry * std::sin(radians));
        };

        winrt::com_ptr<ID2D1PathGeometry> geometry;
        winrt::com_ptr<ID2D1GeometrySink> sink;
        winrt::check_hresult(devices.factory->CreatePathGeometry(geometry.put()));
        winrt::check_hresult(geometry->Open(sink.put()));
        sink->BeginFigure(wedge ? point(cx, cy) : on(start), D2D1_FIGURE_BEGIN_FILLED);
        if (wedge) sink->AddLine(on(start));
        // A quarter turn at most to an arc: no two ends meet, and none is ambiguous.
        auto pieces = std::max(1, static_cast<int>(std::ceil(std::abs(sweep) / 90)));
        auto radii = D2D1::SizeF(static_cast<float>(std::abs(rx)), static_cast<float>(std::abs(ry)));
        auto turning = sweep < 0 ? D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE : D2D1_SWEEP_DIRECTION_CLOCKWISE;
        for (int piece = 1; piece <= pieces; ++piece)
            sink->AddArc(D2D1::ArcSegment(on(start + sweep * piece / pieces), radii, 0, turning, D2D1_ARC_SIZE_SMALL));
        sink->EndFigure(closed || wedge ? D2D1_FIGURE_END_CLOSED : D2D1_FIGURE_END_OPEN);
        winrt::check_hresult(sink->Close());
        return geometry;
    }

    /// The next `count` curves - each its kind, 0 move, 1 line, 2 cubic, 3 quadratic, 4 close, then its points -
    /// filled by the nonzero rule; null where the numbers run out first.
    winrt::com_ptr<ID2D1PathGeometry> curves(Reader &reader, int32_t count) {
        winrt::com_ptr<ID2D1PathGeometry> geometry;
        winrt::com_ptr<ID2D1GeometrySink> sink;
        winrt::check_hresult(devices.factory->CreatePathGeometry(geometry.put()));
        winrt::check_hresult(geometry->Open(sink.put()));
        sink->SetFillMode(D2D1_FILL_MODE_WINDING);
        bool open = false;
        auto start = point(0, 0);
        // A curve drawn with no figure open begins one where the last began: at the origin before any.
        auto begin = [&] {
            if (open) return;
            sink->BeginFigure(start, D2D1_FIGURE_BEGIN_FILLED);
            open = true;
        };
        for (int32_t index = 0; index < count; ++index) {
            auto const *kind = reader.numbers(1);
            if (!kind) break;
            double const *p = nullptr;
            switch (static_cast<int>(*kind)) {
            case 0:
                if (!(p = reader.numbers(2))) break;
                if (open) sink->EndFigure(D2D1_FIGURE_END_OPEN);
                open = false;
                start = point(p[0], p[1]);
                begin();
                break;
            case 1:
                if (!(p = reader.numbers(2))) break;
                begin();
                sink->AddLine(point(p[0], p[1]));
                break;
            case 2:
                if (!(p = reader.numbers(6))) break;
                begin();
                sink->AddBezier(D2D1::BezierSegment(point(p[0], p[1]), point(p[2], p[3]), point(p[4], p[5])));
                break;
            case 3:
                if (!(p = reader.numbers(4))) break;
                begin();
                sink->AddQuadraticBezier(D2D1::QuadraticBezierSegment(point(p[0], p[1]), point(p[2], p[3])));
                break;
            default:
                if (open) sink->EndFigure(D2D1_FIGURE_END_CLOSED);
                open = false;
            }
        }
        if (open) sink->EndFigure(D2D1_FIGURE_END_OPEN);
        winrt::check_hresult(sink->Close());
        return reader.whole ? geometry : nullptr;
    }

    /// `text` wrapped in the box `at`, set across it and down it as `across` and `down` say, cut at its edges.
    void write(ID2D1DeviceContext *context, ID2D1Brush *brush, float size, double const *at, int32_t across,
               int32_t down, std::wstring const &text) {
        winrt::com_ptr<IDWriteTextFormat> format;
        if (size <= 0
            || FAILED(devices.words->CreateTextFormat(devices.family.c_str(), nullptr, DWRITE_FONT_WEIGHT_NORMAL,
                                                      DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, size,
                                                      devices.language, format.put())))
            return;
        format->SetTextAlignment(across == 1   ? DWRITE_TEXT_ALIGNMENT_CENTER
                                 : across == 2 ? DWRITE_TEXT_ALIGNMENT_TRAILING
                                               : DWRITE_TEXT_ALIGNMENT_LEADING);
        format->SetParagraphAlignment(down == 1   ? DWRITE_PARAGRAPH_ALIGNMENT_CENTER
                                      : down == 2 ? DWRITE_PARAGRAPH_ALIGNMENT_FAR
                                                  : DWRITE_PARAGRAPH_ALIGNMENT_NEAR);
        winrt::com_ptr<IDWriteTextLayout> layout;
        winrt::com_ptr<ID2D1RectangleGeometry> edges;
        if (FAILED(devices.words->CreateTextLayout(text.c_str(), static_cast<UINT32>(text.size()), format.get(),
                                                   static_cast<float>(std::max(0.0, at[2])),
                                                   static_cast<float>(std::max(0.0, at[3])), layout.put()))
            || FAILED(devices.factory->CreateRectangleGeometry(box(at), edges.put())))
            return;
        // A layer cut by the box, where a clip would take the box's bounds once the canvas is turned.
        context->PushLayer(D2D1::LayerParameters1(D2D1::InfiniteRect(), edges.get()), nullptr);
        context->DrawTextLayout(point(at[0], at[1]), layout.get(), brush);
        context->PopLayer();
    }

    /// Replays `drawing` on `context`, over `base`, which places the canvas on its surface.
    void replay(ID2D1DeviceContext *context, D2D1::Matrix3x2F const &base, Drawing const &drawing) {
        winrt::com_ptr<ID2D1SolidColorBrush> brush;
        winrt::check_hresult(context->CreateSolidColorBrush(D2D1::ColorF(D2D1::ColorF::Black), brush.put()));
        Pen pen;
        std::vector<Pen> kept;
        auto paint = [&](D2D1_COLOR_F const &colour) {
            brush->SetColor(colour);
            brush->SetOpacity(pen.alpha);
            return brush.get();
        };
        auto place = [&] { context->SetTransform(pen.transform * base); };
        auto shape = [&](ID2D1Geometry *geometry, bool filled) {
            if (!geometry) return;
            if (filled) context->FillGeometry(geometry, paint(pen.fill));
            else if (pen.width > 0) context->DrawGeometry(geometry, paint(pen.stroke), pen.width);
        };

        Reader reader{drawing};
        while (reader.more()) {
            auto kind = reader.integer();
            double const *at = nullptr;
            switch (kind) {
            case FillColor: pen.fill = colour(reader.integer()); break;
            case StrokeColor: pen.stroke = colour(reader.integer()); break;
            case TextColor: pen.text = colour(reader.integer()); break;
            case StrokeWidth:
                if ((at = reader.numbers(1))) pen.width = static_cast<float>(std::max(0.0, *at));
                break;
            case FontSize:
                if ((at = reader.numbers(1))) pen.size = static_cast<float>(std::max(0.0, *at));
                break;
            case Alpha:
                if ((at = reader.numbers(1))) pen.alpha = static_cast<float>(std::clamp(*at, 0.0, 1.0));
                break;
            case DrawLine:
                if ((at = reader.numbers(4)) && pen.width > 0)
                    context->DrawLine(point(at[0], at[1]), point(at[2], at[3]), paint(pen.stroke), pen.width);
                break;
            case DrawRectangle:
                if ((at = reader.numbers(4)) && pen.width > 0) context->DrawRectangle(box(at), paint(pen.stroke), pen.width);
                break;
            case FillRectangle:
                if ((at = reader.numbers(4))) context->FillRectangle(box(at), paint(pen.fill));
                break;
            case DrawRoundedRectangle:
            case FillRoundedRectangle: {
                if (!(at = reader.numbers(5))) break;
                auto radius = static_cast<float>(std::max(0.0, at[4]));
                auto rounded = D2D1::RoundedRect(box(at), radius, radius);
                if (kind == FillRoundedRectangle) context->FillRoundedRectangle(rounded, paint(pen.fill));
                else if (pen.width > 0) context->DrawRoundedRectangle(rounded, paint(pen.stroke), pen.width);
                break;
            }
            case DrawEllipse:
            case FillEllipse: {
                if (!(at = reader.numbers(4))) break;
                auto oval = D2D1::Ellipse(point(at[0] + at[2] / 2, at[1] + at[3] / 2), static_cast<float>(at[2] / 2),
                                          static_cast<float>(at[3] / 2));
                if (kind == FillEllipse) context->FillEllipse(oval, paint(pen.fill));
                else if (pen.width > 0) context->DrawEllipse(oval, paint(pen.stroke), pen.width);
                break;
            }
            case DrawArc:
            case FillArc: {
                bool clockwise = reader.integer() != 0;
                bool closed = kind == FillArc || reader.integer() != 0;
                if ((at = reader.numbers(6))) shape(arc(at, clockwise, closed, kind == FillArc).get(), kind == FillArc);
                break;
            }
            case DrawPath:
            case FillPath:
                shape(curves(reader, reader.integer()).get(), kind == FillPath);
                break;
            case DrawText: {
                auto across = reader.integer(), down = reader.integer(), word = reader.integer();
                if (!(at = reader.numbers(4)) || word < 0 || static_cast<size_t>(word) >= drawing.words.size()) return;
                write(context, paint(pen.text), pen.size, at, across, down, drawing.words[word]);
                break;
            }
            case Translate:
                if (!(at = reader.numbers(2))) break;
                pen.transform = D2D1::Matrix3x2F::Translation(static_cast<float>(at[0]), static_cast<float>(at[1])) * pen.transform;
                place();
                break;
            case Rotate:
                if (!(at = reader.numbers(1))) break;
                pen.transform = D2D1::Matrix3x2F::Rotation(static_cast<float>(*at)) * pen.transform;
                place();
                break;
            case Scale:
                if (!(at = reader.numbers(2))) break;
                pen.transform = D2D1::Matrix3x2F::Scale(static_cast<float>(at[0]), static_cast<float>(at[1])) * pen.transform;
                place();
                break;
            case SaveState:
                kept.push_back(pen);
                break;
            case RestoreState:
                if (kept.empty()) break;
                pen = kept.back();
                kept.pop_back();
                place();
                break;
            default:
                return;
            }
        }
    }

    /// How many canvases there are.
    int32_t canvases = 0;

    /// A canvas: a panel with no size of its own, painted with the surface its drawing is replayed on.
    struct StateUICanvas : controls::PanelT<StateUICanvas> {
        explicit StateUICanvas(int64_t view) : view(view) {
            canvases += 1;
            // A clear background: the whole canvas is hit, drawn on or not.
            Background(media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
            PointerPressed({this, &StateUICanvas::pressed});
            PointerMoved({this, &StateUICanvas::moved});
            PointerReleased({this, &StateUICanvas::released});
            PointerCaptureLost({this, &StateUICanvas::lostPress});
            PointerCanceled({this, &StateUICanvas::lostPress});
            // A canvas put in a tree draws; WinUI's unloading is not heard: it can come after the canvas is loaded
            // again elsewhere, and would stop the drawing that waits.
            Loaded([this](auto &&, auto &&) { invalidate(); });
        }

        ~StateUICanvas() {
            canvases -= 1;
        }

        winrt::Microsoft::UI::Xaml::Automation::Peers::AutomationPeer OnCreateAutomationPeer() {
            IInspectable self = *this;
            return figurePeer(self.as<xaml::FrameworkElement>(), view);
        }

        Size MeasureOverride(Size) {
            return {0, 0};
        }

        Size ArrangeOverride(Size final) {
            if (final != size) {
                size = final;
                invalidate();
            }
            return final;
        }

        /// The drawing to replay from now on.
        void show(Drawing next) {
            drawing = std::move(next);
            stale = true;
            invalidate();
        }

    private:
        /// Draws on the next frame, however often it is asked before then.
        void invalidate() {
            if (!rendering) rendering = media::CompositionTarget::Rendering(winrt::auto_revoke, {get_weak(), &StateUICanvas::render});
        }

        void render(IInspectable const &, IInspectable const &) {
            rendering.revoke();
            auto root = XamlRoot();
            if (!root) return;
            watch(root);
            auto scale = static_cast<float>(root.RasterizationScale());
            auto across = static_cast<int32_t>(std::ceil(size.Width * scale));
            auto down = static_cast<int32_t>(std::ceil(size.Height * scale));
            if (!stale && across == drawnAcross && down == drawnDown && scale == drawnScale) return;

            stale = false;
            drawnScale = scale;
            try {
                if (across <= 0 || down <= 0) {
                    surface = nullptr;
                    drawnAcross = drawnDown = 0;
                    Background(media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
                    return;
                }
                for (int attempt = 0; attempt < 2; ++attempt) {
                    prepare();
                    if (!surface || across != drawnAcross || down != drawnDown || made != devices.made) {
                        surface = media::Imaging::SurfaceImageSource(across, down, false);
                        winrt::check_hresult(surface.as<ISurfaceImageSourceNativeWithD2D>()->SetDevice(devices.device.get()));
                        media::ImageBrush painted;
                        painted.ImageSource(surface);
                        painted.Stretch(media::Stretch::Fill);
                        Background(painted);
                        drawnAcross = across;
                        drawnDown = down;
                        made = devices.made;
                    }
                    auto result = draw(scale);
                    if (!lost(result)) {
                        winrt::check_hresult(result);
                        return;
                    }
                    // Windows took the device away: a new one, a new surface, and the drawing again.
                    devices.device = nullptr;
                }
            } catch (...) {
                report("drawing a canvas");
            }
        }

        /// Replays the drawing on the whole surface, cleared first: the canvas's DIPs at `scale` pixels each.
        HRESULT draw(float scale) {
            auto native = surface.as<ISurfaceImageSourceNativeWithD2D>();
            winrt::com_ptr<ID2D1DeviceContext> context;
            POINT offset{};
            auto began = native->BeginDraw(RECT{0, 0, drawnAcross, drawnDown}, __uuidof(ID2D1DeviceContext),
                                           context.put_void(), &offset);
            if (FAILED(began)) return began;

            // The surface may be part of a larger one: the drawing starts where it does.
            context->SetDpi(96 * scale, 96 * scale);
            context->SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);
            auto base = D2D1::Matrix3x2F::Translation(offset.x / scale, offset.y / scale);
            context->SetTransform(base);
            context->PushAxisAlignedClip(D2D1::RectF(0, 0, drawnAcross / scale, drawnDown / scale), D2D1_ANTIALIAS_MODE_ALIASED);
            context->Clear(D2D1::ColorF(0, 0, 0, 0));
            try {
                replay(context.get(), base, drawing);
            } catch (...) {
                report("replaying a drawing");
            }
            context->PopAxisAlignedClip();
            return native->EndDraw();
        }

        void pressed(IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            auto element = sender.as<xaml::UIElement>();
            auto at = args.GetCurrentPoint(element);
            if (holding || !at.Properties().IsLeftButtonPressed() || !element.CapturePointer(args.Pointer())) return;
            holding = true;
            pointer = args.Pointer().PointerId();
            args.Handled(true);
            tell(0, at.Position());
        }

        void moved(IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            if (!holding || args.Pointer().PointerId() != pointer) return;
            args.Handled(true);
            tell(1, args.GetCurrentPoint(sender.as<xaml::UIElement>()).Position());
        }

        void released(IInspectable const &sender, input::PointerRoutedEventArgs const &args) {
            if (!holding || args.Pointer().PointerId() != pointer) return;
            args.Handled(true);
            auto element = sender.as<xaml::UIElement>();
            auto at = args.GetCurrentPoint(element).Position();
            holding = false;
            element.ReleasePointerCapture(args.Pointer());
            tell(2, at);
        }

        /// The press ends where it last was: its pointer taken away, or the input cancelled.
        void lostPress(IInspectable const &, input::PointerRoutedEventArgs const &args) {
            if (!holding || args.Pointer().PointerId() != pointer) return;
            holding = false;
            tell(2, last);
        }

        void tell(int32_t phase, Point at) {
            last = at;
            callbacks.canvasPressed(view, phase, at.X, at.Y);
        }

        /// Drawn again when the scale of the root it draws in changes, and whenever WinUI's surfaces lose what
        /// they held: both heard for as long as the canvas lives, and neither holds it.
        void watch(xaml::XamlRoot const &root) {
            if (watched.get() != root) {
                watched = winrt::make_weak(root);
                rootChanged = root.Changed(winrt::auto_revoke, {get_weak(), &StateUICanvas::rootChange});
            }
            if (!contentsLost)
                contentsLost = media::CompositionTarget::SurfaceContentsLost(winrt::auto_revoke, {get_weak(), &StateUICanvas::surfaceLost});
        }

        void rootChange(xaml::XamlRoot const &root, xaml::XamlRootChangedEventArgs const &) {
            if (static_cast<float>(root.RasterizationScale()) != drawnScale) invalidate();
        }

        void surfaceLost(IInspectable const &, IInspectable const &) {
            stale = true;
            invalidate();
        }

        int64_t view;
        Drawing drawing;
        Size size{};
        bool stale = false;

        media::Imaging::SurfaceImageSource surface{nullptr};
        int32_t drawnAcross = 0, drawnDown = 0;
        float drawnScale = 0;
        uint32_t made = 0;

        bool holding = false;
        uint32_t pointer = 0;
        Point last{};

        media::CompositionTarget::Rendering_revoker rendering;
        media::CompositionTarget::SurfaceContentsLost_revoker contentsLost;
        winrt::weak_ref<xaml::XamlRoot> watched;
        xaml::XamlRoot::Changed_revoker rootChanged;
    };

    /// The canvas a handle holds, reached through an interface the canvas implements itself: the panel it is made
    /// on answers the rest.
    StateUICanvas *canvas(StateUIObjectRef handle) {
        return winrt::get_self<StateUICanvas>(as<xaml::IFrameworkElementOverrides>(handle));
    }
}

extern "C" StateUIObjectRef stateui_winui_canvas_make(int64_t view) {
    try {
        return detach(winrt::make<StateUICanvas>(view).as<controls::Panel>());
    } catch (...) {
        report("making a canvas");
        return nullptr;
    }
}

extern "C" void stateui_winui_canvas_draw(
    StateUIObjectRef handle, int32_t const *ints, int32_t intCount, double const *numbers, int32_t numberCount,
    char const *words, int32_t const *lengths, int32_t wordCount
) {
    try {
        Drawing drawing;
        drawing.ints.assign(ints, ints + intCount);
        drawing.numbers.assign(numbers, numbers + numberCount);
        for (int32_t index = 0, at = 0; index < wordCount; at += lengths[index++])
            drawing.words.emplace_back(winrt::to_hstring(std::string_view(words + at, lengths[index])));
        canvas(handle)->show(std::move(drawing));
    } catch (...) {
        report("handing a canvas its drawing");
    }
}

extern "C" int32_t stateui_winui_canvases(void) {
    try {
        return canvases;
    } catch (...) {
        report("counting the canvases");
        return 0;
    }
}
