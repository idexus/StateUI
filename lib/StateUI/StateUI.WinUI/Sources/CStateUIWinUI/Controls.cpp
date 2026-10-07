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
    auto button = element.try_as<controls::Button>();
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
        labelWords(handle).VerticalAlignment(vertical == 1 ? xaml::VerticalAlignment::Center
                                             : vertical == 2 ? xaml::VerticalAlignment::Bottom
                                                             : xaml::VerticalAlignment::Stretch);
    } catch (...) {
        report("standing a label's words across its height");
    }
}

extern "C" StateUIObjectRef stateui_winui_button_make(int64_t view) {
    try {
        controls::Button button;
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
    double underPointer, double pressed
) {
    try {
        auto button = borrow<controls::Button>(handle);
        auto resources = button.Resources();
        auto keep = [&](wchar_t const *key, xaml::Media::Brush const &value) {
            auto name = winrt::box_value(key);
            if (resources.HasKey(name)) resources.Remove(name);
            if (value) resources.Insert(name, value);
        };
        // Under the pointer and pressed, the fill is drawn a little fainter each time, as WinUI's own buttons draw it.
        auto fill = brush(background);
        auto faded = [&](double opacity) {
            auto made = brush(background);
            if (made) made.Opacity(opacity);
            return made;
        };
        if (fill) button.Background(fill);
        else button.ClearValue(controls::Control::BackgroundProperty());
        keep(L"ButtonBackground", fill);
        keep(L"ButtonBackgroundPointerOver", faded(underPointer));
        keep(L"ButtonBackgroundPressed", faded(pressed));

        auto outline = lineWidth > 0 ? brush(stroke) : xaml::Media::Brush{nullptr};
        if (outline) {
            button.BorderBrush(outline);
            button.BorderThickness({lineWidth, lineWidth, lineWidth, lineWidth});
        } else {
            button.ClearValue(controls::Control::BorderBrushProperty());
            button.ClearValue(controls::Control::BorderThicknessProperty());
        }
        keep(L"ButtonBorderBrush", outline);
        keep(L"ButtonBorderBrushPointerOver", outline);
        keep(L"ButtonBorderBrushPressed", outline);

        if (cornerRadius >= 0) button.CornerRadius({cornerRadius, cornerRadius, cornerRadius, cornerRadius});
        else button.ClearValue(controls::Control::CornerRadiusProperty());
    } catch (...) {
        report("dressing a button");
    }
}

extern "C" void stateui_winui_set_caption(StateUIObjectRef handle, char const *utf8) {
    try {
        as<controls::ContentControl>(handle).Content(winrt::box_value(text(utf8)));
    } catch (...) {
        report("setting a caption");
    }
}

extern "C" void stateui_winui_button_set_content(
    StateUIObjectRef handle, char const *words, char const *icons, int32_t position, double spacing, int32_t aspect,
    bool wraps, bool trims
) {
    try {
        auto button = borrow<controls::Button>(handle);
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
        auto button = borrow<controls::Button>(handle);
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
        pattern<provider::IInvokeProvider>(borrow<controls::Button>(handle), PatternInterface::Invoke).Invoke();
    } catch (...) {
        report("pressing a button");
    }
}
