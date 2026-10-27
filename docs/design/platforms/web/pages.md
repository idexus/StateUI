# Pages on the Web

The Web host shows an application's pages as a web page shows its own: one
window, its bar across the top, and the arrangement of pages in the room
beneath it. What the bar shows is the host layer's `WindowChrome`
([pages](../../host/pages.md)); only its look is the page's.

## The window's bar

The bar is a `<header>` with the role of a toolbar, over the window's room -
none where the page the user sees stands with no bar (`showsNavigationBar`),
the room then the window's whole height. It
leads with the split view's toggle where the window shows a split view that
offers it (`showsSidebarToggle`), the
way back where the visible stack offers it, and the leading actions the
visible page's path declares; the page's title stands in its middle - or the
view the page, or else its stack, declares in its place (`chromeTitleView`),
at its own size, the same view for as long as it is declared - and the
trailing actions and the overflow at its end, each group of actions together
on a glass of its own, apart from the next. Each action is a button with
its picture, its words beside it where it shows them, its name for assistive
technology and its tooltip; a setting is a two-state button
(`aria-pressed`), tinted in the accent while on, and a
`menuitemcheckbox` behind the overflow. The bar's own buttons - the toggle, the way
back, a sheet's close, the overflow - are named in the library's words, in
the user's language (`ChromeWords`). The bar's material and colors are the
arrangement's, written as CSS variables the stylesheet paints it with - a blur
its backdrop filter under its color, glass drawn as its blur; without them the
bar is the
page's surface, translucent, blurred and deepened over what lies behind it,
the room running under it ([the safe area](#the-safe-area)). A clear bar
paints nothing: a page resting below it shows as it is, the same color as
the page under it, and what scrolls under it softens - blurred at the top,
the blur fading out toward the bar's bottom edge (`data-clear`). No line
stands under the bar. The same title
names the browser's tab, beside the site's name ([The tab](#the-tab)).

A page's title stands with the line under it the page says (`barSubtitle`).
Beside a sidebar shown, the bar stands in two parts as wide as the split
view's columns: over the sidebar the title area its page names the
application with - its title, else the application's name, and the line
under it - at its start, in line with the rows under it, the sidebar's
part's actions - its start's at its leading edge, its end's and their own
More before the toggle - and the toggle at the sidebar's edge; the name gives
way before them, cut short with an ellipsis, and the part fits itself before
the detail's does (`BarFit`), the groups it has no room for behind its More. Over the
detail the rest, its title centered over the detail. An item moving between the parts keeps its button and slides there from
where it stood, on the sidebar's slide - at once where the user asks for less
motion. Over a drawer the part is as wide as what it
holds, under the drawer while it is open. With the sidebar hidden, or over
the detail as a drawer, the name stands in the sidebar alone, and the title
is centered over the whole bar; a page's title the same as the name is not
said twice. Without a split view the bar names the page alone. The parts follow
from the split view's `data-sidebar`, which the bar repeats, and the page's
width, so no measuring moves them.

The bar shows no application's mark: it names the page and the application
in words, and the browser's tab shows the site's own icon.

The page is one window: an application's second window has no place of its
own in it.

## A bar's items in the application's look

What the application says of a bar's item - its `background`, its outline's
`shape`, `stroke` and `lineWidth`, the room inside it (`padding`), its words'
color and font - stands on the item's own element as inline style over the
stylesheet's look for the bar's buttons (`toolbarStyle`): a button's box and
words (`showBarLook`, the same box a control draws, `WebBox`, and the words a
text draws, `WebCSS.font`), a group's box on its group's element
(`WebBarGroup`), with the room between its buttons its `gap`. The room
between the bar's groups and its own buttons is the bar's
`--stateui-bar-spacing` (`toolbarSpacing`), else the stylesheet's. What it leaves unsaid
stays as the stylesheet has it, so an outline alone keeps the stylesheet's
fill and its light under the pointer; a background said replaces both, and
the item's own `.pointerOver` state says how it lights. A button saying the
room inside it is as large as its picture and words and that room, as a
control is: the stylesheet's least size for a bar's button (42) stands only
where it says none.

The states are StateUI's: the button and the group tell the item's element the
pointer coming and going and a press beginning and ending - a finger hovering
over nothing ([the host layer's rule](../../host/runtime.md#a-finger-hovers-over-nothing))
- where it declares a state that follows them, and the differ describes the
item again in that state's values.

A lone item's own group is a group like any other, and wears the group style.
The bar's own buttons - the toggle, the way back, More, a sheet's close -
stand as a lone item does, in the group style's box under the style every
`ToolbarButton` wears, asked of StateUI in the state the user puts each in
(`BarOwnButtons`). The words of the bar's
buttons stand at a size in `rem`, so the user's own text size scales them as
it does every word the page shows.

## A bar with no room

The bar measures itself ([a bar with no room](../../host/pages.md#a-bar-with-no-room)):
each standing `BarFit` tries is laid out on it, and the relay says whether its
buttons and title stand over one another or beyond its edges (`crowded`). A
title between the actions takes the bar's middle column, the columns around it
as wide as what they hold (`data-crowded`), its words in the middle of it; one
left less than a few letters' room - 72 pixels - stands hidden
(`data-squeezed`), as an ellipsis alone says nothing. The bar stands its groups
again as the window's width changes, and as the part before the title moves
with a split view's sidebar.

A standing tried is measured as it stands at once, so nothing it changes
moves: a bar whose columns moved to a standing would be measured on its way
there, find another, and stand the two in turn, frame after frame. Only the
widths of its first and last columns move, with the sidebar.

## The safe area

The page is drawn under a phone's status bar, notch and home indicator
(`viewport-fit=cover`), and the stylesheet passes what stands over each edge
down as `--stateui-over-top`, `-left`, `-bottom` and `-right`, from
`env(safe-area-inset-*)` ([the safe area](../../host/layout.md#the-safe-area)).
The window's bar is a material over the top of its room, as the platforms'
glass bars are: it reaches under the top of the window, its words clear of it
and of the sides, at a height of its own, and the room runs under it, the
bar's depth the top of the room's safe area. A row of tabs stands below it,
its pages clear of nothing at their top; a card sheet stands clear of all of
it in the middle, a phone's sheet from the bottom keeps the bottom and the
sides. A page stands its content clear of what is left by its own padding -
what stands in it then has nothing over that edge (`data-pads`) - but on an
edge where the content lets itself under (`SafeAreaArithmetic.under`), where
the content's scroller takes that padding instead, its rows scrolling under
the bar's material, the first and the last clear of it. The overlays stand
clear of all of it. A view's frame is told from the corner below the bar
(`WebRenderer.contentBox`), where the room's safe area starts.

## The color under the window

The page under the window wears the window's color, where the window is one
opaque color (`WebWindowController.pageColor`): `--stateui-page` on the
document, which `body` and the loading screen wear before the page's own
surface. Safari on an iPhone - and a page added to the home screen - takes
the color above the page and around its bars ONCE, at the first paint, from
what stands there then; the window's color comes with the program after it.
So the relay
keeps the color in the viewer's browser (`localStorage`, one an appearance:
`stateui.page-color.light` and `.dark`, as the system's stood when it was
written), and `index.html` wears it before anything is drawn: from the second
start the bars are the window's color; the very first shows the page's own.
A translucent window, a blur or the platform's own keeps none - the page
under it would show through. A per-viewer convenience: nothing depends on it,
and a browser keeping nothing paints as before.

## The tab

The tab names the page the user sees beside the site's name the page's head
gives - its `application-name`, which an application writes in its
`Page/head.html` - as "Home - StateUI": the site's name tells one of the
user's tabs from another, the page's which place of the site it shows. A page
with no title, or one named as the site, names the tab as the site alone.
Where the head gives no name, the tab is the page's title alone, so a page
the library lays out by itself reads as its window's title. The head's
`<title>` is the page's name before the module runs and what a crawler that
runs no script reads; it is often a sentence, too long to stand beside every
page's title.

## The browser's way back

The browser's own way back - its button, a swipe on a phone - goes back a
step in the window, as the bar's does: while the window offers a way back
(`WindowPresentation.wayBack`) one entry of the page's own stands on the
browser's history, and the browser taking it back takes the window a step
back; where a way back still stands after it, the entry is put back. Where
the window offers none any more - the bar's way back, the program's own -
the page goes back over its entry itself, and does not take that for the
user's - only where the browser stands on that entry, so the page never takes
the user off the site from one it did not put there. One entry, never one a
page: a page the application pushes is the
tree's, and the browser could hand none of them back on its way forward.
A window hears the history move until it closes, and closing lets that
listener go on both sides of the relay. The browser tells a going back
after it is asked, so a window closing before the page's own going back
over its entry is told leaves it to the page: the next window to hear the
history move takes it as the page's, not the user's - a window opened at
once after another's way back went is not taken a step back by it.

A window closing takes its sheets away first, the top one first: each is a
modal dialog of the page's, which would hold every page after it still.

## Overlays

What a window lays over its pages - the overlays its pages declare and the
library's own, in the host layer's order (`WindowPresentation`) - stands in
one layer over the window's room, each overlay the room whole, the first
lowest. A touch beside what they hold goes on to the pages: the layer, each
overlay and the layout in it take no touch of their own
(`pointer-events: none`), what they hold does - a layout letting touches
through gives that back to its children only where a child does not let
them through itself.

## A popover

A view's popover is the document's own (`popover="auto"`): the popover
element's layout itself, at the start of the body, placed under its anchor
and kept in the window by the relay's `show_popover`. A click beside it or
Escape takes it down - the browser's light dismissal - which the host hears
from `toggle` and tells as the user's while it wants the popover shown. The
layout's grid is written on the element itself, so its look hides it while
it is closed with `display: none !important`.

## Menus

A menu is the host layer's walk of its entries (`MenuEntry`) as a popover
over everything (`popover="auto"`): an item a button, a separator a line, a
submenu a button opening its own popover beside it, inside the one it stands
in so that both stay open. A click beside it or Escape takes it down - the
browser's own light dismissal - and so does choosing an item, which then
hears it chosen. An open menu holds the keyboard: the page's own keys - a
view taking the arrows, Enter or Escape - pass it by, so its arrows go
through its items whatever the page takes, and as it goes the browser gives
the keyboard back to what held it. A popover is kept in the window whole,
under what opened it, above where there is no room under, at the pointer
for a context menu.
Its entries stand in a grid of rows each as tall as it is: WebKit spreads a
grid held to a maximum height over its rows, and a menu of three stood the
window's height in Safari.
A context menu a held finger opens is the page's to close: that finger went
down before the menu stood, so its lift comes beside the menu, and the
browser's light dismissal - a press and a release beside it - closed it the
moment it lifted (Safari on a phone). Opened by a hold, the menu stands as
`popover="manual"` while it is open and closes on a press beside it or
Escape, the relay's own; the view it belongs to chooses none of its words by
the hold and shows no callout of the browser's (`data-holds-menu`).

A bar's action that is a menu opens its entries under it. The actions
standing behind the bar - its overflow - and the menus the page's path
declares stand in one menu at the bar's end, the overflow first. A view
whose element declares a context menu opens it as the user asks: a right
click, or a finger held still the host layer's hold (`HandReading.hold`) -
still meaning no farther from where it pressed than a finger goes before
its press is a drag (`WebPress.finger`), so steps each too short to count
still add up; its entries are read as they stand then.

## The Edit menu

A page keeps no Edit menu of its own, so a menu joining `StandardMenu.edit`
behind the bar's More holds the host layer's entries (`ChromeMenus.editing`).
The page keeps the field the user last typed into (`focusin` on an input, a
text area or editable words), since the menu takes the focus, and each entry
hands it back and does its act there (`stateui_web_edit`): undo, redo, cut,
copy and delete through the document's own commands - a cut and a copy want
the user's click, which choosing the entry is - select all through the
field's own, and paste through the clipboard's API, which the browser opens
only where the user allowed it.

## Sheets

A page a view presents stands on a sheet: the browser's own modal
`<dialog>`, which takes the focus and every input until it closes and shades
the page under it - a card in the middle, from the bottom where the page is
narrow. The dialog stands on its window's background ([a page's
ground](../../host/pages.md#a-pages-ground)): an opaque color as its own, any
other laid over the browser's dialog background as an image layer; the
browser's own where the window says none. A sheet has no bar of its own: a stack in it brings one
(`bringsABar`), the chrome of the sheet's page (`WindowChrome`), its way back
the window's (`WindowPresentation.wayBack`), ending with a button closing the
sheet unless the page says it offers none. Escape is the user's dismissal as that button is: the browser does not
close the dialog itself, false is written onto the top sheet's state, and a
sheet closes as the tree lets its page go. The last sheet's
title names the browser's tab.

## Questions for the user

An alert, a confirmation, a choice of actions and a prompt are the
browser's modal `<dialog>` too: the title, the message, a prompt's field -
its keys and help the host layer's traits (`InputTraits`) - and a button
for each answer, a choice's actions one under another and its dangerous one
marked. A choice's cancel button answers its caption, as a choice of its
own; Escape answers nothing chosen, as cancelling does where the question
can be cancelled, and dismisses an alert. The dialog is held by the acts' part of
the page until it is answered: its buttons hold it no more than weakly, and
a question nobody held would never answer.

## A split view

A split view stands its sidebar in an `<aside>` beside the detail, apart from
it by a divider down its edge - from the bar's top, whose part over the
sidebar carries the same line, to the window's foot - and over it: the detail
holds its children's z-index to itself (`isolation`), so what a page draws
past its column - a run of cards fanned outward - passes under the sidebar.
Where the
page is narrower than 900 pixels the sidebar stands over the detail as a
drawer, with a shade over the rest that takes it away when tapped; the
toggle in the bar shows and hides it either way. Shown or hidden is the
tree's, else the user's, and the user's choice is heard by the host layer
(`sidebarShown`), which tells the page and the state. The first room the split
view is given decides once (`SidebarAdaptation`): at least the breakpoint
wide, the sidebar shows, as the user's.

The sidebar stands on the split view's material for each place ([a sidebar's
material](../../host/pages.md#a-sidebars-material)): the split view sets a
variable for each - `--stateui-sidebar-ground` and `-filter` beside the
detail, `--stateui-sidebar-overlay-ground` and `-filter` over it - which the style
sheet reads in that place, so a page turning narrow moves the sidebar to the
other with no word from the host. A blur is a backdrop filter under its
color. Over the detail a color is laid over the page's raised surface
(`--stateui-sidebar-overlay-layer`), so a clear window still leaves the sidebar
opaque. None is the page's own: beside the detail the window shows through,
a breath darker - lighter in the light theme - as a desktop sidebar lets it
through; over the detail the page's raised surface. The
window's bar, over a sidebar shown beside the page, stands its part over the
sidebar on the same ground - the window hands the bar the split view's
variables as it writes its chrome - so the sidebar and the bar over it read
as one column, the bar's title part over the detail on the window's.

Beside the detail the sidebar moves in and out: its column opens or closes
while the sidebar slides with the column's edge, both on one timing, and the
bar's parts travel with them - the toggle to the bar's edge, the title to its
middle, the name fading - the widths of its first and last columns stated in
pixels in both states and registered as lengths, so the browser moves them
between the two, the columns between following. The first room's decision, and
the tree's first word, stand at once, the bar's parts with them: what the user
first sees is the page itself (`data-moves`, the split view's and the bar's).
Where the user asks for less motion nothing moves.

## Tabs

A tabbed view is a `<section>`: a strip of its tabs over one cell its pages
share. The strip scrolls across alone, never down - its line drawn inside it,
so no tab's underline reaches past it for a finger to drag it by. It wears
the color of the bars on its path (`barColors`), and no blur under a clear
one - the window bar's own look where nothing is said - so under the window's
bar it stands as one with it; its words, as the window bar's, are the color
the tree writes, else light on a dark band and dark on a light one
(`BandWords`). Each tab is a button with the role of a tab - its page's picture, where
it has one, beside its name - the chosen one selected; the chosen page shows and the others stand beside it covered, kept
as they stood, scrolled where the user left them. A covered page is laid out
unseen - it takes no touch, no keyboard and no assistive technology - so a
page sized by its own frame knows it before it shows, rather than standing a
frame at no width when it does. A view says where it stands only where the
browser lays it out, so nothing covered says it stands nowhere. Which tab shows is the host
layer's (`TabChoice`): the tree's word, until the user chooses another - and
the user's choice is heard by the host layer (`tabChosen`), which tells the
pages and the state, and the bar follows the page the user now sees.

## A stack

A stack holds its pages one over another in one cell, the top one shown:
those beneath stay in the page, hidden, where the user left them - scrolled
as they were - and a page pushed arrives with a short rise, one popped back
to returns with a short fall, as the host layer says the path changed
([a path that changes](../../host/pages.md#a-path-that-changes)); at the
end of either every view the tree reads says where it stands: the rise moves the page on
the browser's own animation, which no observer of the page tells, so a frame
read during it stood 6 points low until something else moved. A covered page is
hidden over its own inline `display`, the stylesheet's rule being
`!important`: an element's own style wins over a rule otherwise. The way
back is the bar's: the host layer goes back (`HostRuntime.goBack`), and the
stack's path hears how many pages remain.
