// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a test reads of what WinUI holds, by the property's name: the relay's
// one reader, so a test of the contract reads the native control rather than
// what the host last wrote. And what the dialogs ask and the screen reader was
// told, which WinUI keeps nowhere a test can ask.
// Design: docs/design/platforms/winui/relay.md#what-a-test-reads

#include "Relay.h"

#include <cstdio>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

#include <winrt/Windows.Globalization.DateTimeFormatting.h>
#include <winrt/Windows.UI.h>
#include <winrt/Windows.UI.Text.h>
#include <winrt/Microsoft.UI.Composition.h>
#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Microsoft.UI.Xaml.Documents.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Microsoft.UI.Xaml.Media.Imaging.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;
namespace shapes = winrt::Microsoft::UI::Xaml::Shapes;

namespace {
    /// What the screen reader was told, in order.
    std::vector<std::string> announcements;

    std::string number(double value) {
        char words[32];
        std::snprintf(words, sizeof words, "%.10g", value);
        return words;
    }

    std::string flag(bool value) {
        return value ? "1" : "0";
    }

    std::string narrow(winrt::hstring const &words) {
        return winrt::to_string(words);
    }

    /// A solid brush's colour as #AARRGGBB, its own opacity taken into it; empty for none or another brush.
    std::string colour(media::Brush const &brush) {
        auto solid = brush ? brush.try_as<media::SolidColorBrush>() : media::SolidColorBrush{nullptr};
        if (!solid) return "";
        auto made = solid.Color();
        auto alpha = static_cast<unsigned>(made.A * solid.Opacity() + 0.5);
        char words[10];
        std::snprintf(words, sizeof words, "#%02X%02X%02X%02X", alpha, made.R, made.G, made.B);
        return words;
    }

    std::string sides(xaml::Thickness const &thickness) {
        return number(thickness.Left) + "," + number(thickness.Top) + "," + number(thickness.Right) + "," +
               number(thickness.Bottom);
    }

    std::string corners(xaml::CornerRadius const &radius) {
        return number(radius.TopLeft) + "," + number(radius.TopRight) + "," + number(radius.BottomRight) + "," +
               number(radius.BottomLeft);
    }

    std::string day(winrt::Windows::Foundation::DateTime const &time) {
        auto seconds = winrt::clock::to_time_t(time);
        std::tm parts{};
        gmtime_s(&parts, &seconds);
        char words[16];
        std::snprintf(words, sizeof words, "%04d-%02d-%02d", parts.tm_year + 1900, parts.tm_mon + 1, parts.tm_mday);
        return words;
    }

    /// The first element of type `T` under `element`, depth first.
    template <typename T>
    T first(xaml::DependencyObject const &element) {
        auto count = media::VisualTreeHelper::GetChildrenCount(element);
        for (int32_t index = 0; index < count; ++index) {
            auto child = media::VisualTreeHelper::GetChild(element, index);
            if (auto found = child.try_as<T>()) return found;
            if (auto inner = first<T>(child)) return inner;
        }
        return nullptr;
    }

    /// How words are written on a text block or a control.
    std::optional<std::string> font(IInspectable const &object, std::string_view what) {
        auto text = object.try_as<controls::TextBlock>();
        auto control = object.try_as<controls::Control>();
        if (!text && !control) return std::nullopt;
        if (what == "fontSize") return number(text ? text.FontSize() : control.FontSize());
        if (what == "fontWeight") return number(text ? text.FontWeight().Weight : control.FontWeight().Weight);
        if (what == "italic") {
            return flag((text ? text.FontStyle() : control.FontStyle()) == winrt::Windows::UI::Text::FontStyle::Italic);
        }
        if (what == "fontFamily") return narrow((text ? text.FontFamily() : control.FontFamily()).Source());
        if (what == "characterSpacing") return number(text ? text.CharacterSpacing() : control.CharacterSpacing());
        if (what == "foreground") return colour(text ? text.Foreground() : control.Foreground());
        if (what == "padding") return sides(text ? text.Padding() : control.Padding());
        return std::nullopt;
    }

    /// What a text block alone holds; its runs' words, each ended by the unit separator but the last.
    std::optional<std::string> block(controls::TextBlock const &text, std::string_view what) {
        if (what == "runs") {
            std::string words;
            bool first = true;
            for (auto const &inline_ : text.Inlines()) {
                auto run = inline_.try_as<winrt::Microsoft::UI::Xaml::Documents::Run>();
                if (!run) continue;
                words += (first ? "" : "\x1f") + narrow(run.Text());
                first = false;
            }
            return words;
        }
        if (what == "lineHeight") return number(text.LineHeight());
        if (what == "decorations") return number(static_cast<int32_t>(text.TextDecorations()));
        if (what == "textAlignment") return number(static_cast<int32_t>(text.TextAlignment()));
        if (what == "wrapping") return number(static_cast<int32_t>(text.TextWrapping()));
        if (what == "trimming") return number(static_cast<int32_t>(text.TextTrimming()));
        if (what == "maxLines") return number(text.MaxLines());
        return std::nullopt;
    }

    /// What a field holds: a text box, a password box, or the text box a search box's template holds.
    std::optional<std::string> field(IInspectable const &object, std::string_view what) {
        auto box = object.try_as<controls::TextBox>();
        if (auto search = object.try_as<controls::AutoSuggestBox>()) {
            if (what == "placeholder") return narrow(search.PlaceholderText());
            box = first<controls::TextBox>(search);
        }
        if (auto password = object.try_as<controls::PasswordBox>()) {
            if (what == "password") return "1";
            if (what == "placeholder") return narrow(password.PlaceholderText());
            if (what == "maxLength") return number(password.MaxLength());
            return std::nullopt;
        }
        if (!box) return std::nullopt;
        if (what == "password") return "0";
        if (what == "placeholder") return narrow(box.PlaceholderText());
        if (what == "placeholderForeground") return colour(box.PlaceholderForeground());
        if (what == "maxLength") return number(box.MaxLength());
        if (what == "textAlignment") return number(static_cast<int32_t>(box.TextAlignment()));
        return std::nullopt;
    }

    /// What a shape - a WinUI Path, or the box a layout paints behind its children - is painted with.
    std::optional<std::string> painted(shapes::Shape const &shape, std::string_view what) {
        if (what == "fill") return colour(shape.Fill());
        if (what == "stroke") return colour(shape.Stroke());
        if (what == "strokeThickness") return number(shape.StrokeThickness());
        if (what == "dashes") {
            std::string words;
            for (auto dash : shape.StrokeDashArray()) words += (words.empty() ? "" : ";") + number(dash);
            return words;
        }
        if (what == "dashOffset") return number(shape.StrokeDashOffset());
        if (what == "cap") return number(static_cast<int32_t>(shape.StrokeStartLineCap()));
        if (what == "join") return number(static_cast<int32_t>(shape.StrokeLineJoin()));
        if (what == "miter") return number(shape.StrokeMiterLimit());
        if (what == "stretch") return number(static_cast<int32_t>(shape.Stretch()));
        if (what == "radius") {
            auto rectangle = shape.try_as<shapes::Rectangle>();
            return number(rectangle ? rectangle.RadiusX() : 0);
        }
        if (what == "ellipse") return flag(static_cast<bool>(shape.try_as<shapes::Ellipse>()));
        return std::nullopt;
    }

    /// What a window's chrome holds: its title, its way back, its toggle, its colours and its actions - each action
    /// by its label, "!" before one that cannot be chosen, the overflow's after "|".
    std::optional<std::string> chrome(controls::TitleBar const &bar, std::string_view what) {
        if (what == "title") return narrow(bar.Title());
        if (what == "back") return flag(bar.IsBackButtonVisible());
        if (what == "paneToggle") return flag(bar.IsPaneToggleButtonVisible());
        if (what == "background") return colour(bar.Background());
        if (what == "foreground") return colour(bar.Foreground());
        if (what == "actions") {
            auto actions = bar.RightHeader().as<controls::StackPanel>().Children().GetAt(0).as<controls::CommandBar>();
            auto listed = [](auto const &commands) {
                std::string words;
                for (auto const &command : commands) {
                    auto button = command.template try_as<controls::AppBarButton>();
                    if (!button) continue;
                    words += (words.empty() ? "" : ";") + std::string(button.IsEnabled() ? "" : "!") +
                             narrow(button.Label());
                }
                return words;
            };
            return listed(actions.PrimaryCommands()) + "|" + listed(actions.SecondaryCommands());
        }
        return std::nullopt;
    }

    /// The accent a control wears where the host tinted it: a bar's or a spinner's colour, or the resource its
    /// template takes the accent from.
    std::optional<std::string> tint(IInspectable const &object) {
        if (auto bar = object.try_as<controls::ProgressBar>()) return colour(bar.Foreground());
        if (auto ring = object.try_as<controls::ProgressRing>()) return colour(ring.Foreground());
        wchar_t const *key = object.try_as<controls::CheckBox>()      ? L"CheckBoxCheckBackgroundFillChecked"
                             : object.try_as<controls::ToggleSwitch>() ? L"ToggleSwitchFillOn"
                             : object.try_as<controls::Slider>()       ? L"SliderThumbBackground"
                             : object.try_as<controls::ComboBox>()     ? L"ComboBoxItemPillFillBrush"
                                                                      : nullptr;
        auto element = object.try_as<xaml::FrameworkElement>();
        if (!key || !element) return std::nullopt;
        auto name = winrt::box_value(winrt::hstring(key));
        auto resources = element.Resources();
        if (!resources.HasKey(name)) return std::string();
        return colour(resources.Lookup(name).try_as<media::Brush>());
    }

    /// What a field is for, as StateUI's InputPurpose numbers it: the input scope's first name, found in the
    /// relay's own table of them.
    std::optional<std::string> purpose(IInspectable const &object) {
        auto box = object.try_as<controls::TextBox>();
        if (!box) return std::nullopt;
        auto scope = box.InputScope();
        if (!scope || scope.Names().Size() == 0) return "0";
        auto name = scope.Names().GetAt(0).NameValue();
        for (int32_t index = 0; index < 8; ++index) {
            if (inputScope(index).Names().GetAt(0).NameValue() == name) return number(index);
        }
        return "0";
    }

    std::optional<std::string> read(IInspectable const &object, std::string_view what) {
        if (what == "tint") return tint(object);
        if (what == "purpose") return purpose(object);
        if (auto bar = object.try_as<controls::TitleBar>()) return chrome(bar, what);
        if (auto split = object.try_as<controls::NavigationView>(); split && what == "paneOpen") {
            return flag(split.IsPaneOpen());
        }
        if (auto tabs = object.try_as<controls::SelectorBar>()) {
            if (what == "tabs") {
                std::string words;
                for (auto const &item : tabs.Items()) words += (words.empty() ? "" : ";") + narrow(item.Text());
                return words;
            }
            if (what == "selected") {
                uint32_t index = 0;
                auto chosen = tabs.SelectedItem() && tabs.Items().IndexOf(tabs.SelectedItem(), index);
                return number(chosen ? static_cast<double>(index) : -1);
            }
        }
        if (auto found = font(object, what)) return found;
        if (auto text = object.try_as<controls::TextBlock>()) {
            if (auto found = block(text, what)) return found;
        }
        if (auto found = field(object, what)) return found;
        if (auto shape = object.try_as<shapes::Shape>()) {
            if (auto found = painted(shape, what)) return found;
        }
        if (auto panel = object.try_as<controls::Panel>(); panel && what.rfind("box.", 0) == 0) {
            auto children = panel.Children();
            auto box = children.Size() > 0 ? children.GetAt(0).try_as<shapes::Shape>() : shapes::Shape{nullptr};
            if (!box) return std::string();
            return painted(box, what.substr(4));
        }
        if (auto image = object.try_as<controls::Image>()) {
            if (what == "stretch") return number(static_cast<int32_t>(image.Stretch()));
            if (what == "source") return narrow(winrt::unbox_value_or<winrt::hstring>(image.Tag(), L""));
        }
        if (auto radio = object.try_as<controls::RadioButton>(); radio && what == "groupName") {
            return narrow(radio.GroupName());
        }
        if (auto box = object.try_as<controls::NumberBox>()) {
            if (what == "minimum") return number(box.Minimum());
            if (what == "maximum") return number(box.Maximum());
            if (what == "step") return number(box.SmallChange());
        }
        if (auto picker = object.try_as<controls::ComboBox>()) {
            if (what == "placeholder") return narrow(picker.PlaceholderText());
            if (what == "contentAlignment") return number(static_cast<int32_t>(picker.HorizontalContentAlignment()));
        }
        if (auto picker = object.try_as<controls::CalendarDatePicker>()) {
            if (what == "minimumDate") return day(picker.MinDate());
            if (what == "maximumDate") return day(picker.MaxDate());
            if (what == "dateFormat") return narrow(picker.DateFormat());
            if (what == "longDate") {
                winrt::Windows::Globalization::DateTimeFormatting::DateTimeFormatter longDate(L"longdate");
                return flag(picker.DateFormat() == longDate.Patterns().GetAt(0));
            }
        }
        if (auto picker = object.try_as<controls::TimePicker>(); picker && what == "clock") {
            return narrow(picker.ClockIdentifier());
        }
        if (auto scroller = object.try_as<controls::ScrollViewer>()) {
            if (what == "verticalBar") return number(static_cast<int32_t>(scroller.VerticalScrollBarVisibility()));
            if (what == "horizontalBar") return number(static_cast<int32_t>(scroller.HorizontalScrollBarVisibility()));
            if (what == "verticalMode") return number(static_cast<int32_t>(scroller.VerticalScrollMode()));
            if (what == "horizontalMode") return number(static_cast<int32_t>(scroller.HorizontalScrollMode()));
        }
        if (auto control = object.try_as<controls::Control>()) {
            if (what == "background") return colour(control.Background());
            if (what == "borderBrush") return colour(control.BorderBrush());
            if (what == "borderThickness") return sides(control.BorderThickness());
            if (what == "cornerRadius") return corners(control.CornerRadius());
        }
        if (auto border = object.try_as<controls::Border>()) {
            if (what == "background") return colour(border.Background());
            if (what == "cornerRadius") return corners(border.CornerRadius());
        }
        if (auto element = object.try_as<xaml::FrameworkElement>()) {
            if (what == "automationName") return narrow(xaml::Automation::AutomationProperties::GetName(element));
            if (what == "flowDirection") return number(static_cast<int32_t>(element.FlowDirection()));
            if (what == "hitTestable") return flag(element.IsHitTestVisible());
            if (what == "zIndex") return number(controls::Canvas::GetZIndex(element));
            if (what == "clipped") {
                auto visual = xaml::Hosting::ElementCompositionPreview::GetElementVisual(element);
                return flag(static_cast<bool>(element.Clip()) || static_cast<bool>(visual.Clip()));
            }
        }
        return std::nullopt;
    }

    void copy(std::string const &words, char *utf8, int32_t capacity) {
        if (!utf8 || capacity <= 0) return;
        auto length = std::min<size_t>(words.size(), static_cast<size_t>(capacity - 1));
        std::memcpy(utf8, words.data(), length);
        utf8[length] = 0;
    }

    controls::ContentDialog shownDialog(xaml::XamlRoot const &root) {
        for (auto const &popup : media::VisualTreeHelper::GetOpenPopupsForXamlRoot(root))
            if (auto dialog = popup.Child().try_as<controls::ContentDialog>()) return dialog;
        return nullptr;
    }
}

extern "C" int32_t stateui_winui_read(StateUIObjectRef handle, char const *what, char *utf8, int32_t capacity) {
    try {
        IInspectable object{nullptr};
        winrt::copy_from_abi(object, handle);
        auto value = read(object, what ? what : "");
        if (!value) return -1;
        copy(*value, utf8, capacity);
        return static_cast<int32_t>(value->size());
    } catch (winrt::hresult_error const &error) {
        report(error, "reading an element");
        return -1;
    }
}

extern "C" int32_t stateui_winui_question(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        auto dialog = shownDialog(as<xaml::UIElement>(handle).XamlRoot());
        if (!dialog) return -1;
        std::string const separator = "\x1f";
        auto title = narrow(winrt::unbox_value_or<winrt::hstring>(dialog.Title(), L""));
        std::string message;
        std::string field = "\x01";
        std::vector<std::string> choices;
        if (auto words = dialog.Content().try_as<controls::TextBlock>()) message = narrow(words.Text());
        if (auto panel = dialog.Content().try_as<controls::StackPanel>()) {
            for (auto const &child : panel.Children()) {
                if (auto words = child.try_as<controls::TextBlock>()) message = narrow(words.Text());
                if (auto box = child.try_as<controls::TextBox>()) field = narrow(box.Text());
                if (auto button = child.try_as<controls::Button>()) {
                    choices.push_back(narrow(winrt::unbox_value_or<winrt::hstring>(button.Content(), L"")));
                }
            }
        }
        auto words = title + separator + message + separator + narrow(dialog.PrimaryButtonText()) + separator +
                     narrow(dialog.CloseButtonText()) + separator + field;
        for (auto const &choice : choices) words += separator + choice;
        copy(words, utf8, capacity);
        return static_cast<int32_t>(words.size());
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a question");
        return -1;
    }
}

extern "C" int32_t stateui_winui_announced(char *utf8, int32_t capacity) {
    std::string words;
    for (auto const &said : announcements) words += (words.empty() ? "" : "\x1f") + said;
    copy(words, utf8, capacity);
    return static_cast<int32_t>(words.size());
}

void stateui::announced(std::string const &words) {
    announcements.push_back(words);
}
