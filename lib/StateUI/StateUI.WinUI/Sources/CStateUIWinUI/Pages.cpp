// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The native parts of a window and its arrangements of pages: the window's
// chrome in WinUI's TitleBar, a split view's SplitView, and a row of tabs.
// Each says what the user chose by the view's number and the entry's place.
// Design: docs/design/platforms/winui/pages.md

#include "Relay.h"

#include <algorithm>

#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Content.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>

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

    /// The actions on the bar stand in its words' color where the tree gives one, "more" and the lines between
    /// groups among them; a destructive one keeps the theme's critical color, and one behind "more" the menu's
    /// colors, on the menu's own background.
    void paintActions(controls::TitleBar const &bar) {
        bool given = bar.ReadLocalValue(controls::Control::ForegroundProperty()) != xaml::DependencyProperty::UnsetValue();
        stateui::paintActions(actionEdges(bar), given ? bar.Foreground() : nullptr);
    }

    /// The place on the bar a title view stands in: no stop of Tab's itself, as the view in it may be.
    controls::ContentControl slot() {
        controls::ContentControl slot;
        slot.IsTabStop(false);
        slot.VerticalContentAlignment(xaml::VerticalAlignment::Center);
        return slot;
    }

    void fill(controls::ContentControl const &slot, StateUIObjectRef element) {
        auto shown = element ? as<xaml::UIElement>(element) : xaml::UIElement{nullptr};
        if (slot.Content() != shown) slot.Content(shown);
    }

    /// Shows the sidebar in the split's pane, or collapses it: a closed pane keeps what it holds, where the keyboard
    /// and Narrator would still reach it.
    /// Design: docs/design/platforms/winui/pages.md#a-split-view
    void showSidebar(controls::SplitView const &split, bool shown) {
        auto sidebar = split.Pane();
        auto visibility = shown ? xaml::Visibility::Visible : xaml::Visibility::Collapsed;
        if (sidebar && sidebar.Visibility() != visibility) sidebar.Visibility(visibility);
    }

    /// A split view's pane: a head over the sidebar page holding the actions of the sidebar's part of the bar, at its
    /// start and at its end with "more" - a press chosen on `view` by its place - as a Windows application's
    /// navigation pane holds its commands over what it lists.
    /// Design: docs/design/platforms/winui/pages.md#a-split-view
    controls::Grid paneColumn(int64_t view) {
        auto column = rows({true, false});
        controls::Grid head;
        head.Tag(winrt::box_value(view));
        auto star = xaml::GridLengthHelper::FromValueAndType(1, xaml::GridUnitType::Star);
        auto fitting = xaml::GridLengthHelper::Auto();
        for (auto width : {fitting, star, fitting}) {
            controls::ColumnDefinition each;
            each.Width(width);
            head.ColumnDefinitions().Append(each);
        }
        head.Padding({4, 4, 4, 0});
        head.Visibility(xaml::Visibility::Collapsed);
        auto leading = actionBar(), trailing = actionBar();
        leading.Visibility(xaml::Visibility::Collapsed);
        controls::Grid::SetColumn(trailing, 2);
        head.Children().Append(leading);
        head.Children().Append(trailing);
        column.Children().Append(head);
        return column;
    }

    /// The head over a split view's sidebar page.
    controls::Grid paneHead(controls::SplitView const &split) {
        return split.Pane().as<controls::Grid>().Children().GetAt(0).as<controls::Grid>();
    }

    /// The edges of a split view's pane's head.
    ActionEdges headEdges(controls::Grid const &head) {
        return {head.Children().GetAt(0).as<controls::CommandBar>(), head.Children().GetAt(1).as<controls::CommandBar>()};
    }

    /// Shows the pane's head where it holds an action, else leaves the sidebar page the whole pane.
    void showPaneHead(controls::Grid const &head) {
        auto edges = headEdges(head);
        bool holds = edges.leading.PrimaryCommands().Size() > 0 || edges.trailing.PrimaryCommands().Size() > 0
                     || edges.trailing.SecondaryCommands().Size() > 0;
        auto visibility = holds ? xaml::Visibility::Visible : xaml::Visibility::Collapsed;
        if (head.Visibility() != visibility) head.Visibility(visibility);
    }

    /// The card a split view's detail stands in: WinUI's own layer and its edge, as a Windows application's content
    /// stands beside its navigation pane, by the theme resources that card is named by - which a window writing its
    /// background clears (`stateui_winui_window_clear_detail`).
    controls::Border detailCard() {
        return xaml::Markup::XamlReader::Load(
            L"<Border xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\""
            L" Background=\"{ThemeResource NavigationViewContentBackground}\""
            L" BorderBrush=\"{ThemeResource NavigationViewContentGridBorderBrush}\"/>").as<controls::Border>();
    }

    /// The brush WinUI's theme names `name`, in the theme `element` stands in.
    media::Brush themeBrush(xaml::FrameworkElement const &element, wchar_t const *name) {
        auto theme = winrt::box_value(element.ActualTheme() == xaml::ElementTheme::Light ? L"Light" : L"Dark");
        auto resources = xaml::Application::Current().Resources();
        for (auto const &merged : resources.MergedDictionaries()) {
            auto themed = merged.ThemeDictionaries().TryLookup(theme).try_as<xaml::ResourceDictionary>();
            if (auto found = themed ? themed.TryLookup(winrt::box_value(name)) : nullptr) return found.try_as<media::Brush>();
        }
        return resources.TryLookup(winrt::box_value(name)).try_as<media::Brush>();
    }

    /// Asks WinUI to measure `element` and everything in it again.
    void measureAgain(xaml::DependencyObject const &element) {
        if (auto each = element.try_as<xaml::UIElement>()) each.InvalidateMeasure();
        for (int32_t index = 0, count = media::VisualTreeHelper::GetChildrenCount(element); index < count; ++index)
            measureAgain(media::VisualTreeHelper::GetChild(element, index));
    }

    /// How far the bar's theme fades a disabled action's words: its disabled brush's alpha over its own. WinUI fades
    /// a glyph with them; a picture of the application's own it leaves as drawn.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    double disabledShare(xaml::FrameworkElement const &owner) {
        auto alpha = [&](wchar_t const *name) {
            auto brush = themeBrush(owner, name).try_as<media::SolidColorBrush>();
            return brush ? brush.Color().A * brush.Opacity() : 255.0;
        };
        return std::clamp(alpha(L"AppBarButtonForegroundDisabled") / alpha(L"AppBarButtonForeground"), 0.0, 1.0);
    }

    /// Stands the split as its place says - the pane beside the detail, the card's edge along the top and the pane's
    /// side and its corner rounded where they meet, or over it, the edge along the top alone - and the pane on its
    /// ground for that place: the split's own, else WinUI's navigation pane's.
    /// Design: docs/design/platforms/winui/pages.md#a-split-view
    void stand(controls::SplitView const &split) {
        bool beside = split.DisplayMode() == controls::SplitViewDisplayMode::Inline;
        auto card = split.Content().as<controls::Border>();
        card.BorderThickness(beside ? xaml::Thickness{1, 1, 0, 0} : xaml::Thickness{0, 1, 0, 0});
        card.CornerRadius(beside ? xaml::CornerRadius{8, 0, 0, 0} : xaml::CornerRadius{0, 0, 0, 0});
        auto own = ownBrush(split.Resources(), beside ? L"StateUIPaneBeside" : L"StateUIPaneOver");
        split.PaneBackground(own ? own : themeBrush(split, beside ? L"NavigationViewExpandedPaneBackground"
                                                                    : L"NavigationViewDefaultPaneBackground"));
    }

    /// The width a bar's button showing its picture alone stands at: WinUI's compact command's
    /// (`MediaTransportControlsAppBarButtonWidth`).
    constexpr double compactWidth = 40;

    /// The size of a bar button's words: an `AppBarButton`'s label's, as its template draws it.
    constexpr double barWordsSize = 12;

    /// Stands a bar's button showing its picture alone at `compactWidth` on the bar; in the overflow's menu it spans
    /// the menu, its width the overflow's style's.
    /// Design: docs/design/platforms/winui/pages.md#a-bars-buttons
    template <typename Button>
    void standCompact(Button const &button) {
        auto stand = [](Button const &button) {
            if (button.IsInOverflow()) button.ClearValue(xaml::FrameworkElement::WidthProperty());
            else button.Width(compactWidth);
        };
        stand(button);
        button.RegisterPropertyChangedCallback(Button::IsInOverflowProperty(), guarded("standing a compact button",
            [stand](xaml::DependencyObject const &sender, xaml::DependencyProperty const &) {
                stand(sender.as<Button>());
            }));
    }

    /// The room between two groups on a bar: WinUI's separator drawing no line there, its room alone standing, and
    /// its line in the overflow's menu.
    /// Design: docs/design/platforms/winui/pages.md#a-bars-buttons
    controls::AppBarSeparator groupGap() {
        controls::AppBarSeparator gap;
        auto stand = [](controls::AppBarSeparator const &gap) {
            if (gap.IsInOverflow()) gap.ClearValue(controls::Control::ForegroundProperty());
            else gap.Foreground(media::SolidColorBrush(winrt::Windows::UI::Color{0, 0, 0, 0}));
        };
        stand(gap);
        gap.RegisterPropertyChangedCallback(controls::AppBarSeparator::IsInOverflowProperty(),
            guarded("standing a group's room", [stand](xaml::DependencyObject const &sender, xaml::DependencyProperty const &) {
                stand(sender.as<controls::AppBarSeparator>());
            }));
        return gap;
    }

    /// Rests a split or drop-down button on a bar as the bar's own buttons rest: no fill and no border, the theme's
    /// subtle fills under the pointer and pressed - a split's two parts told apart by those fills alone.
    /// Design: docs/design/platforms/winui/pages.md#a-bars-buttons
    void restSubtle(controls::Control const &control, bool splits) {
        std::wstring prefix = splits ? L"SplitButton" : L"Button", clear = L"Transparent";
        std::vector<std::pair<std::wstring, std::wstring>> brushes{
            {prefix + L"Background", clear},
            {prefix + L"BackgroundPointerOver", L"{ThemeResource SubtleFillColorSecondary}"},
            {prefix + L"BackgroundPressed", L"{ThemeResource SubtleFillColorTertiary}"},
            {prefix + L"BackgroundDisabled", clear},
            {prefix + L"BorderBrush", clear},
            {prefix + L"BorderBrushPointerOver", clear},
            {prefix + L"BorderBrushPressed", clear},
            {prefix + L"BorderBrushDisabled", clear},
        };
        if (splits) brushes.emplace_back(L"SplitButtonBorderBrushDivider", clear);
        nameThemedBrushes(control, brushes);
    }

    /// Dresses the button of the action at `index` - an action's or a setting's: its place in the list, which a press
    /// tells and a reader names it by, its words, whether it can be chosen, its identifier, its picture with its words
    /// beside it only where it says so - else they name it to Narrator and in its tip - and its keys.
    template <typename Button>
    void dressAction(
        Button const &button, xaml::FrameworkElement const &owner, int64_t view, int32_t index, char const *words,
        char const *identifier, char const *icon, bool showsWords, bool enabled, int32_t key, int32_t modifiers,
        bool givesWay
    ) {
        button.Tag(winrt::box_value(index));
        button.Label(text(words));
        button.IsEnabled(enabled);
        if (identifier && *identifier) xaml::Automation::AutomationProperties::SetAutomationId(button, text(identifier));
        if (auto picture = pictureIcon(icon)) {
            if (!enabled && picture.try_as<controls::ImageIcon>()) picture.Opacity(disabledShare(owner));
            button.Icon(picture);
            if (!showsWords) {
                button.LabelPosition(controls::CommandBarLabelPosition::Collapsed);
                controls::ToolTipService::SetToolTip(button, winrt::box_value(text(words)));
                standCompact(button);
            }
        }
        if (key != 0) button.KeyboardAccelerators().Append(accelerator(key, modifiers, givesWay));
        button.Click(guarded("handling Click", [view, index](IInspectable const &, xaml::RoutedEventArgs const &) {
            callbacks.chosen(view, index);
        }));
    }

    /// An action whose menu opens apart from its click - a split button's arrow - or by its click with WinUI's
    /// chevron - a drop-down button's - in the container a command bar holds any control in, told by its place as a
    /// bar's button is: its picture, and its words where they show, as a bar's button shows them.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    controls::AppBarElementContainer containedAction(
        bool splits, xaml::FrameworkElement const &owner, int64_t view, int32_t index, char const *words,
        char const *identifier, char const *icon, bool showsWords, bool destructive, bool enabled, int32_t key,
        int32_t modifiers, bool givesWay
    ) {
        controls::StackPanel content;
        content.Orientation(controls::Orientation::Horizontal);
        content.Spacing(8);
        auto picture = pictureIcon(icon);
        if (picture) {
            if (!enabled && picture.try_as<controls::ImageIcon>()) picture.Opacity(disabledShare(owner));
            content.Children().Append(picture);
        }
        if (!picture || showsWords) {
            controls::TextBlock label;
            label.Text(text(words));
            content.Children().Append(label);
        }
        controls::ContentControl control{nullptr};
        if (splits) {
            controls::SplitButton split;
            split.Click(guarded("handling Click",
                [view, index](controls::SplitButton const &, controls::SplitButtonClickEventArgs const &) {
                callbacks.chosen(view, index);
            }));
            control = split;
        } else {
            control = controls::DropDownButton();
        }
        control.Content(content);
        control.IsEnabled(enabled);
        restSubtle(control, splits);
        // Its words a bar button's size, its box centered on the bar as the bar's other buttons stand.
        control.FontSize(barWordsSize);
        control.VerticalAlignment(xaml::VerticalAlignment::Center);
        xaml::Automation::AutomationProperties::SetName(control, text(words));
        if (identifier && *identifier) xaml::Automation::AutomationProperties::SetAutomationId(control, text(identifier));
        if (picture && !showsWords) controls::ToolTipService::SetToolTip(control, winrt::box_value(text(words)));
        if (key != 0) control.KeyboardAccelerators().Append(accelerator(key, modifiers, givesWay));
        if (destructive) {
            std::wstring name = splits ? L"SplitButtonForeground" : L"ButtonForeground";
            markDestructive(control, {name, name + L"PointerOver", name + L"Pressed"});
        }
        controls::AppBarElementContainer contained;
        contained.VerticalContentAlignment(xaml::VerticalAlignment::Center);
        contained.Tag(winrt::box_value(index));
        contained.IsEnabled(enabled);
        contained.Content(control);
        return contained;
    }
}

extern "C" StateUIObjectRef stateui_winui_title_bar_make(int64_t view) {
    try {
        controls::TitleBar bar;
        bar.Tag(winrt::box_value(view));
        bar.BackRequested(guarded("handling BackRequested",
            [view](controls::TitleBar const &, IInspectable const &) { callbacks.chosen(view, -1); }));
        bar.PaneToggleRequested(guarded("handling PaneToggleRequested",
            [view](controls::TitleBar const &, IInspectable const &) { callbacks.chosen(view, -2); }));
        bar.Content(slot());
        bar.Loaded(guarded("handling Loaded", [](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            capCaptionRoom(sender.as<controls::TitleBar>());
        }));
        bar.SizeChanged(guarded("handling SizeChanged",
            [](IInspectable const &sender, xaml::SizeChangedEventArgs const &) {
            capCaptionRoom(sender.as<controls::TitleBar>());
        }));

        // The leading edge's actions stand after the way back and the toggle; it shows only while it holds some.
        auto leading = actionBar();
        leading.Visibility(xaml::Visibility::Collapsed);
        bar.LeftHeader(leading);
        bar.RightHeader(actionBar());
        return detach(bar);
    } catch (...) {
        report("making a title bar");
        return nullptr;
    }
}

extern "C" void stateui_winui_title_bar_set(
    StateUIObjectRef handle, char const *title, char const *subtitle, char const *icon, bool back, bool paneToggle,
    StateUIGround kind, uint32_t argb, float opacity, float tintOpacity, StateUIBrush gradient, bool hasForeground,
    uint32_t foreground, int32_t theme
) {
    try {
        auto bar = borrow<controls::TitleBar>(handle);
        if (bar.Title() != text(title)) bar.Title(text(title));
        if (bar.Subtitle() != text(subtitle)) bar.Subtitle(text(subtitle));
        if (sourceFile(bar.IconSource()) != pictureName(icon)) bar.IconSource(pictureIconSource(icon));
        bar.IsBackButtonVisible(back);
        bar.IsPaneToggleButtonVisible(paneToggle);
        if (auto brush = barGround(kind, argb, opacity, tintOpacity, gradient)) bar.Background(brush);
        else bar.ClearValue(controls::Control::BackgroundProperty());
        if (hasForeground) bar.Foreground(media::SolidColorBrush(color(foreground)));
        else bar.ClearValue(controls::Control::ForegroundProperty());
        if (bar.RequestedTheme() != elementTheme(theme)) bar.RequestedTheme(elementTheme(theme));
        paintActions(bar);
    } catch (...) {
        report("setting a title bar");
    }
}

extern "C" void stateui_winui_title_bar_caption_room(
    StateUIObjectRef handle, double *kept, double *room, int32_t *columns) {
    try {
        auto found = captionRoom(borrow<controls::TitleBar>(handle));
        *kept = found.trailing ? found.trailing.ActualWidth() : -1;
        *room = found.trailingRoom;
        *columns = (found.leading ? 1 : 0) + (found.trailing ? 1 : 0);
    } catch (...) {
        report("reading the room a title bar keeps");
    }
}

extern "C" int32_t stateui_winui_title_bar_theme(StateUIObjectRef handle) {
    try {
        return colorScheme(borrow<controls::TitleBar>(handle).RequestedTheme());
    } catch (...) {
        report("reading a title bar's theme");
        return StateUIColorSchemeSystem;
    }
}

extern "C" void stateui_winui_title_bar_set_actions(
    StateUIObjectRef handle, char const *const *texts, char const *const *identifiers, char const *const *icons,
    bool const *words, bool const *destructive, int32_t const *groups, int32_t leadingGroups, bool const *enabled,
    int32_t const *keys, int32_t const *modifiers, bool const *givesWay, int32_t const *states,
    int32_t const *openings, int32_t count
) {
    try {
        auto bar = borrow<controls::TitleBar>(handle);
        setActions(actionEdges(bar), bar, winrt::unbox_value<int64_t>(bar.Tag()), texts, identifiers, icons, words,
                   destructive, groups, leadingGroups, enabled, keys, modifiers, givesWay, states, openings, count);
        paintActions(bar);
    } catch (...) {
        report("setting a title bar's actions");
    }
}

void stateui::setActions(
    ActionEdges const &edges, xaml::FrameworkElement const &owner, int64_t view, char const *const *texts,
    char const *const *identifiers, char const *const *icons, bool const *words, bool const *destructive,
    int32_t const *groups, int32_t leadingGroups, bool const *enabled, int32_t const *keys, int32_t const *modifiers,
    bool const *givesWay, int32_t const *states, int32_t const *openings, int32_t count
) {
    auto leading = edges.leading, trailing = edges.trailing;
    for (auto const &actions : {leading, trailing}) {
        actions.PrimaryCommands().Clear();
        actions.SecondaryCommands().Clear();
    }
    for (int32_t index = 0; index < count; ++index) {
        // A setting is WinUI's two-state button, checked while on; an action, its button.
        controls::ICommandBarElement button{nullptr};
        if (states[index] >= 0) {
            controls::AppBarToggleButton toggle;
            toggle.IsChecked(states[index] == 1);
            dressAction(toggle, owner, view, index, texts[index], identifiers[index], icons[index], words[index],
                        enabled[index], keys[index], modifiers[index], givesWay[index]);
            button = toggle;
        } else if (openings[index] != 0) {
            button = containedAction(openings[index] == 1, owner, view, index, texts[index], identifiers[index],
                                     icons[index], words[index], destructive[index], enabled[index], keys[index],
                                     modifiers[index], givesWay[index]);
        } else {
            controls::AppBarButton action;
            dressAction(action, owner, view, index, texts[index], identifiers[index], icons[index], words[index],
                        enabled[index], keys[index], modifiers[index], givesWay[index]);
            if (destructive[index])
                markDestructive(action, {L"AppBarButtonForeground", L"AppBarButtonForegroundPointerOver",
                                         L"AppBarButtonForegroundPressed"});
            button = action;
        }
        if (groups[index] < 0) {
            trailing.SecondaryCommands().Append(button);
            continue;
        }
        // A group stands apart from the one before it at its edge by the room of WinUI's separator.
        auto commands = (groups[index] < leadingGroups ? leading : trailing).PrimaryCommands();
        if (index > 0 && groups[index - 1] >= 0 && groups[index - 1] != groups[index] && commands.Size() > 0)
            commands.Append(groupGap());
        commands.Append(button);
    }
    auto shown = leading.PrimaryCommands().Size() > 0 ? xaml::Visibility::Visible : xaml::Visibility::Collapsed;
    if (leading.Visibility() != shown) leading.Visibility(shown);
}

extern "C" void stateui_winui_title_bar_set_title_view(StateUIObjectRef handle, StateUIObjectRef view) {
    try {
        fill(borrow<controls::TitleBar>(handle).Content().as<controls::ContentControl>(), view);
    } catch (...) {
        report("filling a title bar");
    }
}

extern "C" StateUIObjectRef stateui_winui_split_make(int64_t view) {
    try {
        controls::SplitView split;
        split.DisplayMode(controls::SplitViewDisplayMode::Overlay);
        split.Pane(paneColumn(view));
        auto card = detailCard();
        card.Child(rows({true, false}));
        split.Content(card);
        stand(split);
        split.ActualThemeChanged(guarded("handling ActualThemeChanged",
            [](xaml::FrameworkElement const &sender, IInspectable const &) { stand(sender.as<controls::SplitView>()); }));
        split.PaneOpening(guarded("handling PaneOpening", [view](controls::SplitView const &sender, IInspectable const &) {
            showSidebar(sender, true);
            callbacks.presented(view, true);
        }));
        split.PaneClosing(guarded("handling PaneClosing",
            [view](controls::SplitView const &sender, controls::SplitViewPaneClosingEventArgs const &args) {
            // Closing of WinUI's accord - a click beside a pane over the detail - the pane stays open while the host
            // slides it out; the host closes a pane none wide.
            if (sender.OpenPaneLength() > 0.5) args.Cancel(true);
            callbacks.presented(view, false);
        }));
        split.PaneClosed(guarded("handling PaneClosed", [](controls::SplitView const &sender, IInspectable const &) {
            if (!sender.IsPaneOpen()) showSidebar(sender, false);
        }));
        return detach(split);
    } catch (...) {
        report("making a split view");
        return nullptr;
    }
}

extern "C" void stateui_winui_split_set(
    StateUIObjectRef handle, StateUIObjectRef pane, StateUIObjectRef content, StateUIObjectRef row, bool open,
    bool beside
) {
    try {
        auto split = borrow<controls::SplitView>(handle);
        auto column = split.Pane().as<controls::Grid>();
        auto sidebar = pane ? as<xaml::UIElement>(pane) : xaml::UIElement{nullptr};
        auto children = column.Children();
        bool anew = children.Size() < 2 ? sidebar != nullptr : children.GetAt(1) != sidebar;
        if (anew) standInRow(column, 1, pane);
        auto detail = split.Content().as<controls::Border>().Child().as<controls::Grid>();
        standInRow(detail, 0, row);
        standInRow(detail, 1, content);
        auto mode = beside ? controls::SplitViewDisplayMode::Inline : controls::SplitViewDisplayMode::Overlay;
        if (split.DisplayMode() != mode) {
            split.DisplayMode(mode);
            stand(split);
        }
        // A pane over the detail collapses its sidebar once it has closed; one beside it tells no closing, and a
        // view WinUI has not loaded, or a new sidebar, tells nothing.
        if (open || anew || beside || !split.IsLoaded()) showSidebar(split, open);
        if (split.IsPaneOpen() != open) split.IsPaneOpen(open);
    } catch (...) {
        report("setting a split view");
    }
}

extern "C" void stateui_winui_split_set_actions(
    StateUIObjectRef handle, char const *const *texts, char const *const *identifiers, char const *const *icons,
    bool const *words, bool const *destructive, int32_t const *groups, int32_t leadingGroups, bool const *enabled,
    int32_t const *keys, int32_t const *modifiers, bool const *givesWay, int32_t const *states,
    int32_t const *openings, int32_t count
) {
    try {
        auto head = paneHead(borrow<controls::SplitView>(handle));
        setActions(headEdges(head), head, winrt::unbox_value<int64_t>(head.Tag()), texts, identifiers, icons,
                   words, destructive, groups, leadingGroups, enabled, keys, modifiers, givesWay, states, openings,
                   count);
        showPaneHead(head);
    } catch (...) {
        report("setting a split view's sidebar actions");
    }
}

extern "C" void stateui_winui_split_set_action_menu(
    StateUIObjectRef handle, int32_t place, bool held, int32_t first, int32_t const *kinds, char const *const *titles,
    bool const *enabled, char const *const *identifiers, char const *const *icons, bool const *destructive,
    int32_t const *keys, int32_t const *modifiers, bool const *givesWay, int32_t count
) {
    try {
        auto head = paneHead(borrow<controls::SplitView>(handle));
        setActionMenu(headEdges(head), winrt::unbox_value<int64_t>(head.Tag()), place, held, first, kinds,
                      titles, enabled, identifiers, icons, destructive, keys, modifiers, givesWay, count);
    } catch (...) {
        report("giving a split view's sidebar action its menu");
    }
}

ActionEdges stateui::paneActionEdges(controls::SplitView const &split) {
    return headEdges(paneHead(split));
}

extern "C" double stateui_winui_split_pane_width(StateUIObjectRef) {
    try {
        // The theme's width, which a SplitView's style opens its pane at; the pane's own is the slide's.
        auto key = winrt::box_value(L"SplitViewOpenPaneThemeLength");
        auto width = xaml::Application::Current().Resources().TryLookup(key);
        return winrt::unbox_value_or<double>(width, 320);
    } catch (...) {
        report("reading a split view's pane");
        return 320;
    }
}

extern "C" void stateui_winui_split_slide(StateUIObjectRef handle, double pane, double width) {
    try {
        auto split = borrow<controls::SplitView>(handle);
        if (split.OpenPaneLength() != pane) split.OpenPaneLength(pane);
        // The sidebar at its whole width, its trailing edge at the pane's: what stands past the pane's leading edge
        // stands past the window's.
        if (auto sidebar = split.Pane().try_as<xaml::FrameworkElement>()) {
            if (sidebar.Width() != width) sidebar.Width(width);
            sidebar.HorizontalAlignment(xaml::HorizontalAlignment::Right);
        }
    } catch (...) {
        report("sliding a split view's pane");
    }
}

extern "C" void stateui_winui_split_measure_pane_again(StateUIObjectRef handle) {
    try {
        if (auto pane = borrow<controls::SplitView>(handle).Pane()) measureAgain(pane);
    } catch (...) {
        report("measuring a split view's pane again");
    }
}

void stateui::paintActions(ActionEdges const &edges, media::Brush const &foreground) {
    auto paint = [&](controls::Control const &control) {
        if (foreground) control.Foreground(foreground);
        else control.ClearValue(controls::Control::ForegroundProperty());
    };
    for (auto const &actions : {edges.leading, edges.trailing}) {
        paint(actions);
        for (auto const &command : actions.PrimaryCommands()) {
            // A group's room draws nothing on the bar.
            if (command.try_as<controls::AppBarSeparator>()) continue;
            auto button = command.try_as<controls::AppBarButton>();
            if (button && isDestructive(button, L"AppBarButtonForeground")) continue;
            // A contained split or drop-down button draws its words in its own color, not its container's.
            if (auto contained = command.try_as<controls::AppBarElementContainer>()) {
                auto control = contained.Content().as<controls::Control>();
                auto name = control.try_as<controls::SplitButton>() ? L"SplitButtonForeground" : L"ButtonForeground";
                if (!isDestructive(control, name)) paint(control);
                continue;
            }
            if (auto control = command.try_as<controls::Control>()) paint(control);
        }
    }
}

xaml::Media::Brush stateui::ground(StateUIGround kind, uint32_t argb, float opacity, float tintOpacity) {
    switch (kind) {
    case StateUIGroundOwn:
        return nullptr;
    case StateUIGroundColor:
        return media::SolidColorBrush(color(argb));
    case StateUIGroundAcrylic: {
        media::AcrylicBrush acrylic;
        acrylic.TintColor(color(argb | 0xFF000000u));
        acrylic.TintOpacity(tintOpacity);
        acrylic.TintLuminosityOpacity(static_cast<double>(opacity));
        acrylic.FallbackColor(color(argb | 0xFF000000u));
        return acrylic;
    }
    }
    return nullptr;
}

xaml::Media::Brush stateui::barGround(
    StateUIGround kind, uint32_t argb, float opacity, float tintOpacity, StateUIBrush const &gradient
) {
    if (gradient.kind == StateUIBrushKindLinear || gradient.kind == StateUIBrushKindRadial) return brush(gradient);
    return ground(kind, argb, opacity, tintOpacity);
}

extern "C" void stateui_winui_split_set_pane_grounds(
    StateUIObjectRef handle, StateUIGround besideKind, uint32_t besideArgb, float besideOpacity, float besideTintOpacity,
    StateUIGround overKind, uint32_t overArgb, float overOpacity, float overTintOpacity
) {
    try {
        // Each place's own brush - the whole pane's, around the page in it too; none is WinUI's own.
        // Design: docs/design/platforms/winui/pages.md#a-split-view
        auto split = borrow<controls::SplitView>(handle);
        auto keep = [&](wchar_t const *name, xaml::Media::Brush const &brush) {
            auto key = winrt::box_value(name);
            if (brush) split.Resources().Insert(key, brush);
            else if (split.Resources().HasKey(key)) split.Resources().Remove(key);
        };
        keep(L"StateUIPaneBeside", ground(besideKind, besideArgb, besideOpacity, besideTintOpacity));
        keep(L"StateUIPaneOver", ground(overKind, overArgb, overOpacity, overTintOpacity));
        stand(split);
    } catch (...) {
        report("standing a split view's sidebar");
    }
}

extern "C" void stateui_winui_menu_bar_set_colors(
    StateUIObjectRef handle, StateUIBrush background, bool hasForeground, uint32_t foreground, int32_t theme
) {
    try {
        // One of the window's bars, painted as the title bar is; its menus' words through the brush their template reads.
        // Design: docs/design/platforms/winui/pages.md#menus
        auto bar = borrow<controls::MenuBar>(handle);
        if (auto painted = brush(background)) bar.Background(painted);
        else bar.ClearValue(controls::Control::BackgroundProperty());
        if (bar.RequestedTheme() != elementTheme(theme)) bar.RequestedTheme(elementTheme(theme));
        auto brush = hasForeground ? xaml::Media::Brush(media::SolidColorBrush(color(foreground))) : nullptr;
        writeResources(bar, {{L"MenuBarItemForeground", brush}});
    } catch (...) {
        report("painting a menu bar");
    }
}

extern "C" StateUIObjectRef stateui_winui_tabs_make(int64_t view) {
    try {
        controls::SelectorBar tabs;
        tabs.SelectionChanged(guarded("handling SelectionChanged",
            [view](controls::SelectorBar const &sender, controls::SelectorBarSelectionChangedEventArgs const &) {
            if (settingTabs) return;
            uint32_t index = 0;
            if (sender.SelectedItem() && sender.Items().IndexOf(sender.SelectedItem(), index)) {
                callbacks.chosen(view, static_cast<int32_t>(index));
            }
        }));
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

extern "C" void stateui_winui_tabs_set(
    StateUIObjectRef handle, char const *const *titles, char const *const *icons, int32_t count, int32_t selected
) {
    struct Setting {
        Setting() { settingTabs = true; }
        ~Setting() { settingTabs = false; }
    } setting;
    try {
        auto tabs = borrow<controls::SelectorBar>(handle);
        auto items = tabs.Items();
        auto tabIconHeight = winrt::unbox_value<double>(
            xaml::Application::Current().Resources().Lookup(winrt::box_value(L"TabViewItemHeaderIconSize")));
        while (static_cast<int32_t>(items.Size()) > count) items.RemoveAtEnd();
        for (int32_t index = 0; index < count; ++index) {
            if (index >= static_cast<int32_t>(items.Size())) items.Append(controls::SelectorBarItem());
            auto item = items.GetAt(index);
            if (item.Text() != text(titles[index])) item.Text(text(titles[index]));
            if (iconFile(item.Icon()) != pictureName(icons[index])) {
                // The row stands a tab's picture at its own size: as tall as the theme's tab icons, as wide as its
                // shape makes it; an icon's glyph as tall.
                auto icon = pictureIcon(icons[index]);
                if (icon) icon.Height(tabIconHeight);
                if (auto glyph = icon ? icon.try_as<controls::FontIcon>() : nullptr) glyph.FontSize(tabIconHeight);
                item.Icon(icon);
            }
        }
        if (selected >= 0 && selected < count && tabs.SelectedItem() != items.GetAt(selected)) {
            tabs.SelectedItem(items.GetAt(selected));
        }
    } catch (...) {
        report("setting a row of tabs");
    }
}
