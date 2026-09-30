# Pages on UIKit

How the UIKit host shows pages and their arrangements: each held by a view
controller of UIKit's own, so a page stands under UIKit's bars, goes back by
UIKit's gestures and sits in UIKit's tab bar and split view, and the user's
choices on them are handed to the host layer, which tells the pages and the
states.

A page is a controller whose view holds the page's own view within the safe
area its bars leave. An arrangement of pages is the controller UIKit has for
it; the window's arrangement is a child of the window's root controller, over
the whole window.

## The safe area

A page's view stands in its controller's safe area, clear of the bars and the
notch, and out to the screen's edge on each edge its content lets itself under
them ([the safe area](../../host/layout.md#the-safe-area)); the controller's
own view shows the page's background, so it stands behind the bars either
way. Only a page's own layout reaches under them; one deeper in stands where
its page puts it.

## The bar

A page's bar is its navigation item: its title - or the view standing in for
it - its actions as the host layer composes them along the page's path, each
group a `UIBarButtonItemGroup` of its own, so each keeps its own shared
background, the leading ones beside the way back, those beyond the bar in a
menu behind its last button, whether it offers the way back, and its colours
where the tree gives them. An action that destroys something is marked
destructive in the menu and tinted red on the bar. A tabbed view's bar is its
chosen tab's page's, but for its title: the page the window is named by
([the window's chrome](../../host/pages.md#the-windows-chrome)) - tabs pushed
onto a stack by their own title, else by the page beneath - which names the
window's scene too. Every bar in the window is written again as the window is shown, so a bar
always says what its page says now.

## Pictures on the bars

A picture on a bar - an action's - stands 24 points tall and a tab's 25,
UIKit's own icon sizes, each as wide as its shape makes it
(`PictureArithmetic.glyph`); on a phone on its side, whose bars stand
lower, both stand 18 points tall (`landscapeImagePhone`). The picture keeps
its pixels and is drawn smaller: at its file's size it stands far taller
than the system's own pictures beside it.

## A navigation stack

A NavigationStack is UIKit's navigation controller over its pages, the top
one showing, and the bar hidden where the top page hides it. A page coming or
going is pushed or popped as UIKit does it, unless the user asked for less
motion. The user taking pages away - the back button, the edge swipe, the
back button's menu - is told to the stack as how many stay, as the index of
its top; where the application keeps its pages, the stack stays as it is.

## Tabs

A TabbedView is UIKit's tab bar controller, each tab named by its page's
title and picture. Which tab shows is the host layer's rule: none chosen
until the tree or the user chooses one, a tab the tree asks for anew chosen,
the user's choice standing where it is a tab there is. The user's choice is
told as the tab before and the tab now; one the program makes is not.

## A split view

A SplitView is UIKit's split view controller: its sidebar the first column,
its detail the second, a page standing alone in a column under the column's
own bar. It is never one column. In a narrow room - a phone, upright or on
its side - the sidebar slides over the detail from the leading edge, the
detail shaded behind it, opened by the sidebar button UIKit puts on the
detail's bar or a swipe from the edge and closed by a tap on the shade; in a
wide room it stands beside the detail. The split view says it is wide
whatever the room (`traitOverrides`), so UIKit never folds it into one
column, and each column says the room's own width, so the tabs, sheets and
bars inside stand as a phone's.

Whether the sidebar shows is the display mode the host prefers: over or
beside the detail while the tree asks for it, the detail alone while not.
The sidebar showing or hiding on screen is heard as the display mode
changes, whoever moved it; the program's own move and the host's adapting
to a new room are not told back. The traps: sliding over the detail, UIKit
tells no column shown or hidden (`willShow`/`willHide` stay silent for the
sidebar); entering its window it settles a display mode of its own before
the first layout, which is no user's move; and its sidebar button item is
handed out bare - the one on the bar is UIKit's own.

## Sheets

A window's modal stack is UIKit's page sheets, each presented over the one
before once that one stands - UIKit presents over a controller only then -
and all of them only once the window stands on screen: a sheet presented
before, UIKit takes away again at once and tells as the user's. Those still
asked for stay, the rest go from the top. The user swiping the top sheet down
is the window's way back, told as how many stay; a window that leaves tells
nobody of its sheets, which leave with it.

An overlay is laid over the window's pages within the safe area, and a touch
beside what it holds reaches the page under it.

## Menus

A menu is UIKit's, built from the host layer's walk of its entries: an
action for each item, which tells its element when the user chooses it, a
submenu for each menu, and the entries between two separators a group of
their own, as UIKit parts a menu. UIKit holds no menu out of reach itself: a
menu out of reach holds each of its entries out of reach.

A view's context menu is UIKit's context menu interaction, which asks for
the menu as the user holds the view; it is built then from what the tree says
now. The menus the page the user sees puts on its menu bar are the
application's main menu - on an iPad its menu bar - standing before UIKit's
own Window menu, built again whenever they say something else.
