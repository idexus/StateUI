// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

/// <summary>
/// What this host realizes, member by member - the MAUI column of the control
/// dictionary, <c>docs/controls/</c>.
/// </summary>
/// <remarks>
/// <para>
/// A record names an entry of the dictionary - a control, or a part of an
/// application's structure - or a tier, the protocol an entry takes the member
/// from; an entry's own record wins over its tier's. A member is recorded once
/// this host realizes it and a test of this host's suite covers it; a partial
/// record says what is still missing.
/// </para>
/// <para>
/// <c>ControlDictionaryTests</c>, in the core's suite, reads these records,
/// holds each to the contracts - a member of the element or tier it names,
/// recorded once, a partial one saying what is missing - and renders the
/// dictionary's MAUI column from them. An act is recorded where a test of this
/// host performs it.
/// </para>
/// </remarks>
internal static class MauiRealization
{
    /// <summary>One member this host realizes.</summary>
    /// <param name="Owner">The entry or tier the record is about.</param>
    /// <param name="Member">The member - a property, or a handler's event.</param>
    /// <param name="Missing">What is not realized yet; null when nothing is.</param>
    internal sealed record Record(string Owner, string Member, string? Missing);

    /// <summary>The entries this host builds nothing for: none of their members is realized.</summary>
    internal static readonly HashSet<string> Unrealized = [];

    /// <summary>Every record, the tiers' first.</summary>
    internal static readonly Record[] Records =
    [
        // Tiers - a member every wearer realizes alike
        Complete("BarElement", "barBackgroundColor"),
        Complete("DecorableTextElement", "textDecorations"),
        Complete("LineHeightElement", "lineHeight"),
        Complete("MenuItemElement", "clicked"),
        Complete("MenuItemElement", "icon"),
        Complete("MenuItemElement", "isDestructive"),
        Complete("MenuItemElement", "isEnabled"),
        Complete("MenuItemElement", "text"),
        Complete("PageElement", "icon"),
        Complete("PageElement", "title"),
        Complete("StackBase", "spacing"),

        // Entries - a control's or a part's own, and where it differs from its tier
        Complete("Border", "shape"),
        Complete("Border", "stroke"),
        Complete("Border", "strokeDashOffset"),
        Complete("Border", "strokeDashPattern"),
        Complete("Border", "strokeLineCap"),
        Complete("Border", "strokeLineJoin"),
        Complete("Border", "strokeMiterLimit"),
        Complete("Border", "strokeWidth"),
        Complete("Grid", "columnSpacing"),
        Complete("Grid", "columns"),
        Complete("Grid", "rowSpacing"),
        Complete("Grid", "rows"),
        Complete("Label", "background"),
        Complete("Label", "lineBreak"),
        Complete("Label", "maximumLines"),
        Partial("Map", "isScrollEnabled", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Map", "isTrafficEnabled", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Map", "isZoomEnabled", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Map", "mapClicked", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Map", "mapType", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Map", "showsUserLocation", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Complete("Menu", "isEnabled"),
        Complete("Menu", "text"),
        Complete("NavigationStack", "barForegroundColor"),
        Complete("NavigationStack", "popped"),
        Complete("Page", "appearing"),
        Complete("Page", "backButtonTitle"),
        Complete("Page", "background"),
        Complete("Page", "disappearing"),
        Complete("Page", "hasBackButton"),
        Complete("Page", "hasNavigationBar"),
        Complete("Page", "icon"),
        Complete("Page", "navigatedFrom"),
        Complete("Page", "navigatedTo"),
        Complete("Page", "navigatingFrom"),
        Complete("Page", "padding"),
        Complete("Page", "title"),
        Partial("Pin", "address", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Pin", "label", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Pin", "location", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Pin", "pinClicked", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Pin", "pinDetailsClicked", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Partial("Pin", "type", missing: "Windows and Linux have no map; the Map draws the unknown-control marker there."),
        Complete("PositionIndicator", "count"),
        Complete("PositionIndicator", "hideSingle"),
        Complete("PositionIndicator", "indicatorColor"),
        Complete("PositionIndicator", "indicatorSize"),
        Complete("PositionIndicator", "indicatorsShape"),
        Complete("PositionIndicator", "maximumVisible"),
        Complete("PositionIndicator", "position"),
        Complete("PositionIndicator", "selectedIndicatorColor"),
        Complete("RefreshView", "isRefreshEnabled"),
        Complete("RefreshView", "isRefreshing"),
        Complete("RefreshView", "isRefreshingChanged"),
        Complete("RefreshView", "refreshRequested"),
        Complete("Scene", "activated"),
        Complete("Scene", "deactivated"),
        Complete("Scene", "destroying"),
        Complete("Scene", "stopped"),
        Complete("Scene", "windowClosed"),
        Complete("Scene", "windowRestored"),
        Complete("ScrollView", "horizontalScrollBarVisibility"),
        Complete("ScrollView", "orientation"),
        Complete("ScrollView", "scrollOffset"),
        Complete("ScrollView", "scrollStopped"),
        Complete("ScrollView", "scrollYChanged"),
        Complete("ScrollView", "verticalScrollBarVisibility"),
        Complete("Span", "background"),
        Complete("SplitView", "isSidebarVisible"),
        Complete("SplitView", "isSidebarVisibleChanged"),
        Complete("SwipeAction", "background"),
        Complete("SwipeAction", "isVisible"),
        Complete("SwipeActions", "mode"),
        Complete("SwipeActions", "side"),
        Complete("SwipeActions", "swipeBehaviorOnInvoked"),
        Complete("SwipeView", "swipeChanging"),
        Complete("SwipeView", "swipeEnded"),
        Complete("SwipeView", "swipeStarted"),
        Complete("SwipeView", "threshold"),
        Complete("TabbedView", "currentPage"),
        Complete("TabbedView", "currentPageChanged"),
        Complete("TitleBar", "barForegroundColor"),
        Complete("TitleBar", "icon"),
        Complete("TitleBar", "subtitle"),
        Complete("TitleBar", "title"),
        Complete("ToolbarItem", "placement"),
        Complete("ToolbarItem", "priority"),
        Complete("VisualState", "group"),
        Complete("VisualState", "name"),
        Complete("Window", "activated"),
        Complete("Window", "created"),
        Complete("Window", "deactivated"),
        Complete("Window", "destroying"),
        Partial("Window", "floatsOnTop", missing: "Only Mac Catalyst keeps the window on top; Windows and Linux leave it among the others."),
        Complete("Window", "height"),
        Complete("Window", "isMaximizable"),
        Complete("Window", "isMinimizable"),
        Complete("Window", "maximumHeight"),
        Complete("Window", "maximumWidth"),
        Complete("Window", "minimumHeight"),
        Complete("Window", "minimumWidth"),
        Complete("Window", "modalPopped"),
        Complete("Window", "resumed"),
        Complete("Window", "stopped"),
        Complete("Window", "title"),
        Complete("Window", "width"),
        Complete("Window", "windowType"),
        Complete("Window", "windowValue"),
        Complete("Window", "x"),
        Complete("Window", "y"),
    ];

    /// <summary>A member realized in full.</summary>
    /// <param name="owner">The entry or tier.</param>
    /// <param name="member">The member.</param>
    private static Record Complete(string owner, string member) => new(owner, member, null);

    /// <summary>A member realized, but incomplete.</summary>
    /// <param name="owner">The entry or tier.</param>
    /// <param name="member">The member.</param>
    /// <param name="missing">What is not realized yet.</param>
    private static Record Partial(string owner, string member, string missing) => new(owner, member, missing);
}
