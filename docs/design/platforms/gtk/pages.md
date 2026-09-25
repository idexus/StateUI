# Pages on GTK

How the GTK host presents a window's pages as GNOME's own applications do:
each page under a header bar of its own, which slides with it.

## A page and its header bar

A page GTK shows stands in a frame: an `AdwToolbarView` whose top bar is the
page's own `AdwHeaderBar`, over the page's view. A page shown by itself is the
window's content in such a frame, its header bar the window's title bar; a
page of a stack is one in its navigation page. The frame lets go of nothing in
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
- no bar at all, for a page that hides its navigation bar.

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

## A page's phases

A page hears that it appears and disappears, and that it is navigated to and
from, in the order the user sees it: when the window shows it, when a push or
a pop moves it, each phase rendered before the next is heard.
