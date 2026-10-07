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

- the page's title, at the middle of its bar, with the line under it its
  path declares (`barSubtitle`) - libadwaita's window title holds both - or
  its title view in its place, where an application puts its search. A
  header bar names its page: the application's own name and mark
  (`barTitle`, `barIcon`) stand on no GNOME header bar;
- the groups of actions its path declares, composed by the host layer
  ([the actions of a path](../../host/pages.md#the-actions-of-a-path)): the
  leading groups at the bar's start, after the sidebar's toggle, the
  trailing ones at its end, each group a box of its own, apart from the
  next by twice the room between two buttons of a group - a header bar
  draws no shared background - and the actions placed in overflow behind
  the bar's menu at the very end. An action with a picture stands on the
  bar as an icon, the way a header bar's buttons stand, its title its
  tooltip and its name to assistive technology; one that shows its words
  stands with its picture before them, as libadwaita's button content
  does; one whose picture the application does not hold shows its title,
  and the overflow's menu shows titles. So the bar's own buttons never read
  as one more choice of a tabbed view's switcher beside them. An action
  that destroys something is libadwaita's `destructive-action` button on
  the bar; in the overflow's flat menu that class writes its words in the
  white meant for its red fill, so its words there take the theme's
  `@destructive_color`, as libadwaita writes a destructive answer of an
  alert;
- the way back, the bar's own back button, which libadwaita shows while the
  page has one below it and the page does not refuse it;
- no bar at all, for a page that hides its navigation bar;
- a split view's sidebar toggle, at the start of the bar of the page the user
  sees in its detail, pressed in while the sidebar shows;
- for a tabbed view, its switcher beneath the bar, under the chosen tab's
  page's chrome;
- the bar's colours: a page's header bar is painted in the colours its path
  declares, the nearest arrangement's (`barColors`), and what stands on it -
  the title, the way back, the toggles and the switcher's captions - in its
  foreground, else light on a dark band and dark on a light one ([words on
  a painted band](../../host/layout.md#words-on-a-painted-band)), as a class
  of the host's style sheet ([a widget's own
  box](drawing.md#a-widgets-own-box)); a bar no arrangement colours keeps
  the platform's.

The page the user sees names the window, for the desktop's switcher and dock;
a page with no title leaves the window's own.

## A navigation stack

A navigation stack is libadwaita's `AdwNavigationView`, each page in a
navigation page holding its frame. A path one page longer pushes the page, one
shorter pops to where it now ends, any other change replaces the stack - each
as the program's move, whose `popped` is its echo. The user's back - the back
button, the swipe, Alt+Left, the mouse's back button - pops in GTK first, and
the stack's `popped` then tells the path how many pages remain; a path that
does not follow is put back by the next render. The host's own way back is
the window's (`WindowPresentation.wayBack`): a top page that refuses it - no
back button - offers none. A page is pushed named as the
tree names it, or after the application until it does: libadwaita asks every
page for a title.

## A split view

A split view is libadwaita's `AdwOverlaySplitView`: the sidebar beside the
detail, and over it in a window narrower than 400sp - a breakpoint of the
window's, as GNOME's applications collapse theirs, the window then saying the
smallest size GNOME's windows keep. Whether the sidebar shows is StateUI's
binding: the program's write shows or hides it, and GTK's own change - a click
beside a sidebar over the detail, a swipe - and the detail's toggle report
back into it. The split's first room wider than nothing decides, by the host
layer's rule ([a sidebar on the first room](../../host/pages.md#a-sidebar-on-the-first-room)):
wide enough for both panes - 400sp at the desktop's text scale - it opens
with the sidebar shown, said once GTK has laid the frame out.

A closed sidebar is out of reach: libadwaita slides it past the split's edge
and keeps it shown there, where Tab and a screen reader would still find
what it holds. While it is closed the sidebar takes no focus - GTK's
`can-focus` keeps the focus out of a widget and everything in it - and is
hidden from assistive technology; both come back as it shows, so its slide
stays libadwaita's own.

The sidebar stands on the split view's material for its place ([a sidebar's
material](../../host/pages.md#a-sidebars-material)) - over the detail where
the split is collapsed, beside it otherwise - as a fill class of the host's
style sheet on the sidebar's widget, moved as the split's `collapsed` turns;
none leaves libadwaita's own sidebar, which over the detail is a pane of its
own. GTK blurs nothing inside a window, so a blur stands as its colour.

## Tabs

A tabbed view is a `GtkStack` of its tabs, each named by its page's title,
and its `GtkStackSwitcher` - the captions joined in one control - stands at
the start of a bar of its own beneath the header bar of the frame the tabbed
view stands in, painted as the header bar is. The header bar keeps its room
for the title - the host layer's: tabs on a stack name it by their own
title, else by the page beneath - the chosen tab's actions and the window's buttons,
and the tabs' bar scrolls them across where the page is narrower than they
are. The
switcher's choice is the user's: the pages hear it, then the selection's
state, and the header bar follows the chosen tab whether or not the
application renders again. Over a tab that is a stack the stack's bar is the
one (the host layer's `showsTheStacksBar`): the tabbed view's frame shows no
header bar, and the switcher - with a split view's sidebar toggle - stands
beneath the header bar of the stack's page the user sees, moving with it as
pages come and go.

A tab shows its caption alone. The switcher draws a page's icon in place of
its caption, never beside it, so a tab's picture is not given to it.

## Menus

A menu is GTK's model of one: the host layer's walk of its entries
([menus](../../host/pages.md#the-menus-of-a-path)) as a `GMenu` - the
entries between two separators a section, a submenu a link - each item an
action of a group the menu hands the widget it stands on, which GTK runs only
while it is enabled; a submenu out of reach is one whose tracking action is
not. GNOME's menus show words alone: no picture beside them, no entry marked
as destroying something.

A view's context menu is a `GtkPopoverMenu` on the view's widget, opened where
the user clicks with the secondary button or holds a finger, at that point; a
panel presents it as it lays out. A menu of no entries is none.

A desktop of header bars has no menu bar: the menus a page's path declares
stand in the main menu at the very end of its header bar - GNOME's
`open-menu-symbolic` button - each a submenu holding its entries, joined by
the host layer's rule. A page that declares none shows no main menu.

## Sheets

A page a window's modal stack presents is a sheet: libadwaita's `AdwDialog`
over the window, each over those before it, the last on top - a page in a
frame of its own, whose header bar holds the dialog's close button, or an
arrangement whose pages carry theirs. A sheet asks for 560 by 480, which
libadwaita fits to the window, rising from its bottom where the window is
narrow. The user's close - Escape, the close button - takes the top sheet
away through the host layer's way back, the modal stack told how many remain;
a sheet the program takes away closes and tells nothing. A sheet starts a path
of its own ([the visible path](../../host/pages.md#the-visible-path)): it
wears no bar of what stands around it, and names the dialog by its page's
title.

## The window's overlays

What a window lays over everything it shows - the overlays the pages on its
visible path declare, then the inspector docked in it - are overlays of the
`GtkOverlay` the window's content stands in, the first lowest: over the
whole window, header bars included, which the inspector's own layout leaves
free where it docks at a side. Each holds a layout that lets input through,
so a click beside what it holds goes on to the page under it
([listening](input.md#listening)). The window takes the overlays out and
lays them again when the list it is told changes.

## A page's phases

A page hears its phases as the host layer tells them ([a page's
phases](../../host/pages.md#a-pages-phases)); GTK supplies the tab the user
chose and whether the sidebar shows, which the layer reads to know what an
arrangement shows.
