// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The controls: a text block and a button, and what the user does to them.
// Each handler names its view by number and holds nothing of the control it is
// on.

#include "Automation.h"

#include <algorithm>
#include <limits>

#include <winrt/Windows.System.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;

namespace {
    /// What a label with no background is drawn over: nothing, which is still hit across its bounds.
    xaml::Media::SolidColorBrush clearGround() {
        return xaml::Media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0});
    }
}

controls::TextBlock stateui::wordsOf(IInspectable const &element) {
    if (auto block = element.try_as<controls::TextBlock>()) return block;
    if (auto border = element.try_as<controls::Border>()) return border.Child().try_as<controls::TextBlock>();
    return nullptr;
}

controls::TextBlock stateui::labelWords(StateUIObjectRef handle) {
    auto words = wordsOf(as<IInspectable>(handle));
    if (!words) winrt::throw_hresult(E_INVALIDARG);
    return words;
}

controls::TextBlock stateui::captionOf(IInspectable const &element) {
    // A button's, or a split button's, which shows its words as a button does.
    auto button = element.try_as<controls::Button>() || element.try_as<controls::SplitButton>()
        ? element.try_as<controls::ContentControl>() : nullptr;
    if (!button) return nullptr;
    auto content = button.Content();
    if (auto block = content.try_as<controls::TextBlock>()) return block;
    if (auto both = content.try_as<controls::StackPanel>())
        for (auto const &child : both.Children())
            if (auto block = child.try_as<controls::TextBlock>()) return block;
    return nullptr;
}

xaml::UIElement stateui::metOf(IInspectable const &element) {
    if (auto border = element.try_as<controls::Border>()) {
        if (auto block = border.Child().try_as<controls::TextBlock>()) return block;
        // A picture's image, or its icon's glyph in a box.
        if (auto image = border.Child().try_as<controls::Image>()) return image;
        if (auto box = border.Child().try_as<controls::Viewbox>()) return box.Child();
    }
    return element.as<xaml::UIElement>();
}

extern "C" StateUIObjectRef stateui_winui_text_make(void) {
    try {
        // The words stand in a border, which draws what they are drawn over and stands them across its height as
        // their alignment says: a text block does neither.
        controls::TextBlock block;
        block.TextWrapping(xaml::TextWrapping::Wrap);
        controls::Border label;
        label.Background(clearGround());
        label.Child(block);
        return detach(label);
    } catch (...) {
        report("making a label");
        return nullptr;
    }
}

extern "C" void stateui_winui_text_set_text(StateUIObjectRef handle, char const *utf8) {
    try {
        labelWords(handle).Text(text(utf8));
    } catch (...) {
        report("setting a label's words");
    }
}

extern "C" void stateui_winui_text_set_background(StateUIObjectRef handle, StateUIBrush background) {
    try {
        auto fill = brush(background);
        borrow<controls::Border>(handle).Background(fill ? fill : clearGround());
    } catch (...) {
        report("setting what a label is drawn over");
    }
}

extern "C" void stateui_winui_text_set_vertical(StateUIObjectRef handle, int32_t vertical) {
    try {
        auto down = xaml::VerticalAlignment::Stretch;
        switch (static_cast<StateUITextAlignment>(vertical)) {
        case StateUITextAlignmentStart: down = xaml::VerticalAlignment::Stretch; break;
        case StateUITextAlignmentCenter: down = xaml::VerticalAlignment::Center; break;
        case StateUITextAlignmentEnd: down = xaml::VerticalAlignment::Bottom; break;
        }
        labelWords(handle).VerticalAlignment(down);
    } catch (...) {
        report("standing a label's words across its height");
    }
}

extern "C" void stateui_winui_text_set_selectable(StateUIObjectRef handle, bool selectable) {
    try {
        labelWords(handle).IsTextSelectionEnabled(selectable);
    } catch (...) {
        report("letting a label's words be selected");
    }
}

extern "C" StateUIObjectRef stateui_winui_button_make(int64_t view, StateUIButtonKind kind) {
    try {
        if (kind == StateUIButtonKindSplit) {
            controls::SplitButton split;
            split.Click(guarded("handling Click",
                [view](controls::SplitButton const &, controls::SplitButtonClickEventArgs const &) {
                    callbacks.clicked(view);
                }));
            return detach(split);
        }
        controls::Button button = kind == StateUIButtonKindDropDown ? controls::DropDownButton() : controls::Button();
        button.Click(guarded("handling Click",
            [view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.clicked(view); }));
        // Held down by a pointer or a key, and let go: what WinUI's own pressed look follows.
        button.RegisterPropertyChangedCallback(
            controls::Primitives::ButtonBase::IsPressedProperty(),
            [view](xaml::DependencyObject const &sender, xaml::DependencyProperty const &) {
                callbacks.held(view, sender.as<controls::Primitives::ButtonBase>().IsPressed());
            });
        return detach(button);
    } catch (...) {
        report("making a button");
        return nullptr;
    }
}

extern "C" void stateui_winui_button_set_look(
    StateUIObjectRef handle, StateUIBrush background, StateUIBrush stroke, double lineWidth, double cornerRadius,
    bool drawsOval, double width, double height, double underPointer, double pressed
) {
    try {
        // A Button or a SplitButton: one QueryInterface finds the control either way.
        auto button = as<controls::Control>(handle);
        // A split button's style reads keys of its own; what its template reads is written as one, so a brush that
        // comes or goes has its template read it again.
        std::wstring kind = button.try_as<controls::SplitButton>() ? L"SplitButton" : L"Button";
        std::vector<std::pair<std::wstring, xaml::Media::Brush>> brushes;
        auto keep = [&](std::wstring const &key, xaml::Media::Brush const &value) { brushes.emplace_back(key, value); };
        // Under the pointer and pressed, the fill is drawn a little fainter each time, as WinUI's own buttons draw it.
        // An oval, which the button's corners cannot draw, is a brush of its own holding the outline too.
        auto faded = [&](double opacity) -> xaml::Media::Brush {
            if (drawsOval) return oval(background, stroke, lineWidth, opacity, width, height);
            auto made = brush(background);
            if (made) made.Opacity(opacity);
            return made;
        };
        auto fill = faded(1);
        if (fill) button.Background(fill);
        else button.ClearValue(controls::Control::BackgroundProperty());
        // The accent's style reads its own keys: a main action's button wears the look written for it too.
        for (std::wstring style : {L"", L"Accent"}) {
            keep(style + kind + L"Background", fill);
            keep(style + kind + L"BackgroundPointerOver", faded(underPointer));
            keep(style + kind + L"BackgroundPressed", faded(pressed));
        }

        auto outline = lineWidth > 0 && !drawsOval ? brush(stroke) : xaml::Media::Brush{nullptr};
        if (outline) {
            button.BorderBrush(outline);
            button.BorderThickness({lineWidth, lineWidth, lineWidth, lineWidth});
        } else if (drawsOval) {
            button.BorderThickness({0, 0, 0, 0});
        } else {
            button.ClearValue(controls::Control::BorderBrushProperty());
            button.ClearValue(controls::Control::BorderThicknessProperty());
        }
        for (std::wstring style : {L"", L"Accent"}) {
            keep(style + kind + L"BorderBrush", outline);
            keep(style + kind + L"BorderBrushPointerOver", outline);
            keep(style + kind + L"BorderBrushPressed", outline);
        }
        writeResources(button, brushes);

        if (cornerRadius >= 0) button.CornerRadius({cornerRadius, cornerRadius, cornerRadius, cornerRadius});
        else button.ClearValue(controls::Control::CornerRadiusProperty());
    } catch (...) {
        report("dressing a button");
    }
}

extern "C" void stateui_winui_button_set_accent(StateUIObjectRef handle, bool accent) {
    try {
        // WinUI writes the accent for its Button alone.
        auto button = as<IInspectable>(handle).try_as<controls::Button>();
        if (!button) return;
        auto style = accent
            ? xaml::Application::Current().Resources().TryLookup(winrt::box_value(L"AccentButtonStyle")).try_as<xaml::Style>()
            : nullptr;
        if (style) button.Style(style);
        else button.ClearValue(xaml::FrameworkElement::StyleProperty());
    } catch (...) {
        report("giving a button the accent");
    }
}

extern "C" void stateui_winui_button_set_critical(StateUIObjectRef handle, bool critical) {
    try {
        // The theme's critical colour under the button's words, as a destructive entry's: a colour the tree writes
        // in the button's own resources stands over it.
        auto button = as<controls::Control>(handle);
        std::wstring name = button.try_as<controls::SplitButton>() ? L"SplitButtonForeground" : L"ButtonForeground";
        if (critical == isDestructive(button, name.c_str())) return;
        auto merged = button.Resources().MergedDictionaries();
        if (critical) {
            markDestructive(button, {name, name + L"PointerOver", name + L"Pressed"});
        } else {
            for (uint32_t index = merged.Size(); index-- > 0;) {
                for (auto const &theme : merged.GetAt(index).ThemeDictionaries()) {
                    auto dictionary = theme.Value().try_as<xaml::ResourceDictionary>();
                    if (dictionary && ownBrush(dictionary, name)) {
                        merged.RemoveAt(index);
                        break;
                    }
                }
            }
        }
        readThemeAgain(button);
    } catch (...) {
        report("marking a button destructive");
    }
}

extern "C" bool stateui_winui_button_critical(StateUIObjectRef handle) {
    try {
        auto button = as<controls::Control>(handle);
        return isDestructive(button, button.try_as<controls::SplitButton>() ? L"SplitButtonForeground" : L"ButtonForeground");
    } catch (...) {
        report("reading whether a button is marked destructive");
        return false;
    }
}

extern "C" bool stateui_winui_button_accent(StateUIObjectRef handle) {
    try {
        auto style = as<controls::Control>(handle).Style();
        return style && style == xaml::Application::Current().Resources().TryLookup(winrt::box_value(L"AccentButtonStyle"));
    } catch (...) {
        report("reading a button's accent");
        return false;
    }
}

extern "C" void stateui_winui_button_set_content(
    StateUIObjectRef handle, char const *words, char const *icons, int32_t position, double spacing, int32_t aspect,
    bool wraps, bool trims
) {
    try {
        auto button = as<controls::ContentControl>(handle);
        auto picture = pictureImage(icons);
        auto caption = text(words);
        controls::TextBlock block{nullptr};
        if (!caption.empty() || !picture) {
            block = controls::TextBlock();
            block.Text(caption);
            block.CharacterSpacing(button.CharacterSpacing());
            block.TextWrapping(wraps ? xaml::TextWrapping::Wrap : xaml::TextWrapping::NoWrap);
            block.TextTrimming(trims ? xaml::TextTrimming::CharacterEllipsis : xaml::TextTrimming::None);
        }
        auto alone = picture && !block;
        // Words beside a picture are no content WinUI names the button by: they label it.
        if (picture && block) xaml::Automation::AutomationProperties::SetLabeledBy(button, block);
        else button.ClearValue(xaml::Automation::AutomationProperties::LabeledByProperty());
        if (alone) {
            button.HorizontalContentAlignment(xaml::HorizontalAlignment::Stretch);
            button.VerticalContentAlignment(xaml::VerticalAlignment::Stretch);
        } else {
            button.ClearValue(controls::Control::HorizontalContentAlignmentProperty());
            button.ClearValue(controls::Control::VerticalContentAlignmentProperty());
        }
        if (!picture) {
            button.Content(block);
            return;
        }
        // Alone, the picture fills the room inside the padding as StateUI's ContentMode says: fit, fill, stretch,
        // centre. Beside words it stands at its own size, smaller where the button is.
        controls::Viewbox box;
        box.Child(picture);
        if (alone) {
            box.Stretch(aspect == 1 ? xaml::Media::Stretch::UniformToFill
                        : aspect == 2 ? xaml::Media::Stretch::Fill
                        : aspect == 3 ? xaml::Media::Stretch::None : xaml::Media::Stretch::Uniform);
            button.Content(box);
            return;
        }
        box.StretchDirection(controls::StretchDirection::DownOnly);
        // StateUI's IconPosition: before the words (0), above (1), after (2), below (3), apart by the spacing given
        // or WinUI Gallery's 8.
        auto across = position == 0 || position == 2;
        controls::StackPanel both;
        both.Orientation(across ? controls::Orientation::Horizontal : controls::Orientation::Vertical);
        both.Spacing(spacing >= 0 ? spacing : 8);
        for (xaml::FrameworkElement part : {xaml::FrameworkElement(box), xaml::FrameworkElement(block)}) {
            if (across) part.VerticalAlignment(xaml::VerticalAlignment::Center);
            else part.HorizontalAlignment(xaml::HorizontalAlignment::Center);
        }
        auto after = position == 2 || position == 3;
        both.Children().Append(after ? xaml::UIElement(block) : xaml::UIElement(box));
        both.Children().Append(after ? xaml::UIElement(box) : xaml::UIElement(block));
        button.Content(both);
    } catch (...) {
        report("setting what a button shows");
    }
}

extern "C" void stateui_winui_button_set_room(StateUIObjectRef handle, double height) {
    try {
        auto button = as<controls::ContentControl>(handle);
        auto both = button.Content().try_as<controls::StackPanel>();
        if (!both) return;
        controls::Viewbox box{nullptr};
        for (auto const &child : both.Children())
            if (auto found = child.try_as<controls::Viewbox>()) box = found;
        if (!box) return;
        // The room inside the padding and the outline, less the words' line where the picture stands above or
        // below them.
        auto padding = button.Padding();
        auto border = button.BorderThickness();
        auto room = height - padding.Top - padding.Bottom - border.Top - border.Bottom;
        if (both.Orientation() == controls::Orientation::Vertical) {
            if (auto caption = captionOf(button)) room -= caption.DesiredSize().Height + both.Spacing();
        }
        auto bound = height > 0 ? std::max(0.0, room) : std::numeric_limits<double>::infinity();
        if (box.MaxHeight() != bound) box.MaxHeight(bound);
    } catch (...) {
        report("bounding a button's picture");
    }
}

extern "C" void stateui_winui_button_set_words(StateUIObjectRef handle, char const *words) {
    try {
        if (auto block = captionOf(as<IInspectable>(handle))) block.Text(text(words));
    } catch (...) {
        report("setting a button's words");
    }
}

extern "C" bool stateui_winui_go_to_state(StateUIObjectRef handle, char const *state) {
    try {
        return xaml::VisualStateManager::GoToState(as<controls::Control>(handle), text(state), false);
    } catch (...) {
        report("putting a control in a visual state");
        return false;
    }
}

extern "C" void stateui_winui_button_invoke(StateUIObjectRef handle) {
    try {
        pattern<provider::IInvokeProvider>(as<xaml::UIElement>(handle), PatternInterface::Invoke).Invoke();
    } catch (...) {
        report("pressing a button");
    }
}
