// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Menus: a view's context menu - WinUI's MenuFlyout on the element, opened by
// a right click, the menu key, a long press - and a window's menu bar, WinUI's
// MenuBar. Both are written from the same flat entries - items, separators
// and submenus - an item with its picture and its destructive mark, each
// item's choice told through `menuChosen` by its place among the items.
// Design: docs/design/platforms/winui/pages.md#menus

#include "Automation.h"

#include <winrt/Microsoft.UI.Xaml.Automation.h>

#include <algorithm>
#include <functional>
#include <cstring>
#include <string>
#include <string_view>
#include <vector>

using namespace stateui;
using Entries = winrt::Windows::Foundation::Collections::IVector<controls::MenuFlyoutItemBase>;

namespace {
    /// Gives `entry` the identifier whatever drives the application finds it by; none for an empty one.
    void identify(xaml::UIElement const &entry, char const *identifier) {
        if (identifier && *identifier) {
            xaml::Automation::AutomationProperties::SetAutomationId(entry, text(identifier));
        }
    }

    /// Writes a menu's flat entries into the lists they belong to: an item (0), a separator (1), a submenu opening
    /// (2) and closing (3), an item standing unchecked (4) or checked (5). On a bar, a menu at the top is one of the
    /// bar's own. An item's shortcut is WinUI's accelerator on a bar, whose words WinUI shows beside it; a context
    /// menu's item only shows its words, its accelerator held disabled.
    struct Writer {
        int64_t view;
        controls::MenuBar bar{nullptr};
        std::vector<Entries> levels;
        int32_t chosen = 0;

        void write(int32_t kind, char const *title, bool enabled, char const *identifier, char const *icon,
                   bool destructive, int32_t key, int32_t modifiers, bool givesWay) {
            if (kind == 3) {
                if (levels.size() > (bar ? 0u : 1u)) levels.pop_back();
                return;
            }
            if (bar && levels.empty()) {
                if (kind != 2) return;
                controls::MenuBarItem menu;
                menu.Title(text(title));
                menu.IsEnabled(enabled);
                identify(menu, identifier);
                bar.Items().Append(menu);
                levels.push_back(menu.Items());
                return;
            }
            switch (kind) {
            case 0:
            case 4:
            case 5: {
                controls::MenuFlyoutItem item = kind == 0 ? controls::MenuFlyoutItem() : controls::ToggleMenuFlyoutItem();
                if (kind != 0) item.as<controls::ToggleMenuFlyoutItem>().IsChecked(kind == 5);
                item.Text(text(title));
                item.IsEnabled(enabled);
                identify(item, identifier);
                if (auto pictured = pictureIcon(icon)) item.Icon(pictured);
                if (destructive)
                    markDestructive(item, {L"MenuFlyoutItemForeground", L"MenuFlyoutItemForegroundPointerOver",
                                           L"MenuFlyoutItemForegroundPressed"});
                if (key != 0) {
                    auto held = accelerator(key, modifiers, givesWay);
                    if (!bar) {
                        held.IsEnabled(false);
                        item.KeyboardAcceleratorTextOverride(acceleratorText(key, modifiers));
                    }
                    item.KeyboardAccelerators().Append(held);
                }
                item.Click(guarded("handling Click",
                    [view = view, place = chosen++](IInspectable const &, xaml::RoutedEventArgs const &) {
                    callbacks.menuChosen(view, place);
                }));
                levels.back().Append(item);
                break;
            }
            case 1:
                levels.back().Append(controls::MenuFlyoutSeparator());
                break;
            case 2: {
                controls::MenuFlyoutSubItem sub;
                sub.Text(text(title));
                sub.IsEnabled(enabled);
                identify(sub, identifier);
                levels.back().Append(sub);
                levels.push_back(sub.Items());
                break;
            }
            }
        }
    };

    /// The entries as a test reads them: items by caption, "!" before one that cannot be chosen, "-" a separator,
    /// a submenu's entries in brackets after its caption, ";" between.
    std::wstring described(Entries const &entries) {
        std::wstring text;
        for (auto const &entry : entries) {
            if (!text.empty()) text += L";";
            if (entry.try_as<controls::MenuFlyoutSeparator>()) {
                text += L"-";
            } else if (auto sub = entry.try_as<controls::MenuFlyoutSubItem>()) {
                text += (sub.IsEnabled() ? L"" : L"!") + std::wstring(sub.Text()) + L"[" + described(sub.Items()) + L"]";
            } else if (auto item = entry.try_as<controls::MenuFlyoutItem>()) {
                text += (item.IsEnabled() ? L"" : L"!") + std::wstring(item.Text());
            }
        }
        return text;
    }

    /// The item at `index` among the entries' items, submenus' included, in the order they stand; null past the last.
    controls::MenuFlyoutItem item(Entries const &entries, int32_t &index) {
        for (auto const &entry : entries) {
            if (auto sub = entry.try_as<controls::MenuFlyoutSubItem>()) {
                if (auto found = item(sub.Items(), index)) return found;
            } else if (auto each = entry.try_as<controls::MenuFlyoutItem>()) {
                if (index-- == 0) return each;
            }
        }
        return nullptr;
    }

    /// The menu an element offers: a button's flyout, which it opens, else its context menu.
    controls::MenuFlyout offered(xaml::UIElement const &element) {
        if (auto split = element.try_as<controls::SplitButton>()) {
            if (auto flyout = split.Flyout().try_as<controls::MenuFlyout>()) return flyout;
        } else if (auto button = element.try_as<controls::Button>()) {
            if (auto flyout = button.Flyout().try_as<controls::MenuFlyout>()) return flyout;
        }
        return element.ContextFlyout().try_as<controls::MenuFlyout>();
    }

    /// The entries of each menu an element offers: its button's or context menu's, or each of a bar's menus.
    std::vector<Entries> menus(xaml::UIElement const &element) {
        std::vector<Entries> found;
        if (auto bar = element.try_as<controls::MenuBar>()) {
            for (auto const &menu : bar.Items()) found.push_back(menu.Items());
        } else if (auto flyout = offered(element)) {
            found.push_back(flyout.Items());
        }
        return found;
    }
}

extern "C" void stateui_winui_set_context_menu(
    StateUIObjectRef handle, int64_t view, int32_t const *kinds, char const *const *titles, bool const *enabled,
    char const *const *identifiers, char const *const *icons, bool const *destructive, int32_t const *keys,
    int32_t const *modifiers, bool const *givesWay, int32_t count
) {
    try {
        auto element = as<xaml::UIElement>(handle);
        if (count == 0) {
            element.ContextFlyout(nullptr);
        } else {
            controls::MenuFlyout flyout;
            Writer writer{view, nullptr, {flyout.Items()}};
            for (int32_t index = 0; index < count; ++index) {
                writer.write(kinds[index], titles[index], enabled[index], identifiers[index], icons[index],
                             destructive[index], keys[index], modifiers[index], givesWay[index]);
            }
            element.ContextFlyout(flyout);
        }
        holdHitArea(element, view);
    } catch (...) {
        report("giving a view its context menu");
    }
}

extern "C" void stateui_winui_button_set_menu(
    StateUIObjectRef handle, int64_t view, int32_t const *kinds, char const *const *titles, bool const *enabled,
    char const *const *identifiers, char const *const *icons, bool const *destructive, int32_t const *keys,
    int32_t const *modifiers, bool const *givesWay, int32_t count
) {
    try {
        controls::MenuFlyout flyout;
        Writer writer{view, nullptr, {flyout.Items()}};
        for (int32_t index = 0; index < count; ++index) {
            writer.write(kinds[index], titles[index], enabled[index], identifiers[index], icons[index],
                         destructive[index], keys[index], modifiers[index], givesWay[index]);
        }
        auto element = as<IInspectable>(handle);
        if (auto split = element.try_as<controls::SplitButton>()) split.Flyout(flyout);
        else if (auto button = element.try_as<controls::Button>()) button.Flyout(flyout);
    } catch (...) {
        report("giving a button its menu");
    }
}

extern "C" StateUIObjectRef stateui_winui_menu_bar_make(int64_t) {
    try {
        return detach(controls::MenuBar());
    } catch (...) {
        report("making a menu bar");
        return nullptr;
    }
}

extern "C" void stateui_winui_menu_bar_set(
    StateUIObjectRef handle, int64_t view, int32_t const *kinds, char const *const *titles, bool const *enabled,
    char const *const *identifiers, char const *const *icons, bool const *destructive, int32_t const *keys,
    int32_t const *modifiers, bool const *givesWay, int32_t count
) {
    try {
        auto bar = borrow<controls::MenuBar>(handle);
        bar.Items().Clear();
        Writer writer{view, bar, {}};
        for (int32_t index = 0; index < count; ++index) {
            writer.write(kinds[index], titles[index], enabled[index], identifiers[index], icons[index],
                         destructive[index], keys[index], modifiers[index], givesWay[index]);
        }
    } catch (...) {
        report("writing a menu bar");
    }
}

extern "C" int32_t stateui_winui_menus(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        auto element = as<xaml::UIElement>(handle);
        std::wstring text;
        if (auto bar = element.try_as<controls::MenuBar>()) {
            for (auto const &menu : bar.Items()) {
                if (!text.empty()) text += L";";
                text += (menu.IsEnabled() ? L"" : L"!") + std::wstring(menu.Title()) + L"[" + described(menu.Items()) + L"]";
            }
        } else if (auto flyout = offered(element)) {
            text = described(flyout.Items());
        }
        auto bytes = winrt::to_string(text);
        if (utf8 && capacity > 0) {
            auto size = std::min<size_t>(bytes.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, bytes.data(), size);
            utf8[size] = 0;
        }
        return static_cast<int32_t>(bytes.size());
    } catch (...) {
        report("reading a view's menus");
        return 0;
    }
}

extern "C" void stateui_winui_menus_choose(StateUIObjectRef handle, int32_t index) {
    try {
        for (auto const &entries : menus(as<xaml::UIElement>(handle))) {
            if (auto chosen = item(entries, index)) {
                // A checked item's peer offers toggling, as assistive technology chooses it, and no invoking.
                if (auto invoke = pattern<provider::IInvokeProvider>(chosen, PatternInterface::Invoke)) invoke.Invoke();
                else pattern<provider::IToggleProvider>(chosen, PatternInterface::Toggle).Toggle();
                return;
            }
        }
    } catch (...) {
        report("choosing in a view's menus");
    }
}

extern "C" int32_t stateui_winui_menus_items(StateUIObjectRef handle, char const *what, char *utf8, int32_t capacity) {
    try {
        std::string_view asked(what ? what : "");
        std::wstring text;
        bool first = true;
        std::function<void(Entries const &)> each = [&](Entries const &entries) {
            for (auto const &entry : entries) {
                if (auto sub = entry.try_as<controls::MenuFlyoutSubItem>()) {
                    each(sub.Items());
                } else if (auto item = entry.try_as<controls::MenuFlyoutItem>()) {
                    if (!first) text += L";";
                    first = false;
                    if (asked == "identifier")
                        text += std::wstring(xaml::Automation::AutomationProperties::GetAutomationId(item));
                    else if (asked == "icon") text += iconFile(item.Icon());
                    else if (asked == "destructive")
                        text += isDestructive(item, L"MenuFlyoutItemForeground") ? L"1" : L"0";
                    else if (asked == "checked") {
                        auto toggle = item.try_as<controls::ToggleMenuFlyoutItem>();
                        text += toggle && toggle.IsChecked() ? L"1" : L"0";
                    } else if (asked == "shortcut" && item.KeyboardAccelerators().Size() > 0) {
                        auto held = item.KeyboardAccelerators().GetAt(0);
                        text += std::to_wstring(static_cast<int32_t>(held.Key())) + L","
                            + std::to_wstring(static_cast<int32_t>(held.Modifiers()));
                    }
                }
            }
        };
        for (auto const &entries : menus(as<xaml::UIElement>(handle))) each(entries);
        auto bytes = winrt::to_string(text);
        if (utf8 && capacity > 0) {
            auto size = std::min<size_t>(bytes.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, bytes.data(), size);
            utf8[size] = 0;
        }
        return static_cast<int32_t>(bytes.size());
    } catch (...) {
        report("reading a view's menus' items");
        return 0;
    }
}
