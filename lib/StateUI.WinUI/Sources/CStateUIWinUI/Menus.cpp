// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Menus: a view's context menu - WinUI's MenuFlyout on the element, opened by
// a right click, the menu key, a long press - and a window's menu bar, WinUI's
// MenuBar. Both are written from the same flat entries - items, separators
// and submenus - each item's choice told through `menuChosen` by its place
// among the items.
// Design: docs/design/platforms/winui/pages.md#menus

#include "Automation.h"

#include <algorithm>
#include <cstring>
#include <string>
#include <vector>

using namespace stateui;
using Entries = winrt::Windows::Foundation::Collections::IVector<controls::MenuFlyoutItemBase>;

namespace {
    /// Writes a menu's flat entries into the lists they belong to: an item (0), a separator (1), a submenu opening
    /// (2) and closing (3). On a bar, a menu at the top is one of the bar's own.
    struct Writer {
        int64_t view;
        controls::MenuBar bar{nullptr};
        std::vector<Entries> levels;
        int32_t chosen = 0;

        void write(int32_t kind, char const *title, bool enabled) {
            if (kind == 3) {
                if (levels.size() > (bar ? 0u : 1u)) levels.pop_back();
                return;
            }
            if (bar && levels.empty()) {
                if (kind != 2) return;
                controls::MenuBarItem menu;
                menu.Title(text(title));
                menu.IsEnabled(enabled);
                bar.Items().Append(menu);
                levels.push_back(menu.Items());
                return;
            }
            switch (kind) {
            case 0: {
                controls::MenuFlyoutItem item;
                item.Text(text(title));
                item.IsEnabled(enabled);
                item.Click([view = view, place = chosen++](IInspectable const &, xaml::RoutedEventArgs const &) {
                    callbacks.menuChosen(view, place);
                });
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

    /// The entries of each menu an element offers: its context menu's, or each of a bar's menus.
    std::vector<Entries> menus(xaml::UIElement const &element) {
        std::vector<Entries> found;
        if (auto bar = element.try_as<controls::MenuBar>()) {
            for (auto const &menu : bar.Items()) found.push_back(menu.Items());
        } else if (auto flyout = element.ContextFlyout().try_as<controls::MenuFlyout>()) {
            found.push_back(flyout.Items());
        }
        return found;
    }
}

extern "C" void stateui_winui_set_context_menu(
    StateUIObjectRef handle, int64_t view, int32_t const *kinds, char const *const *titles, bool const *enabled,
    int32_t count
) {
    try {
        auto element = as<xaml::UIElement>(handle);
        if (count == 0) {
            element.ContextFlyout(nullptr);
        } else {
            controls::MenuFlyout flyout;
            Writer writer{view, nullptr, {flyout.Items()}};
            for (int32_t index = 0; index < count; ++index) writer.write(kinds[index], titles[index], enabled[index]);
            element.ContextFlyout(flyout);
        }
        holdHitArea(element, view);
    } catch (winrt::hresult_error const &error) {
        report(error, "giving a view its context menu");
    }
}

extern "C" StateUIObjectRef stateui_winui_menu_bar_make(int64_t) {
    try {
        return detach(controls::MenuBar());
    } catch (winrt::hresult_error const &error) {
        report(error, "making a menu bar");
        return nullptr;
    }
}

extern "C" void stateui_winui_menu_bar_set(
    StateUIObjectRef handle, int64_t view, int32_t const *kinds, char const *const *titles, bool const *enabled,
    int32_t count
) {
    try {
        auto bar = borrow<controls::MenuBar>(handle);
        bar.Items().Clear();
        Writer writer{view, bar, {}};
        for (int32_t index = 0; index < count; ++index) writer.write(kinds[index], titles[index], enabled[index]);
    } catch (winrt::hresult_error const &error) {
        report(error, "writing a menu bar");
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
        } else if (auto flyout = element.ContextFlyout().try_as<controls::MenuFlyout>()) {
            text = described(flyout.Items());
        }
        auto bytes = winrt::to_string(text);
        if (utf8 && capacity > 0) {
            auto size = std::min<size_t>(bytes.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, bytes.data(), size);
            utf8[size] = 0;
        }
        return static_cast<int32_t>(bytes.size());
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a view's menus");
        return 0;
    }
}

extern "C" void stateui_winui_menus_choose(StateUIObjectRef handle, int32_t index) {
    try {
        for (auto const &entries : menus(as<xaml::UIElement>(handle))) {
            if (auto chosen = item(entries, index)) {
                pattern<provider::IInvokeProvider>(chosen, PatternInterface::Invoke).Invoke();
                return;
            }
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "choosing in a view's menus");
    }
}
