// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The native parts of a window and its arrangements of pages: the window's
// chrome in WinUI's TitleBar, a split view's NavigationView, and a row of tabs.
// Each says what the user chose by the view's number and the entry's place.
// Design: docs/design/platforms/winui/pages.md

#include "Relay.h"

#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Content.h>
#include <winrt/Microsoft.UI.Windowing.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    /// The columns WinUI's TitleBar keeps at its edges for the window's own buttons, and the room those take in
    /// DIPs; null columns where the bar stands in no window yet.
    struct CaptionRoom {
        controls::ColumnDefinition leading{nullptr};
        controls::ColumnDefinition trailing{nullptr};
        double leadingRoom = 0;
        double trailingRoom = 0;
    };

    CaptionRoom captionRoom(controls::TitleBar const &bar) {
        CaptionRoom found;
        auto root = bar.XamlRoot();
        auto grid = first<controls::Grid>(bar);
        if (!root || !grid) return found;
        auto window = winrt::Microsoft::UI::Windowing::AppWindow::GetFromWindowId(
            root.ContentIslandEnvironment().AppWindowId());
        if (!window) return found;
        auto column = [&](wchar_t const *name) {
            auto named = grid.FindName(name);
            return named ? named.try_as<controls::ColumnDefinition>() : nullptr;
        };
        found.leading = column(L"LeftPaddingColumn");
        found.trailing = column(L"RightPaddingColumn");
        auto scale = root.RasterizationScale();
        found.leadingRoom = window.TitleBar().LeftInset() / scale;
        found.trailingRoom = window.TitleBar().RightInset() / scale;
        return found;
    }

    /// Caps the room the bar keeps for the window's own buttons at theirs: WinUI keeps it in pixels, unscaled
    /// (microsoft-ui-xaml #10344), and a cap leaves a room WinUI keeps right as it is.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    void capCaptionRoom(controls::TitleBar const &bar) {
        auto found = captionRoom(bar);
        if (found.leading) found.leading.MaxWidth(found.leadingRoom);
        if (found.trailing) found.trailing.MaxWidth(found.trailingRoom);
    }

    /// Whether the program is setting a row of tabs: a selection it makes - a tab chosen, or the row's own after
    /// the chosen tab is taken away - is heard by nobody.
    bool settingTabs = false;

    winrt::Windows::UI::Color color(uint32_t argb) {
        return {static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8),
                static_cast<uint8_t>(argb)};
    }

    /// The title bar's right header: the page's actions, then the authored trailing content.
    controls::StackPanel rightHeader(controls::TitleBar const &bar) {
        return bar.RightHeader().as<controls::StackPanel>();
    }

    /// The actions on the bar stand in its words' colour where the tree gives one, "more" among them; a destructive
    /// one keeps the theme's critical colour, and one behind "more" the menu's colours, on the menu's own background.
    void paintActions(controls::TitleBar const &bar) {
        auto actions = rightHeader(bar).Children().GetAt(0).as<controls::CommandBar>();
        bool given = bar.ReadLocalValue(controls::Control::ForegroundProperty()) != xaml::DependencyProperty::UnsetValue();
        auto paint = [&](controls::Control const &control) {
            if (given) control.Foreground(bar.Foreground());
            else control.ClearValue(controls::Control::ForegroundProperty());
        };
        paint(actions);
        for (auto const &command : actions.PrimaryCommands())
            if (auto button = command.try_as<controls::AppBarButton>();
                button && !isDestructive(button, L"AppBarButtonForeground"))
                paint(button);
    }

    /// A place on the bar an authored view stands in: no stop of Tab's itself, as the view in it may be.
    controls::ContentControl slot() {
        controls::ContentControl slot;
        slot.IsTabStop(false);
        return slot;
    }

    void fill(controls::ContentControl const &slot, StateUIObjectRef element) {
        auto shown = element ? as<xaml::UIElement>(element) : xaml::UIElement{nullptr};
        if (slot.Content() != shown) slot.Content(shown);
    }

    /// Shows the sidebar in the split's pane, or collapses it: a closed pane stands beside the detail at no width,
    /// where the keyboard and Narrator would still reach what it holds.
    /// Design: docs/design/platforms/winui/pages.md#a-split-view
    void showSidebar(controls::NavigationView const &split, bool shown) {
        auto sidebar = split.PaneCustomContent();
        auto visibility = shown ? xaml::Visibility::Visible : xaml::Visibility::Collapsed;
        if (sidebar && sidebar.Visibility() != visibility) sidebar.Visibility(visibility);
    }

    /// Asks WinUI to measure `element` and everything in it again.
    void measureAgain(xaml::DependencyObject const &element) {
        if (auto each = element.try_as<xaml::UIElement>()) each.InvalidateMeasure();
        for (int32_t index = 0, count = xaml::Media::VisualTreeHelper::GetChildrenCount(element); index < count; ++index)
            measureAgain(xaml::Media::VisualTreeHelper::GetChild(element, index));
    }
}

extern "C" StateUIObjectRef stateui_winui_title_bar_make(int64_t view) {
    try {
        controls::TitleBar bar;
        bar.Tag(winrt::box_value(view));
        bar.BackRequested([view](controls::TitleBar const &, IInspectable const &) { callbacks.chosen(view, -1); });
        bar.PaneToggleRequested([view](controls::TitleBar const &, IInspectable const &) { callbacks.chosen(view, -2); });
        bar.LeftHeader(slot());
        bar.Content(slot());
        bar.Loaded([](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            capCaptionRoom(sender.as<controls::TitleBar>());
        });
        bar.SizeChanged([](IInspectable const &sender, xaml::SizeChangedEventArgs const &) {
            capCaptionRoom(sender.as<controls::TitleBar>());
        });

        controls::CommandBar actions;
        actions.DefaultLabelPosition(controls::CommandBarDefaultLabelPosition::Right);
        actions.Background(media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
        actions.VerticalAlignment(xaml::VerticalAlignment::Center);
        controls::StackPanel right;
        right.Orientation(controls::Orientation::Horizontal);
        right.Children().Append(actions);
        right.Children().Append(slot());
        bar.RightHeader(right);
        return detach(bar);
    } catch (...) {
        report("making a title bar");
        return nullptr;
    }
}

extern "C" void stateui_winui_title_bar_set(
    StateUIObjectRef handle, char const *title, bool back, bool paneToggle, bool hasBackground, uint32_t background,
    bool hasForeground, uint32_t foreground, int32_t words
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
        auto theme = words == 1 ? xaml::ElementTheme::Dark
            : words == 2 ? xaml::ElementTheme::Light : xaml::ElementTheme::Default;
        if (bar.RequestedTheme() != theme) bar.RequestedTheme(theme);
        paintActions(bar);
    } catch (...) {
        report("setting a title bar");
    }
}

extern "C" void stateui_winui_title_bar_caption_room(StateUIObjectRef handle, double *kept, double *room) {
    try {
        auto found = captionRoom(borrow<controls::TitleBar>(handle));
        *kept = found.trailing ? found.trailing.ActualWidth() : -1;
        *room = found.trailingRoom;
    } catch (...) {
        report("reading the room a title bar keeps");
    }
}

extern "C" int32_t stateui_winui_title_bar_words(StateUIObjectRef handle) {
    try {
        switch (borrow<controls::TitleBar>(handle).RequestedTheme()) {
        case xaml::ElementTheme::Dark: return 1;
        case xaml::ElementTheme::Light: return 2;
        default: return 0;
        }
    } catch (...) {
        report("reading a title bar's words");
        return 0;
    }
}

extern "C" void stateui_winui_title_bar_set_actions(
    StateUIObjectRef handle, char const *const *texts, char const *const *identifiers, char const *const *icons,
    bool const *destructive, bool const *overflows, bool const *enabled, int32_t count
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
            if (identifiers[index] && *identifiers[index]) {
                xaml::Automation::AutomationProperties::SetAutomationId(button, text(identifiers[index]));
            }
            // An action with a picture shows the picture alone; its words name it to Narrator and in its tip.
            if (auto icon = pictureIcon(icons[index])) {
                button.Icon(icon);
                button.LabelPosition(controls::CommandBarLabelPosition::Collapsed);
                controls::ToolTipService::SetToolTip(button, winrt::box_value(text(texts[index])));
            }
            if (destructive[index])
                markDestructive(button, {L"AppBarButtonForeground", L"AppBarButtonForegroundPointerOver",
                                         L"AppBarButtonForegroundPressed"});
            button.Click([view, index](IInspectable const &, xaml::RoutedEventArgs const &) {
                callbacks.chosen(view, index);
            });
            (overflows[index] ? actions.SecondaryCommands() : actions.PrimaryCommands()).Append(button);
        }
        paintActions(bar);
    } catch (...) {
        report("setting a title bar's actions");
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
    } catch (...) {
        report("filling a title bar");
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
        // The pane's own content stands in a row sized to what it holds, so a sidebar's scroller would never scroll.
        // Design: docs/design/platforms/winui/pages.md#a-split-view
        split.Loaded([](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            auto split = sender.as<controls::NavigationView>();
            auto sidebar = first<controls::ContentControl>(split, L"PaneCustomContentBorder");
            auto items = first<controls::Grid>(split, L"ItemsContainerGrid");
            auto pane = sidebar ? xaml::Media::VisualTreeHelper::GetParent(sidebar).try_as<controls::Grid>() : nullptr;
            if (!pane || !items) return;
            auto rows = pane.RowDefinitions();
            rows.GetAt(controls::Grid::GetRow(sidebar)).Height(xaml::GridLengthHelper::FromValueAndType(1, xaml::GridUnitType::Star));
            rows.GetAt(controls::Grid::GetRow(items)).Height(xaml::GridLengthHelper::Auto());
            // Laid out once already, in the row sized to what it holds: measured again, it takes the pane's height.
            measureAgain(sidebar);
        });
        split.PaneOpening([view](controls::NavigationView const &sender, IInspectable const &) {
            showSidebar(sender, true);
            callbacks.presented(view, true);
        });
        split.PaneClosing([view](controls::NavigationView const &, controls::NavigationViewPaneClosingEventArgs const &) {
            callbacks.presented(view, false);
        });
        split.PaneClosed([](controls::NavigationView const &sender, IInspectable const &) {
            if (!sender.IsPaneOpen()) showSidebar(sender, false);
        });
        split.DisplayModeChanged([](controls::NavigationView const &sender, IInspectable const &) {
            if (!sender.IsPaneOpen()) showSidebar(sender, false);
        });
        return detach(split);
    } catch (...) {
        report("making a split view");
        return nullptr;
    }
}

extern "C" void stateui_winui_split_set(
    StateUIObjectRef handle, StateUIObjectRef pane, StateUIObjectRef content, StateUIObjectRef row, bool open
) {
    try {
        auto split = borrow<controls::NavigationView>(handle);
        auto sidebar = pane ? as<xaml::UIElement>(pane) : xaml::UIElement{nullptr};
        bool anew = split.PaneCustomContent() != sidebar;
        if (anew) split.PaneCustomContent(sidebar);
        auto detail = split.Content().as<controls::Grid>();
        standInRow(detail, 0, row);
        standInRow(detail, 1, content);
        // A pane over the detail collapses its sidebar once it has closed; one beside it tells no closing, and a
        // view WinUI has not loaded, or a new sidebar, tells nothing.
        bool beside = split.DisplayMode() == controls::NavigationViewDisplayMode::Expanded;
        if (open || anew || beside || !split.IsLoaded()) showSidebar(split, open);
        if (split.IsPaneOpen() != open) split.IsPaneOpen(open);
    } catch (...) {
        report("setting a split view");
    }
}

extern "C" StateUIObjectRef stateui_winui_tabs_make(int64_t view) {
    try {
        controls::SelectorBar tabs;
        tabs.SelectionChanged([view](controls::SelectorBar const &sender, controls::SelectorBarSelectionChangedEventArgs const &) {
            if (settingTabs) return;
            uint32_t index = 0;
            if (sender.SelectedItem() && sender.Items().IndexOf(sender.SelectedItem(), index)) {
                callbacks.chosen(view, static_cast<int32_t>(index));
            }
        });
        return detach(tabs);
    } catch (...) {
        report("making a row of tabs");
        return nullptr;
    }
}

extern "C" void stateui_winui_tabs_choose_as_user(StateUIObjectRef handle, int32_t index) {
    try {
        // The row's own selection, which the user's click makes and SelectionChanged tells.
        auto tabs = borrow<controls::SelectorBar>(handle);
        if (index >= 0 && index < static_cast<int32_t>(tabs.Items().Size())) tabs.SelectedItem(tabs.Items().GetAt(index));
    } catch (...) {
        report("choosing a tab as the user");
    }
}

extern "C" void stateui_winui_tabs_set(StateUIObjectRef handle, char const *const *titles, int32_t count, int32_t selected) {
    struct Setting {
        Setting() { settingTabs = true; }
        ~Setting() { settingTabs = false; }
    } setting;
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
    } catch (...) {
        report("setting a row of tabs");
    }
}
