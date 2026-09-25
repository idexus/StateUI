// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view's context menu: WinUI's MenuFlyout on the element - a right click,
// the menu key, a long press - its items, separators and submenus, each
// item's choice told through `menuChosen` by its place among the items.
// Design: docs/design/platforms/winui/pages.md#menus

#include "Automation.h"

#include <algorithm>
#include <cstring>
#include <string>
#include <vector>

using namespace stateui;
using Entries = winrt::Windows::Foundation::Collections::IVector<controls::MenuFlyoutItemBase>;

namespace {
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

    /// The item at `index` among the menu's items, submenus' included, in the order they stand; null past the last.
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
}

extern "C" void stateui_winui_set_context_menu(
    StateUIObjectRef handle, int64_t view, int32_t const *kinds, char const *const *titles, bool const *enabled,
    int32_t count
) {
    try {
        auto element = as<xaml::UIElement>(handle);
        if (count == 0) {
            element.ContextFlyout(nullptr);
            holdHitArea(element, view);
            return;
        }

        controls::MenuFlyout flyout;
        std::vector<Entries> levels{flyout.Items()};
        int32_t chosen = 0;
        for (int32_t index = 0; index < count; ++index) {
            switch (kinds[index]) {
            case 0: {
                controls::MenuFlyoutItem item;
                item.Text(text(titles[index]));
                item.IsEnabled(enabled[index]);
                auto place = chosen++;
                item.Click([view, place](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.menuChosen(view, place); });
                levels.back().Append(item);
                break;
            }
            case 1:
                levels.back().Append(controls::MenuFlyoutSeparator());
                break;
            case 2: {
                controls::MenuFlyoutSubItem sub;
                sub.Text(text(titles[index]));
                sub.IsEnabled(enabled[index]);
                levels.back().Append(sub);
                levels.push_back(sub.Items());
                break;
            }
            default:
                if (levels.size() > 1) levels.pop_back();
            }
        }
        element.ContextFlyout(flyout);
        holdHitArea(element, view);
    } catch (winrt::hresult_error const &error) {
        report(error, "giving a view its context menu");
    }
}

extern "C" int32_t stateui_winui_context_menu(StateUIObjectRef handle, char *utf8, int32_t capacity) {
    try {
        auto flyout = as<xaml::UIElement>(handle).ContextFlyout().try_as<controls::MenuFlyout>();
        auto bytes = flyout ? winrt::to_string(described(flyout.Items())) : std::string();
        if (utf8 && capacity > 0) {
            auto size = std::min<size_t>(bytes.size(), static_cast<size_t>(capacity - 1));
            std::memcpy(utf8, bytes.data(), size);
            utf8[size] = 0;
        }
        return static_cast<int32_t>(bytes.size());
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a view's context menu");
        return 0;
    }
}

extern "C" void stateui_winui_context_menu_choose(StateUIObjectRef handle, int32_t index) {
    try {
        auto flyout = as<xaml::UIElement>(handle).ContextFlyout().try_as<controls::MenuFlyout>();
        if (auto chosen = flyout ? item(flyout.Items(), index) : nullptr) {
            pattern<provider::IInvokeProvider>(chosen, PatternInterface::Invoke).Invoke();
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "choosing in a view's context menu");
    }
}
