// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The native parts of a window and its arrangements of pages: the window's
// chrome in WinUI's TitleBar, a split view's NavigationView, and a row of tabs.
// Each says what the user chose by the view's number and the entry's place.
// Design: docs/design/platforms/winui/pages.md

#include "Relay.h"

#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    winrt::Windows::UI::Color color(uint32_t argb) {
        return {static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8),
                static_cast<uint8_t>(argb)};
    }

    /// The title bar's right header: the page's actions, then the authored trailing content.
    controls::StackPanel rightHeader(controls::TitleBar const &bar) {
        return bar.RightHeader().as<controls::StackPanel>();
    }

    void fill(controls::ContentControl const &slot, StateUIObjectRef element) {
        auto shown = element ? as<xaml::UIElement>(element) : xaml::UIElement{nullptr};
        if (slot.Content() != shown) slot.Content(shown);
    }
}

extern "C" StateUIObjectRef stateui_winui_title_bar_make(int64_t view) {
    try {
        controls::TitleBar bar;
        bar.Tag(winrt::box_value(view));
        bar.BackRequested([view](controls::TitleBar const &, IInspectable const &) { callbacks.chosen(view, -1); });
        bar.PaneToggleRequested([view](controls::TitleBar const &, IInspectable const &) { callbacks.chosen(view, -2); });
        bar.LeftHeader(controls::ContentControl());
        bar.Content(controls::ContentControl());

        controls::CommandBar actions;
        actions.DefaultLabelPosition(controls::CommandBarDefaultLabelPosition::Right);
        actions.Background(media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
        actions.VerticalAlignment(xaml::VerticalAlignment::Center);
        controls::StackPanel right;
        right.Orientation(controls::Orientation::Horizontal);
        right.Children().Append(actions);
        right.Children().Append(controls::ContentControl());
        bar.RightHeader(right);
        return detach(bar);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a title bar");
        return nullptr;
    }
}

extern "C" void stateui_winui_title_bar_set(
    StateUIObjectRef handle, char const *title, bool back, bool paneToggle, bool hasBackground, uint32_t background,
    bool hasForeground, uint32_t foreground
) {
    try {
        auto bar = borrow<controls::TitleBar>(handle);
        if (bar.Title() != text(title)) bar.Title(text(title));
        bar.IsBackButtonVisible(back);
        bar.IsPaneToggleButtonVisible(paneToggle);
        if (hasBackground) bar.Background(media::SolidColorBrush(color(background)));
        else bar.ClearValue(controls::Control::BackgroundProperty());
        if (hasForeground) bar.Foreground(media::SolidColorBrush(color(foreground)));
        else bar.ClearValue(controls::Control::ForegroundProperty());
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a title bar");
    }
}

extern "C" void stateui_winui_title_bar_set_actions(
    StateUIObjectRef handle, char const *const *texts, bool const *overflows, bool const *enabled, int32_t count
) {
    try {
        auto bar = borrow<controls::TitleBar>(handle);
        auto view = winrt::unbox_value<int64_t>(bar.Tag());
        auto actions = rightHeader(bar).Children().GetAt(0).as<controls::CommandBar>();
        actions.PrimaryCommands().Clear();
        actions.SecondaryCommands().Clear();
        for (int32_t index = 0; index < count; ++index) {
            controls::AppBarButton button;
            button.Label(text(texts[index]));
            button.IsEnabled(enabled[index]);
            button.Click([view, index](IInspectable const &, xaml::RoutedEventArgs const &) {
                callbacks.chosen(view, index);
            });
            (overflows[index] ? actions.SecondaryCommands() : actions.PrimaryCommands()).Append(button);
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a title bar's actions");
    }
}

extern "C" void stateui_winui_title_bar_set_slots(
    StateUIObjectRef handle, StateUIObjectRef leading, StateUIObjectRef center, StateUIObjectRef trailing
) {
    try {
        auto bar = borrow<controls::TitleBar>(handle);
        fill(bar.LeftHeader().as<controls::ContentControl>(), leading);
        fill(bar.Content().as<controls::ContentControl>(), center);
        fill(rightHeader(bar).Children().GetAt(1).as<controls::ContentControl>(), trailing);
    } catch (winrt::hresult_error const &error) {
        report(error, "filling a title bar");
    }
}

extern "C" StateUIObjectRef stateui_winui_split_make(int64_t view, double expandsAt) {
    try {
        controls::NavigationView split;
        split.PaneDisplayMode(controls::NavigationViewPaneDisplayMode::Auto);
        split.CompactModeThresholdWidth(expandsAt);
        split.ExpandedModeThresholdWidth(expandsAt);
        split.CompactPaneLength(0);
        split.IsSettingsVisible(false);
        split.IsBackButtonVisible(controls::NavigationViewBackButtonVisible::Collapsed);
        split.IsPaneToggleButtonVisible(false);
        split.IsTitleBarAutoPaddingEnabled(false);
        split.Content(rows({true, false}));
        split.PaneOpening([view](controls::NavigationView const &, IInspectable const &) { callbacks.presented(view, true); });
        split.PaneClosing([view](controls::NavigationView const &, controls::NavigationViewPaneClosingEventArgs const &) {
            callbacks.presented(view, false);
        });
        return detach(split);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a split view");
        return nullptr;
    }
}

extern "C" void stateui_winui_split_set(
    StateUIObjectRef handle, StateUIObjectRef pane, StateUIObjectRef content, StateUIObjectRef row, bool open,
    double paneWidth
) {
    try {
        auto split = borrow<controls::NavigationView>(handle);
        auto sidebar = pane ? as<xaml::UIElement>(pane) : xaml::UIElement{nullptr};
        if (split.PaneCustomContent() != sidebar) split.PaneCustomContent(sidebar);
        auto detail = split.Content().as<controls::Grid>();
        standInRow(detail, 0, row);
        standInRow(detail, 1, content);
        split.OpenPaneLength(paneWidth);
        if (split.IsPaneOpen() != open) split.IsPaneOpen(open);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a split view");
    }
}

extern "C" StateUIObjectRef stateui_winui_tabs_make(int64_t view) {
    try {
        controls::SelectorBar tabs;
        tabs.SelectionChanged([view](controls::SelectorBar const &sender, controls::SelectorBarSelectionChangedEventArgs const &) {
            uint32_t index = 0;
            if (sender.SelectedItem() && sender.Items().IndexOf(sender.SelectedItem(), index)) {
                callbacks.chosen(view, static_cast<int32_t>(index));
            }
        });
        return detach(tabs);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a row of tabs");
        return nullptr;
    }
}

extern "C" void stateui_winui_tabs_set(StateUIObjectRef handle, char const *const *titles, int32_t count, int32_t selected) {
    try {
        auto tabs = borrow<controls::SelectorBar>(handle);
        auto items = tabs.Items();
        while (static_cast<int32_t>(items.Size()) > count) items.RemoveAtEnd();
        for (int32_t index = 0; index < count; ++index) {
            if (index >= static_cast<int32_t>(items.Size())) items.Append(controls::SelectorBarItem());
            auto item = items.GetAt(index);
            if (item.Text() != text(titles[index])) item.Text(text(titles[index]));
        }
        if (selected >= 0 && selected < count && tabs.SelectedItem() != items.GetAt(selected)) {
            tabs.SelectedItem(items.GetAt(selected));
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a row of tabs");
    }
}
