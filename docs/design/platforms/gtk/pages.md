# Pages on GTK

How the GTK host presents a window's pages as GNOME's own applications do:
each page under a header bar of its own, which slides with it.

## A page and its header bar

A page GTK shows stands in a frame: an `AdwToolbarView` whose top bar is the
page's own `AdwHeaderBar`, over the page's view. A tabbed view stands in one
too. A page shown by itself is the window's content in such a frame, its
header bar the window's title bar; a page of a stack is one in its navigation
page; a split view's pane is one where it is a page. A stack and a split view
stand in none: their pages carry their own. The frame holds its bar's title
itself, since a title view takes its place in the bar and the bar lets go of
what it no longer shows. The frame lets go of nothing in
it as it goes: a page popped still slides away in it, and GTK lets the whole
of it go once the slide is over.

## The chrome

The chrome is composed by one function from what the window shows, after
every render, and written on the header bar of each page shown:

- the page's title, at the middle of its bar, or its title view in its place,
  where an application puts its search;
- the page's actions, at the bar's end in their priority's order, those it
  places in overflow behind the bar's menu;
- the way back, the bar's own back button, which libadwaita shows while the
  page has one below it and the page does not refuse it;
- no bar at all, for a page that hides its navigation bar;
- a split view's sidebar toggle, at the start of the bar of the page the user
  sees in its detail, pressed in while the sidebar shows;
- for a tabbed view, its switcher in the middle, over the chosen tab's page's
  actions.

The page the user sees names the window, for the desktop's switcher and dock;
a page with no title leaves the window's own.

## A navigation stack

A navigation stack is libadwaita's `AdwNavigationView`, each page in a
navigation page holding its frame. A path one page longer pushes the page, one
shorter pops to where it now ends, any other change replaces the stack - each
as the program's move, whose `popped` is its echo. The user's back - the back
button, the swipe, Alt+Left, the mouse's back button - pops in GTK first, and
the stack's `popped` then tells the path how many pages remain; a path that
does not follow is put back by the next render. A page is pushed named as the
tree names it, or after the application until it does: libadwaita asks every
page for a title.

## A split view

A split view is libadwaita's `AdwOverlaySplitView`: the sidebar beside the
detail, and over it in a window narrower than 400sp - a breakpoint of the
window's, as GNOME's applications collapse theirs, the window then saying the
smallest size GNOME's windows keep. Whether the sidebar shows is StateUI's
binding: the program's write shows or hides it, and GTK's own change - a click
beside a sidebar over the detail, a swipe - and the detail's toggle report
back into it. A window wide enough for both panes opens with the sidebar
shown, said once GTK has laid the window out.

## Tabs

A tabbed view is libadwaita's `AdwViewStack` of its tabs, each named by its
page's title, and its `AdwViewSwitcher` stands in the middle of the header bar
of the frame the tabbed view stands in. The switcher's choice is the user's:
the pages hear it, then the selection's state, and the header bar follows the
chosen tab whether or not the application renders again.

## A page's phases

A page hears that it appears and disappears, and that it is navigated to and
from, in the order the user sees it: when the window shows it, when a push or
a pop moves it, each phase rendered before the next is heard.
