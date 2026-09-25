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
  the bars' colours paint the chrome.

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
