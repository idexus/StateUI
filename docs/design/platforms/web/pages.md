# Pages on the Web

The Web host shows an application's pages as a web page shows its own: one
window, its bar across the top, and the arrangement of pages in the room
beneath it. What the bar shows is the host layer's `WindowChrome`
([pages](../../host/pages.md)); only its look is the page's.

## The window's bar

The bar is a `<header>` with the role of a toolbar, over the window's room. It
leads with the split view's toggle where the window shows a split view, the
way back where the visible stack offers it, and the leading actions the
visible page's path declares; the page's title stands in its middle, and the
trailing actions and the overflow at its end. Each action is a button with
its picture, its words beside it where it shows them, its name for assistive
technology and its tooltip. The bar's colours are the arrangement's, written
as CSS variables the stylesheet paints it with; without them the bar is the
page's surface, translucent over what scrolls beneath. The same title names
the browser's tab.

Beside a sidebar shown, the bar stands in two parts as wide as the split
view's columns: over the sidebar the application's name, mark and the line
under it, centred, with the toggle at the sidebar's edge; over the detail
the rest, its title centred over the detail. With the sidebar hidden, or over
the detail as a drawer, the name stands in the sidebar alone, and the title
is centred over the whole bar. Without a split view the name leads the bar,
and a page's title the same as the name is not said twice. The parts follow
from the split view's `data-sidebar`, which the bar repeats, and the page's
width, so no measuring moves them.

The page is one window: an application's second window has no place of its
own in it.

## A split view

A split view stands its sidebar in an `<aside>` beside the detail. Where the
page is narrower than 900 pixels the sidebar stands over the detail as a
drawer, with a shade over the rest that takes it away when tapped; the
toggle in the bar shows and hides it either way. Shown or hidden is the
tree's, else the user's, and the user's choice is heard by the host layer
(`sidebarShown`), which tells the page and the state. The first room the split
view is given decides once (`SidebarAdaptation`): at least the breakpoint
wide, the sidebar shows, as the user's.

Beside the detail the sidebar moves in and out: its column opens or closes
while the sidebar slides with the column's edge, both on one timing, and the
bar's parts travel with them - the toggle to the bar's edge, the title to its
middle, the name fading - its column widths stated in pixels in both states,
so the browser moves them between the two. The first room's decision, and
the tree's first word, stand at once: what the user first sees is the page
itself (`data-moves`). Where the user asks for less motion nothing moves.

## Tabs

A tabbed view is a `<section>`: a strip of its tabs' names over one cell its
pages share. Each name is a button with the role of a tab, the chosen one
selected; the chosen page shows and the others stand beside it covered, kept
as they stood, scrolled where the user left them. Which tab shows is the host
layer's (`TabChoice`): the tree's word, until the user chooses another - and
the user's choice is heard by the host layer (`tabChosen`), which tells the
pages and the state, and the bar follows the page the user now sees.

## A stack

A stack holds its pages one over another in one cell, the top one shown:
those beneath stay in the page, hidden, where the user left them - scrolled
as they were - and a page pushed arrives with a short rise. A covered page is
hidden over its own inline `display`, the stylesheet's rule being
`!important`: an element's own style wins over a rule otherwise. The way
back is the bar's: the host layer goes back (`HostRuntime.goBack`), and the
stack's path hears how many pages remain.
