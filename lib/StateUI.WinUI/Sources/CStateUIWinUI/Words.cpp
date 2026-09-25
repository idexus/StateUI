// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How words look, on a text block or on any control showing them: their font,
// their colour and the room around them; and a label's lines, alignment,
// spacing and decorations.
// Design: docs/design/platforms/winui/controls.md#words

#include "Relay.h"

#include <winrt/Windows.UI.h>
#include <winrt/Windows.UI.Text.h>
#include <winrt/Microsoft.UI.Text.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    winrt::Windows::UI::Color color(uint32_t argb) {
        return {static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8),
                static_cast<uint8_t>(argb)};
    }

    /// A solid brush's colour as 0xAARRGGBB; 0 for any other.
    double argb(media::Brush const &brush) {
        auto solid = brush.try_as<media::SolidColorBrush>();
        if (!solid) return 0;
        auto c = solid.Color();
        return static_cast<double>(static_cast<uint32_t>(c.A) << 24 | static_cast<uint32_t>(c.R) << 16
                                   | static_cast<uint32_t>(c.G) << 8 | c.B);
    }

    /// Runs `block` on a text block, or `control` on a control; the element is one or the other.
    template <typename OnBlock, typename OnControl>
    void either(StateUIObjectRef handle, OnBlock block, OnControl control) {
        auto object = as<IInspectable>(handle);
        if (auto text = object.try_as<controls::TextBlock>()) block(text);
        else if (auto other = object.try_as<controls::Control>()) control(other);
    }
}

extern "C" void stateui_winui_set_font(StateUIObjectRef handle, double size, bool bold, bool italic, char const *family) {
    try {
        auto weight = bold ? winrt::Microsoft::UI::Text::FontWeights::Bold() : winrt::Microsoft::UI::Text::FontWeights::Normal();
        auto style = italic ? winrt::Windows::UI::Text::FontStyle::Italic : winrt::Windows::UI::Text::FontStyle::Normal;
        auto named = family && *family ? media::FontFamily(text(family)) : media::FontFamily{nullptr};
        auto apply = [&](auto const &element, auto sizeProperty, auto familyProperty) {
            if (size > 0) element.FontSize(size);
            else element.ClearValue(sizeProperty);
            element.FontWeight(weight);
            element.FontStyle(style);
            if (named) element.FontFamily(named);
            else element.ClearValue(familyProperty);
        };
        either(handle,
            [&](controls::TextBlock const &block) {
                apply(block, controls::TextBlock::FontSizeProperty(), controls::TextBlock::FontFamilyProperty());
            },
            [&](controls::Control const &control) {
                apply(control, controls::Control::FontSizeProperty(), controls::Control::FontFamilyProperty());
            });
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a font");
    }
}

extern "C" void stateui_winui_set_foreground(StateUIObjectRef handle, bool has, uint32_t argb) {
    try {
        auto brush = has ? media::SolidColorBrush(color(argb)) : media::SolidColorBrush{nullptr};
        either(handle,
            [&](controls::TextBlock const &block) {
                if (has) block.Foreground(brush);
                else block.ClearValue(controls::TextBlock::ForegroundProperty());
            },
            [&](controls::Control const &control) {
                if (has) control.Foreground(brush);
                else control.ClearValue(controls::Control::ForegroundProperty());
                // A button's template draws its words in its own colour under the pointer and pressed.
                if (!control.try_as<controls::Button>()) return;
                auto resources = control.Resources();
                for (auto key : {L"ButtonForeground", L"ButtonForegroundPointerOver", L"ButtonForegroundPressed"}) {
                    auto name = winrt::box_value(key);
                    if (resources.HasKey(name)) resources.Remove(name);
                    if (has) resources.Insert(name, brush);
                }
            });
    } catch (winrt::hresult_error const &error) {
        report(error, "colouring words");
    }
}

extern "C" void stateui_winui_set_padding(StateUIObjectRef handle, double left, double top, double right, double bottom) {
    try {
        xaml::Thickness room{left, top, right, bottom};
        either(handle,
            [&](controls::TextBlock const &block) { block.Padding(room); },
            [&](controls::Control const &control) { control.Padding(room); });
    } catch (winrt::hresult_error const &error) {
        report(error, "setting the room around words");
    }
}

extern "C" void stateui_winui_text_set_lines(StateUIObjectRef handle, int32_t breaking, int32_t maximum) {
    try {
        auto block = borrow<controls::TextBlock>(handle);
        // StateUI's LineBreak: no wrap, word wrap, character wrap, then head, tail and middle truncation.
        bool wraps = breaking == 1 || breaking == 2;
        block.TextWrapping(wraps ? xaml::TextWrapping::Wrap : xaml::TextWrapping::NoWrap);
        block.TextTrimming(breaking >= 3 ? xaml::TextTrimming::CharacterEllipsis : xaml::TextTrimming::None);
        block.MaxLines(wraps ? std::max(0, maximum) : 1);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a label's lines");
    }
}

extern "C" void stateui_winui_text_set_alignment(StateUIObjectRef handle, int32_t horizontal) {
    try {
        auto aligned = horizontal == 1 ? xaml::TextAlignment::Center
            : horizontal == 2 ? xaml::TextAlignment::End : xaml::TextAlignment::Start;
        borrow<controls::TextBlock>(handle).TextAlignment(aligned);
    } catch (winrt::hresult_error const &error) {
        report(error, "aligning a label's words");
    }
}

extern "C" void stateui_winui_text_set_spacing(StateUIObjectRef handle, int32_t characterSpacing, double lineHeight) {
    try {
        auto block = borrow<controls::TextBlock>(handle);
        block.CharacterSpacing(characterSpacing);
        block.LineStackingStrategy(lineHeight > 0 ? xaml::LineStackingStrategy::BlockLineHeight
                                                  : xaml::LineStackingStrategy::MaxHeight);
        block.LineHeight(lineHeight > 0 ? lineHeight : 0);
    } catch (winrt::hresult_error const &error) {
        report(error, "spacing a label's words");
    }
}

extern "C" void stateui_winui_text_set_decorations(StateUIObjectRef handle, bool underline, bool strikethrough) {
    try {
        using winrt::Windows::UI::Text::TextDecorations;
        auto lines = TextDecorations::None;
        if (underline) lines = lines | TextDecorations::Underline;
        if (strikethrough) lines = lines | TextDecorations::Strikethrough;
        borrow<controls::TextBlock>(handle).TextDecorations(lines);
    } catch (winrt::hresult_error const &error) {
        report(error, "decorating a label's words");
    }
}

extern "C" void stateui_winui_text_style(StateUIObjectRef handle, double *style) {
    try {
        either(handle,
            [&](controls::TextBlock const &block) {
                style[0] = block.FontSize();
                style[1] = block.FontWeight().Weight;
                style[2] = block.MaxLines();
                style[3] = static_cast<double>(block.TextAlignment());
                style[4] = argb(block.Foreground());
            },
            [&](controls::Control const &control) {
                style[0] = control.FontSize();
                style[1] = control.FontWeight().Weight;
                style[2] = 0;
                style[3] = 0;
                style[4] = argb(control.Foreground());
            });
    } catch (winrt::hresult_error const &error) {
        report(error, "reading how words look");
    }
}
