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
  places in overflow behind the bar's menu. An action with a picture stands
  on the bar as an icon, the way a header bar's buttons stand, its title its
  tooltip and its name to assistive technology; one whose picture the
  application does not hold shows its title, and the overflow's menu shows
  titles. So the bar's own buttons never read as one more choice of a
  tabbed view's switcher beside them;
- the way back, the bar's own back button, which libadwaita shows while the
  page has one below it and the page does not refuse it;
- no bar at all, for a page that hides its navigation bar;
- a split view's sidebar toggle, at the start of the bar of the page the user
  sees in its detail, pressed in while the sidebar shows;
- for a tabbed view, its switcher in the middle, over the chosen tab's page's
  actions;
- the bar's colours: a page's header bar is painted in the bar colour of the
  nearest stack or tabbed view around it, and what stands on it - the title,
  the way back, the toggles and the switcher's captions - in the nearest
  stack's foreground, as a class of the host's style sheet
  ([a widget's own box](drawing.md#a-widgets-own-box)). The window's title
  bar has no place of its own on a desktop of header bars: its colours paint
  every header bar no arrangement colours - a split view's sidebar among
  them - and a bar neither colours keeps the platform's.

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

A tabbed view is a `GtkStack` of its tabs, each named by its page's title,
and its `GtkStackSwitcher` stands in the middle of the header bar of the
frame the tabbed view stands in: the captions joined in one control, which
reads as one choice among several beside the bar's own buttons. The
switcher's choice is the user's: the pages hear it, then the selection's
state, and the header bar follows the chosen tab whether or not the
application renders again.

## The window's overlay

What a window lays over everything it shows - the inspector docked in it, an
application's own layers - is an overlay of the `GtkOverlay` the window's
content stands in: over the whole window, header bars included, which the
inspector's own layout leaves free where it docks at a side. It holds a
layout that lets input through, so a click beside what it holds goes on to
the page under it ([listening](input.md#listening)). The window takes the
overlay out when it no longer describes it.

## A page's phases

A page hears its phases as the host layer tells them ([a page's
phases](../../host/pages.md#a-pages-phases)); GTK supplies the tab the user
chose and whether the sidebar shows, which the layer reads to know what an
arrangement shows.
