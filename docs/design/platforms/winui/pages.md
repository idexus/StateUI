# Pages on WinUI

How the WinUI host presents a window's arrangement of pages - a navigation
stack, a split view, a set of tabs - as a Windows desktop application
presents its own: one chrome across the top of the window, WinUI's own
navigation pane, and the way back the mouse and the keyboard offer. StateUI
keeps every page, the path and the selection; WinUI is given no second
navigation model to reconcile with them.

## The window's chrome

A window has one chrome: WinUI's `TitleBar`, across the top of a window
whose content extends under its title bar, over a Mica backdrop, as
Windows' own applications stand. The renderer composes it again from what
the window shows after every render, and after every change the user makes
that the application may not render for - a tab chosen, the sidebar shown:

- the visible page's title names the window, on the chrome and to the
  system;
- the way back is the chrome's own back button, while the visible stack's
  top page can go back;
- a split view adds the chrome's pane toggle, which shows and hides its
  sidebar;
- the visible page's actions stand on a command bar at the chrome's trailing
  side, in their priority's order, those it places in overflow behind the
  bar's own "more";
- the page's title view stands at the chrome's centre, where an application
  puts its search;
- an authored `TitleBar` adds its leading, centre and trailing content, and
  the bars' colours paint the chrome;
- the visible page's menus stand on a menu bar beneath the chrome
  ([menus](#menus)).

A page that hides its navigation bar puts neither the way back nor its
actions on the chrome.

## A navigation stack

A navigation stack shows its top page across its whole frame; the pages below
are kept by their elements and held by no view, so each keeps what it showed
for when the user comes back to it. Its bar is the window's chrome.

## The way back

The way back is the chrome's back button, the mouse's back button, Alt+Left
and the Back key - each the window's, as Windows applications offer it - and
it pops the visible stack's top page.

## A split view

A split view's sidebar stands in WinUI's `NavigationView` pane, the detail in
its content: WinUI decides, as for any Windows application, whether the pane
stands beside the detail - from 1008 DIPs, where its navigation pane expands -
or opens over it, closed by a click beside it. The view shows none of its own
buttons, which the window's chrome carries, and no compact rail: a sidebar is
a page, with no icons to stand in one.

Whether the sidebar shows is StateUI's binding, which follows what WinUI
shows: the pane opening or closing of WinUI's accord - a click beside it, the
window's room - reaches the binding. The host's one adaptation is that a
window wide enough for both panes opens with the sidebar shown; after that,
the user and the application decide. The window learns its room inside a
layout pass, so the binding hears it in the turn after it.

## A native arrangement

WinUI's navigation view lays its pages out in the room it is arranged in, and
a page it places is measured by it at that room. So the host measures the
navigation view at the size it last arranged it at - in the first pass at
the room offered - and a new room measures it again at the new size before it
is arranged there; the second pass then asks for what the first gave, and the
layout settles ([no room asked](layout.md#no-room-asked)).

The split view answers WinUI with what the navigation view asked and never
measures its pages itself. WinUI arranges an element at no less than it was
last measured, so a detail page measured at the split's whole width would
keep that width beside an open pane and run past the window's edge by the
pane's width.

## Tabs

A tabbed view's tabs are a `SelectorBar`. The first tabbed view down the
visible page path - through stacks and split views' details - gives its tabs
to the window: they stand across the window beneath its chrome, or across a
split view's detail, beside the sidebar and never over it. Any other tabbed
view - in a sidebar, in a tab of another, inside content - shows its tabs in a
row of its own above its page. Choosing a tab is the user choosing it: the
pages hear it, then the selection's state, and the chrome follows at once.

## A page's phases

A page hears that it appears and disappears, and on a stack that it is
navigated to and from, only once the arrangement shows what the tree says,
each phase rendered before the next is heard. What an arrangement stopped
showing leaves before what it started showing arrives.

## The modal stack

The pages a window's modal stack presents stand over everything the window
shows, as WinUI presents a dialog: each on a card over a veil across the
whole window - the chrome and the tabs too - the last on top. The card is a
dialog's own - its background, outline and corners, no wider than a dialog
and clear of the window's edges - with the presented page's title above the
page, and it enters as a dialog enters. The veil takes every click meant for
what is beneath, and the keyboard goes round inside the top card.

What the user sees is the top sheet, else the window's arrangement: when that
changes, the page that stops showing hears it and then the one that starts,
as a move. Escape takes the top sheet away, and so does the window's way back
while a sheet shows, once the sheet's own stack has no page to go back to;
the window is told how many sheets remain.

## The window's overlay

What a window lays over everything it shows - the inspector docked in it -
stands where the page stands, beneath the chrome, over the page and over
every sheet, whichever came first. It has no background of its own, so a
click beside what it holds goes on to the page or the sheet under it. It and
the sheets are layers of the window, not the content of a row: the chrome and
the menu bar standing again, as a page's menus come and go, leave both where
they are. The window takes the overlay out when it no longer describes it.

## Menus

The visible page's menus stand on WinUI's `MenuBar` in a row of the window
beneath its chrome, above the window's tabs - each menu one of the bar's,
its entries within it - while the page has any; a page with none leaves no
row. The bar is written again only when what it draws changes: a render that
changes nothing on it leaves the bar, and a menu open on it, as they are.

A view's context menu is WinUI's `MenuFlyout` on the view: a right click and a
long press open it where the user asked, and on a view that holds the
keyboard, the menu key and Shift+F10 too. Its items
are `MenuFlyoutItem`s, its separators `MenuFlyoutSeparator`s and its submenus
`MenuFlyoutSubItem`s, one level inside another as the tree nests them; an
entry that cannot be chosen is shown dimmed. The host hands the relay the
menu flat - an item, a separator, a submenu opening and closing, each with its
caption - and hears a choice by the item's place among the items, submenus'
included; the item's own handler runs. A bar's menus are written the same
way. Any entry the tree changes, adds or
removes gives the view its menu again, and a menu with no entries is none.

A stack with a menu is hit across its bounds, as a listening one is
([listening](input.md#listening)): a right click anywhere across it opens the
menu, not only on its children.
