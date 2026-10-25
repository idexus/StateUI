// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The pages a window presents over everything, as WinUI presents a dialog:
// each on a card over a veil across the whole window, the last on top and
// the page beneath out of reach, entering as a dialog enters.
// Design: docs/design/platforms/winui/pages.md#sheets

#include "Relay.h"

#include <limits>
#include <vector>

#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    /// The application's theme resource of that name, searched through the dictionaries it merges and their themes;
    /// null where there is none.
    IInspectable resource(wchar_t const *name) {
        return xaml::Application::Current().Resources().TryLookup(winrt::box_value(name));
    }

    /// The layer over the window's rows that holds its sheets, made the first time one is asked for.
    controls::Grid layer(xaml::Window const &window, bool make) {
        auto root = window.Content().as<controls::Grid>();
        for (auto const &child : root.Children())
            if (auto grid = child.try_as<controls::Grid>(); grid && winrt::unbox_value_or<winrt::hstring>(grid.Tag(), L"") == L"sheets")
                return grid;
        if (!make) return nullptr;

        controls::Grid sheets;
        sheets.Tag(winrt::box_value(L"sheets"));
        controls::Grid::SetRowSpan(sheets, 4);
        // Over every row by its own depth, not by its place among the root's children: a page stood in a row since
        // goes on the end, and stood over a sheet.
        controls::Canvas::SetZIndex(sheets, 1);
        media::Animation::TransitionCollection transitions;
        transitions.Append(media::Animation::PopupThemeTransition());
        sheets.ChildrenTransitions(transitions);
        root.Children().Append(sheets);
        return sheets;
    }

    /// A sheet's head: the row over its page holding the bar a stack in it brings.
    controls::Grid headOf(controls::Grid const &sheet) {
        auto card = sheet.Children().GetAt(1).as<controls::Border>();
        return card.Child().as<controls::Grid>().Children().GetAt(0).as<controls::Grid>();
    }

    /// Shows the head where it holds anything - the way back, a title, the close button or an action - else leaves
    /// the page the whole card.
    void showHead(controls::Grid const &head) {
        auto shows = [&](uint32_t part) { return head.Children().GetAt(part).Visibility() == xaml::Visibility::Visible; };
        auto edges = ActionEdges{head.Children().GetAt(3).as<controls::CommandBar>(),
                                 head.Children().GetAt(4).as<controls::CommandBar>()};
        bool holds = shows(0) || shows(2) || !head.Children().GetAt(1).as<controls::TextBlock>().Text().empty()
                     || edges.leading.PrimaryCommands().Size() > 0 || edges.trailing.PrimaryCommands().Size() > 0
                     || edges.trailing.SecondaryCommands().Size() > 0;
        head.Visibility(holds ? xaml::Visibility::Visible : xaml::Visibility::Collapsed);
    }
}

ActionEdges stateui::sheetActionEdges(controls::Grid const &sheet) {
    auto head = headOf(sheet);
    return {head.Children().GetAt(3).as<controls::CommandBar>(), head.Children().GetAt(4).as<controls::CommandBar>()};
}

extern "C" StateUIObjectRef stateui_winui_sheet_make(int64_t view) {
    try {
        // The veil: across the window, so nothing beneath it takes a click.
        controls::Grid sheet;
        sheet.Tag(winrt::box_value(L"sheet"));
        winrt::Microsoft::UI::Xaml::Shapes::Rectangle veil;
        veil.Fill(resource(L"SmokeFillColorDefaultBrush").try_as<media::Brush>());
        sheet.Children().Append(veil);

        // The card: a dialog's own background, outline and corners, no wider than a dialog, clear of the edges.
        controls::Border card;
        card.Background(resource(L"ContentDialogBackground").try_as<media::Brush>());
        card.BorderBrush(resource(L"ContentDialogBorderBrush").try_as<media::Brush>());
        card.BorderThickness(winrt::unbox_value_or<xaml::Thickness>(resource(L"ContentDialogBorderWidth"), {1, 1, 1, 1}));
        card.CornerRadius(winrt::unbox_value_or<xaml::CornerRadius>(resource(L"OverlayCornerRadius"), {8, 8, 8, 8}));
        card.Margin({48, 48, 48, 48});
        card.TabFocusNavigation(xaml::Input::KeyboardNavigationMode::Cycle);

        // The head of the bar a stack in the sheet brings: its way back, the page's actions at the leading edge, its
        // title, those at the trailing edge with "more", and the close button last.
        auto content = rows({true, false});
        controls::Grid head;
        head.Tag(winrt::box_value(view));
        auto star = xaml::GridLengthHelper::FromValueAndType(1, xaml::GridUnitType::Star);
        auto fitting = xaml::GridLengthHelper::Auto();
        for (auto width : {fitting, fitting, star, fitting, fitting}) {
            controls::ColumnDefinition column;
            column.Width(width);
            head.ColumnDefinitions().Append(column);
        }
        head.Padding({12, 12, 12, 0});
        // A band painted on the head keeps the card's top corners, inside its outline.
        auto corner = card.CornerRadius().TopLeft - card.BorderThickness().Top;
        head.CornerRadius({corner, corner, 0, 0});
        controls::Button back;
        if (auto style = resource(L"NavigationBackButtonSmallStyle").try_as<xaml::Style>()) back.Style(style);
        back.Click(guarded("handling a sheet's way back",
            [view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.chosen(view, -1); }));
        controls::TextBlock title;
        if (auto style = resource(L"SubtitleTextBlockStyle").try_as<xaml::Style>()) title.Style(style);
        title.Margin({12, 8, 12, 8});
        title.VerticalAlignment(xaml::VerticalAlignment::Center);
        title.TextTrimming(xaml::TextTrimming::CharacterEllipsis);
        controls::Grid::SetColumn(title, 2);
        controls::AppBarButton close;
        close.Icon(controls::SymbolIcon(controls::Symbol::Cancel));
        close.LabelPosition(controls::CommandBarLabelPosition::Collapsed);
        close.Click(guarded("handling a sheet's close button",
            [view](IInspectable const &, xaml::RoutedEventArgs const &) { callbacks.chosen(view, -2); }));
        controls::Grid::SetColumn(close, 4);
        auto leading = actionBar(), trailing = actionBar();
        leading.Visibility(xaml::Visibility::Collapsed);
        controls::Grid::SetColumn(leading, 1);
        controls::Grid::SetColumn(trailing, 3);
        for (xaml::UIElement part : {back.as<xaml::UIElement>(), title.as<xaml::UIElement>(), close.as<xaml::UIElement>(),
                                     leading.as<xaml::UIElement>(), trailing.as<xaml::UIElement>()})
            head.Children().Append(part);
        content.Children().Append(head);
        card.Child(content);
        sheet.Children().Append(card);
        return detach(sheet);
    } catch (...) {
        report("making a sheet");
        return nullptr;
    }
}

extern "C" void stateui_winui_sheet_set(
    StateUIObjectRef handle, char const *title, StateUIObjectRef page, bool back, bool close, char const *backWords,
    char const *closeWords, bool fits, double const *room
) {
    try {
        auto card = borrow<controls::Grid>(handle).Children().GetAt(1).as<controls::Border>();
        // As large as its page, in the middle; else stretched to the standard size, which the window's room holds.
        card.MinWidth(room[0]);
        card.MinHeight(room[1]);
        card.MaxWidth(room[2]);
        card.MaxHeight(fits ? std::numeric_limits<double>::infinity() : room[3]);
        card.HorizontalAlignment(fits ? xaml::HorizontalAlignment::Center : xaml::HorizontalAlignment::Stretch);
        card.VerticalAlignment(fits ? xaml::VerticalAlignment::Center : xaml::VerticalAlignment::Stretch);
        auto content = card.Child().as<controls::Grid>();
        auto head = content.Children().GetAt(0).as<controls::Grid>();
        auto shown = [](bool shows) { return shows ? xaml::Visibility::Visible : xaml::Visibility::Collapsed; };
        auto way = head.Children().GetAt(0).as<controls::Button>();
        way.Visibility(shown(back));
        xaml::Automation::AutomationProperties::SetName(way, text(backWords));
        head.Children().GetAt(1).as<controls::TextBlock>().Text(text(title));
        auto closing = head.Children().GetAt(2).as<controls::AppBarButton>();
        closing.Visibility(shown(close));
        closing.Label(text(closeWords));
        controls::ToolTipService::SetToolTip(closing, winrt::box_value(text(closeWords)));
        showHead(head);
        standInRow(content, 1, page);
    } catch (...) {
        report("filling a sheet");
    }
}

extern "C" void stateui_winui_sheet_set_actions(
    StateUIObjectRef handle, char const *const *texts, char const *const *identifiers, char const *const *icons,
    bool const *words, bool const *destructive, int32_t const *groups, int32_t leadingGroups, bool const *enabled,
    int32_t const *keys, int32_t const *modifiers, bool const *givesWay, int32_t const *states, int32_t count
) {
    try {
        auto sheet = borrow<controls::Grid>(handle);
        auto head = headOf(sheet);
        setActions(sheetActionEdges(sheet), head, winrt::unbox_value<int64_t>(head.Tag()), texts, identifiers, icons,
                   words, destructive, groups, leadingGroups, enabled, keys, modifiers, givesWay, states, count);
        showHead(head);
    } catch (...) {
        report("setting a sheet's actions");
    }
}

extern "C" void stateui_winui_sheet_set_action_menu(
    StateUIObjectRef handle, int32_t place, bool held, int32_t first, int32_t const *kinds, char const *const *titles,
    bool const *enabled, char const *const *identifiers, char const *const *icons, bool const *destructive,
    int32_t const *keys, int32_t const *modifiers, bool const *givesWay, int32_t count
) {
    try {
        auto sheet = borrow<controls::Grid>(handle);
        setActionMenu(sheetActionEdges(sheet), winrt::unbox_value<int64_t>(headOf(sheet).Tag()), place, held, first,
                      kinds, titles, enabled, identifiers, icons, destructive, keys, modifiers, givesWay, count);
    } catch (...) {
        report("giving a sheet's action its menu");
    }
}

extern "C" void stateui_winui_sheet_set_bar(
    StateUIObjectRef handle, bool hasBackground, uint32_t background, bool hasForeground, uint32_t foreground,
    int32_t theme
) {
    try {
        // The head is the bar's band across the card's top, the title, the buttons and the actions on it in the
        // bar's words' color, and in the theme its band asks for.
        auto sheet = borrow<controls::Grid>(handle);
        auto head = headOf(sheet);
        if (hasBackground) head.Background(media::SolidColorBrush(color(background)));
        else head.ClearValue(controls::Panel::BackgroundProperty());
        auto words = hasForeground ? media::Brush(media::SolidColorBrush(color(foreground))) : media::Brush{nullptr};
        auto title = head.Children().GetAt(1).as<controls::TextBlock>();
        if (words) title.Foreground(words);
        else title.ClearValue(controls::TextBlock::ForegroundProperty());
        for (uint32_t part : {0u, 2u}) {
            auto button = head.Children().GetAt(part).as<controls::Control>();
            if (words) button.Foreground(words);
            else button.ClearValue(controls::Control::ForegroundProperty());
        }
        paintActions(sheetActionEdges(sheet), words);
        if (head.RequestedTheme() != elementTheme(theme)) head.RequestedTheme(elementTheme(theme));
    } catch (...) {
        report("painting a sheet's bar");
    }
}

extern "C" void stateui_winui_sheet_set_ground(
    StateUIObjectRef handle, StateUIGround kind, uint32_t argb, float opacity, float tintOpacity
) {
    try {
        // A color lies over the card's own background, inside its outline; an acrylic takes its place, showing what
        // the card covers.
        auto card = borrow<controls::Grid>(handle).Children().GetAt(1).as<controls::Border>();
        auto content = card.Child().as<controls::Grid>();
        auto brush = ground(kind, argb, opacity, tintOpacity);
        bool acrylic = kind == StateUIGroundAcrylic;
        card.Background(acrylic ? brush : resource(L"ContentDialogBackground").try_as<media::Brush>());
        content.Background(acrylic ? nullptr : brush);
        auto corner = card.CornerRadius();
        auto edge = card.BorderThickness();
        content.CornerRadius({corner.TopLeft - edge.Left, corner.TopRight - edge.Right,
                              corner.BottomRight - edge.Right, corner.BottomLeft - edge.Left});
    } catch (...) {
        report("standing a sheet on its ground");
    }
}

extern "C" void stateui_winui_window_push_sheet(StateUIObjectRef handle, StateUIObjectRef sheet) {
    try {
        auto held = layer(borrow<xaml::Window>(handle), true);
        auto shown = as<xaml::UIElement>(sheet);
        held.Children().Append(shown);
        held.Visibility(xaml::Visibility::Visible);
        // The sheet takes the keyboard: its first place that does.
        auto card = shown.as<controls::Grid>().Children().GetAt(1);
        if (auto first = xaml::Input::FocusManager::FindFirstFocusableElement(card))
            if (auto focusable = first.try_as<xaml::UIElement>()) focusable.Focus(xaml::FocusState::Programmatic);
    } catch (...) {
        report("presenting a sheet");
    }
}

extern "C" void stateui_winui_window_pop_sheet(StateUIObjectRef handle) {
    try {
        auto held = layer(borrow<xaml::Window>(handle), false);
        if (!held || held.Children().Size() == 0) return;
        held.Children().RemoveAtEnd();
        if (held.Children().Size() == 0) held.Visibility(xaml::Visibility::Collapsed);
    } catch (...) {
        report("taking a sheet away");
    }
}

extern "C" int32_t stateui_winui_window_sheets(StateUIObjectRef handle) {
    try {
        auto held = layer(borrow<xaml::Window>(handle), false);
        return held ? static_cast<int32_t>(held.Children().Size()) : 0;
    } catch (...) {
        report("counting sheets");
        return 0;
    }
}
