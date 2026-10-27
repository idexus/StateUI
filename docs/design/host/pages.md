# Pages on every host

How the host layer reads an application's pages the same way on every host:
what an arrangement shows, the phases its pages hear, a tabbed view's choice,
a sidebar's first room, the way back, what stands in a slot, and the one
chrome a window composes. A host turns each into its toolkit's calls and
supplies two facts only it knows: the tab the user chose, and whether a split
view shows its sidebar on screen (`NativeElement.chosenTab`, `showsSidebar`).

## The page path

An arrangement shows one page at a time on its path: a stack its top page, a
tabbed view its chosen tab, a split view its detail - and, while it shows,
its sidebar beside it (`MountedElement.shownChildren`). The visible page is
found down that path, and so are the stack and the tabbed view around it. The
tab shown is the one the user chose, else the one the tree says, kept within
the tabs; the sidebar shows as it stands on screen, else as the tree says.

A tabbed view's tabs stand in its window's row where it is the first tabbed
view down the window's stacks and split view details - the page the window
shows under its sheets (`tabsStandInWindow`): one in a
sidebar, in a tab of another, in a sheet or inside content keeps a row of its
own. It is read from where the tabbed view stands, each time, so a view moved
elsewhere keeps no word it once had. A split view's sidebar and a modal
stack's root are their first children as the patch writes them, so the answer
is already right while the tree that holds the tabbed view is still being
made.

## A page's phases

A page tree shown hears it in its turn (`setPagePresented`): a page is
appearing, and navigated to where it came by a move; hidden, it is navigating
from, disappearing and navigated from, the move's words around the
disappearing. An arrangement hands it on to what it shows: a stack to its top
page, as a move where its window came; a tabbed view to its tab and a split
view to its detail and its shown sidebar, as appearances. Each phase is
rendered before the next is heard.

When what an arrangement shows changes - a push or a pop, another tab, the
sidebar shown or hidden - what stopped showing leaves first, then what started
showing arrives (`reconcilePresentation`); on a stack it is a move. The tree
does this itself after each patch of an arrangement shown, and the host layer
after the user's own choices (`HostRuntime.tabChosen`, `sidebarShown`),
before the state the choice carries hears it. A choice is an entry from the
toolkit: it ends in a turn wherever the phases it queued wait, so a tab view
with no selection bound tells its pages at once, on every host.

A window's page - its top sheet, else its arrangement - hears it is shown as
the window presents it, and the one before it that it is not: a move where a
sheet came or went, the window's coming otherwise (`WindowPresentation`).
The window then hears that it was made, before the host shows it.

## A page that leaves the tree

A page shown that leaves the tree - its window closed, by the user or by the
tree, its stack's path cut by the tree - hears that it disappears, then that
it is destroyed, the same on every host: appearing and disappearing go in
pairs. The core does it as the element leaves (`Differ.forget`), since only
it still holds the page's handlers then: by the time a host meets the patch
that takes the page away, nothing of it answers. The core knows a page
stands shown by the phases the host told it (`Differ.heard`); a page that
listens for its disappearing alone hears its appearing too, unseen, so the
host tells it.

## Tabs

A tabbed view's choice (`TabChoice`) is none until the tree or the user makes
one. A tab the tree asks for anew is chosen, so the application can move the
user; the same tab asked for again changes nothing, so the user's own choice
is not argued with. The user's choice stands where it is another tab that
exists, and says which tab showed before it. The tab shown among the tabs
there are is one answer for the view and its row alike: the chosen one while
it is there, else the last there is (`shown(among:)`).

## A sidebar on the first room

A split view's one adaptation (`SidebarAdaptation`): the first room it is
given wider than nothing decides once whether its sidebar shows - it does,
said as the user's, where the room is at least the platform's own breakpoint
and it was hidden. After that the user and the application decide - and a
host measures the room for it no more (`decided`), so a render reads no
layout for it. The breakpoint is each platform's, a host's parameter.

## A sidebar's title

A sidebar's page names the sidebar's own bar, where a host gives the sidebar
one; a sidebar's page that says no title shows the application's name there,
as a sidebar stands under it (`barTitle(applicationName:)`) - the same for a
page at the root of a stack in the sidebar. Any other page that says no title
shows none.

## A sidebar's material

A split view says two materials for its sidebar: what it stands on beside the
detail (`sidebarBackground`) and what it stands on while it slides over the
detail (`sidebarOverlayBackground`). A host whose sidebar can stand over the detail
knows which place it stands in - a drawer, an overlay pane, a collapsed
split - and asks the split view for that place's material
(`sidebarMaterial(over:)`); a Mac sidebar stands beside the detail alone. An
empty material is the platform's own there. Beside the detail the platform's
own lets the window through, as a desktop sidebar does; over the detail it is
the window's background laid over the platform's drawer or overlay surface
([a page's ground](#a-pages-ground)), the platform's surface alone where the
window says none - so a clear window still leaves a sidebar over the page
something under its words. The sidebar page's own
background still paints the page on top. A split view saying either material
gives its sidebar to the application to paint (`paintsSidebar`): a host whose
platform draws a sidebar's material of its own leaves it out then.

## Where a sidebar stands

The place a host stands a sidebar in for the room - over the detail or
beside it, by the platform's own breakpoint - is the application's to hear
(`sidebarOverlays`): a sidebar row closes a sidebar over the page once the
user has chosen and leaves one beside it open. The place is a layout's
answer, as a frame is, so a split view driving it is followed as an element
whose frame is read (`readsOwnFrame`), and the host says its place with the
frame once laid out (`reportSidebarOverlays(_:in:)`) - on the display's
frame after a layout, never while a patch applies. The host layer writes
the state only where the place, or the state it drives, changed. A Mac
sidebar stands beside the detail alone, so it says beside.

## The way back

A window's way back (`WindowPresentation.wayBack`) takes the top sheet first:
its own stack's top page where it can go back, else the sheet itself; with no
sheet, the arrangement's stack. A stack can go back where it holds more than
one page and its top page shows its bar and its way back. Going back tells the
stack it is one page shorter, or writes false onto the top sheet's state
(`HostRuntime.goBack`). Sheets the user took away together have their states
written in one transaction, rendered once: a render between would ask again
for a sheet already gone, which a toolkit shows again.

## A path that changes

A navigation stack's pages change one way on every host (`PathChange`):
pages joining on top of every page that stays are a push, the last of them
arriving, however many join; pages taken from the top are a pop, one move
back to the page on top of those that stay, however many go; anything else -
a page under the top replaced, a stack's first pages, a stack emptied - is a
replacement, which does not move. No change moves for a user who asked for
less motion. A host moves its toolkit's way: UIKit's navigation controller,
libadwaita's navigation view, WinUI's entrance of a panel's children,
Android's transitions, the browser's animations on the page. AppKit changes
the page without motion, as the Mac's own applications do in a window.

## A page's ground

A page is an opaque surface the size of its room, so a page sliding over
another - a push, a pop - hides the one under it rather than mixing with it.
It stands on its own background where it paints one, else on the one the
nearest arrangement on its path declares for its pages - on past a sheet to
the view presenting it, as a bar's look; a sidebar's page on its sidebar's
material (`pageBackground`) - else on the color its host painted its
toolkit's window in - the window's color, or the platform's own ground where
the window says none: UIKit's system background, Android's theme background.
An arrangement draws no background of its own (`drawnBackground`): when it
changes, its pages are drawn again (`pagesGroundedAnew`), and a page made
under it presents the background it never wrote. A window whose color
changes stands every page in it (`MountedElement.pages`) on the new one.

A surface laid over the page - a sheet, a sidebar sliding over the detail -
stands on the window's background where the application says nothing of it
(`overlaidGround`), so the window's color reaches every surface the user
reads on. A host lays that background over the platform's own surface there -
its dialog, its drawer - so a clear or tinted window still leaves the surface
opaque under its words; a blur stands where the platform blurs inside a
window, else as its color. A window saying no background leaves the
platform's own surface alone. A window whose background changes grounds its
sheets and its split views (`splitViews`) again.

## Sheets

A window's sheets are the pages its views present
(`MountedTree.presentedSheets`), in the order they showed: a sheet's page is
made as it shows, so one presented from beneath stands over the top one. They
follow by one rule (`SheetChange`): the
sheets shown that stand as asked, counted from the bottom, stay; the rest
leave, the top first; and each page asked for after them comes over the one
before. A sheet swapped beneath one that stays takes every sheet above it
along, so the stack's last page is always the one on top. A host says only
whether a sheet shown stands as asked - the same page, and on GTK and the Web
the same native page - and presents and dismisses as its toolkit does.

## A sheet's size

On a wide screen a sheet stands as large as its page asks (`SheetSize`): the
page's natural size for the most width the platform gives a sheet, held
between the least and the most of that room (`SheetRoom`) - a page taller than
the most scrolls inside it. A stack, tabs and a split view ask nothing, as
their pages come and go and a sheet resizing with each would jump; nor does a
page holding a view that takes the room it is given - a list, a phase layout,
a map, a web view (`NodeType.roomTakingTypes`). Those stand at the room's
standard size, no larger than its most. Each host gives only its room - the
platform's dialog bounds and the window around the sheet - and its measure of
the page; on a narrow screen a sheet rises from the bottom as the platform's
own does, and the rule is not asked.

## An anchor stands as what it holds

A composed view's anchor has no view of its own (`viewlessTypes`): what it
holds stands in its place. A layout places the anchor's view among its own
children (`arrangedChildren`), so its layout values, its drawing and its
replacement are that view's; the element placing it is the one around the
anchor (`placingParent`). The same list is an arrangement's pages, so a
window, a stack, a tab or a split view holding an anchor shows the
arrangement or page it holds, and every walk down the page path goes through
it. A walk up the path steps through an anchor as through a stack. What the
anchor presents - a sheet, a popover - stands by the view it shows
(`presenter`).

## Slots

A title view is a slot. What stands in it is the first element under the
slot that shows a view of its own (`chromeTitleView`); an element with no
view of its own is shown by the first under it that has one
(`presentingElement`).

A declaration - a toolbar, a title view, a menu bar, a context menu, an
overlay - is a child of whatever element it is declared on, a page, a stack
or a button, and furnishes the chrome from there: no layout places it, and
no element with no view of its own is shown by it (`arrangedChildren`).
Every host lays out and flattens through that one list, so a title view's
field stands in the bar alone, measured by itself, and never also in the
page's room.

## The visible path

A page's chrome takes what is declared on its path (`declared`), but for its
actions, which are its own ([a page's actions](#a-pages-actions)): the slots of
each arrangement around the page, from the outermost in, then what the
page's own tree declares, in the tree's order. Each carries its level - the
outermost arrangement's 0, the page's own last. The path ends at the window
and at a sheet, so a sheet starts one of its own - and so does a split
view's sidebar, which is not on the path; a native
collection's items belong to no page. A page that goes takes its
declarations with it, and what the levels around it declare stands as it
stood: nothing is restored, because nothing was overwritten.

## A page's actions

A page owns its bar's actions: the groups its own tree declares
(`declarations`), none from the arrangements around it - a page pushed onto a
stack carries none of the page under it; the core declares none on a stack or
tabs. Under a split view the page stands under one part of the split view's one
bar (`splitBarPart`), which holds the split view's groups naming that part, the
page's own and those the other column's shown page names for it; a group's part
unsaid is its declarer's - a sidebar page's the sidebar's, a detail page's and
the split view's the detail's. While the sidebar is not shown, its part's
groups stand at the start of the detail's - behind its overflow those that
stood behind the sidebar's - or are gone where they hide with it
(`hidesWithSidebar`); a part said off any split view changes nothing.

A window's one chrome carries both parts (`WindowChrome`): the detail's from
the visible page (`actions`), the sidebar's from the sidebar's page
(`sidebarActions`) - none while the sidebar is not shown, its groups then
standing among the detail's. Each host stands the sidebar's part over the
sidebar natively: AppKit before the toolbar's separator tracking the sidebar,
the Web in the bar's part over the sidebar, WinUI on the head of the split
view's pane, as a Windows application's navigation pane holds its commands; a
host with a bar per column - UIKit, Android, GTK - shows each column's part
on its own bar.

One group is one background where the platform groups a bar's actions; an item
standing alone is a group of one. At each position - the start, the end, the
overflow - the groups stand by their `order`, then the outer at the edge -
first at the start and in the overflow, last at the end - by how far out their
declarer stands, the split view's furthest, a page's by its depth in the page's
tree (`ChromeActions`), then as declared. Each group behind the overflow is a
section of it (`overflowSections`). A bar that draws no groups takes the
trailing actions in reading order (`primary`).

## A bar button's menu

A `ToolbarButton` holds a menu as a `Button` does (`ButtonMenuElement`), and
the host layer reads both alike (`ButtonMenu`): how it opens - its click
where it has no click of its own, else an arrow of its own or held - whether
the arrow shows, and its entries. Each host makes the bar item its toolkit
makes for a menu: a menu item on AppKit's toolbar, a bar button with a menu
on UIKit - where a split stands as held, the bar offering no arrow part - a
submenu on Android's bar where the click opens it, else the action on the bar
and its menu behind the overflow, a flyout on WinUI's command bar, a menu
button on GTK's header bar, a menu button on the Web's bar. Behind the
overflow, a button holding a menu is a submenu under its words
(`ButtonMenu.inOverflow`): its own action first where its click is its own,
a line, then its menu's entries.

## A bar with no room

Where a platform's bar keeps its own items from crowding - UIKit's, Android's,
WinUI's command bar - it decides itself; a host that measures its bar itself
stands its groups by one rule (`BarFit`). Every group stands where they all
fit around the title in the bar's middle; else around a title taking the room
they leave; else the first groups in reading order, the leading ones first,
while they fit, and the rest behind the bar's More - each group's items apart,
ahead of what is placed there anyway - as the platforms' own bars keep their
first items on a phone. The host tries each standing on its bar in that order
and keeps the first that crowds nothing.

## Words beside a picture

A button and a bar's item show words and may show a picture
(`TextAndIconElement`); whether the words stand beside the picture is one
rule on every host (`TextAndIcon.showsText`): always where there is no
picture, else as the element says - unsaid, a button's words show and a bar's
item's do not, as each platform's bar shows its items' pictures alone. Words
left out still name the element to assistive technology, and a bar's item's
stand in its tip. A host puts the words on again where
`MountedElement.changesAccessibility` says, asking it of everything that
changed: the words, the picture and `showsText` are its registration's to
show, and asked of what is left over they never name the button.

## A bar's capsules

Where a host draws a capsule behind its bar's buttons, which buttons stand on
one is decided once (`BarCapsule.places(of:)`): the buttons of a group its
author declares stand on one capsule - its first at the start, its last at
the end, any between in the middle, one alone on the whole of it. A button
declared alone stands bare: StateUI stands it in a group of its own, which
says so (`ToolbarGroupContract.standsAlone`), and no host reads that from
the group's size. None behind "more" stands on a capsule. The host draws its
parts: WinUI's buttons ([a bar's
buttons](../platforms/winui/pages.md#a-bars-buttons)).

## A bar's items in the application's look

A bar's items - a `ToolbarButton`, a `ToolbarToggle`, a `ToolbarGroup` - wear
the look of a control where a host draws its bar itself: their own tiers,
`BarItemElement` (a style, a background, the pointer over it) and
`BarButtonElement` (a press), the room between a group's buttons
(`spacing`) and between the bar's groups (`toolbarSpacing`), and on each item
the box and the words they share with controls - `BorderElement`,
`PaddingElement`, `TextColorElement` and `FontElement`.
Which members those are is said once (`BarItemLook`): a host judges them all
alike, realized where it draws the bar (the Web), not planned where the bar is
the platform's own. The style and the states are resolved by StateUI before
the patch, as a control's are; a host shows the values an item holds and tells
its element the pointer and the press. Every group on the bar wears the group
style - a lone item's own too - so a button standing alone stands in the same
box a declared group gives its buttons.

## The menus of a path

The menu bar a page's window shows is composed from the menu bars its path
declares (`ChromeMenus`). A menu whose `.id`
was declared further out joins that menu, which its outermost declaration
heads - its caption, whether it opens - and places. The menus and the
sections inside a joined one stand by their declaration's `order`, then the
outer first, then as declared: a page's entries come after the window's as
a section of their own, parted by a line, and a page's own menus after the
window's. An entry whose `.id` an entry further out has stands in that
entry's place - its words, whether it can be chosen, its element - which the
others of that id leave; a section left with nothing is none. A menu whose
`.id` is a `StandardMenu` names the platform's menu of that identity
(`standard`), which the host joins by it, never by its caption.

## The bar a path declares

What an arrangement declares of the bar - its look: its material, its words'
color, its buttons' background and style - is a value on the arrangement
(`BarElement`), not a
declaration: each value of a page's bar is the nearest on its path, its own
arrangement included (`barValue`), so a stack further in paints its own bar.
What the bar says is each page's own ([a page's title
area](#a-pages-title-area)). The
path is the declarations' (`arrangementsAround`), but for a split view's
sidebar, which wears its own split view's bar - a split view's bar is both its
panes', so its colors paint a sidebar's own bar where a platform draws one
(`barArrangements`) - and nothing from around the split view. The look
crosses a sheet, which has no bar of its own: a stack in it brings one,
in the look of the bar over the view presenting the sheet unless the stack
declares its own, as the sheet's content is that view's; what the bar says
stops at the sheet ([the visible path](#the-visible-path)). The colors are
`barColors` - the material as a host that blurs nothing paints it - and the
material itself is `barMaterial`, for a host whose bars blur.

## A page's title area

A page says what its bar says of it, and nothing climbs the path: its title,
the line under it (`barSubtitle`, an empty one none) and its picture. The line
stands under the title wherever a bar shows the title - the chrome's line is
the page naming the window's (`WindowChrome.subtitle`). A split view's
sidebar's page names the application (`titleArea(applicationName:)`): its
title, else the application's name ([a sidebar's
title](#a-sidebars-title)), its line and its picture as the application's
mark. A host shows that title area where its platform's chrome names the
application over the sidebar - a desktop's title bar, the sidebar's own bar
(`WindowChrome.titleArea`, none where the window shows no split view).

A tabbed view's row wears the colors of the bar on its path too, and those
move on an element above it - a stack, a theme resolved again - that the
tabbed view never hears from. So where a host paints the row in the bar's
colors - UIKit and the Web - the row is painted with the
chrome: every time a window's chrome is shown again - a render touching it, a
frame moving it - the host paints each tabbed view its arrangements show
(`tabViewsShown`, through pages and arrangements of pages) in its
`barColors` as they stand.

## The overlays of a window

A window lays over what it shows the overlays declared along each page it
shows (`WindowPresentation.overlays`): the arrangement's visible path, the
outer under the inner, then each sheet's in turn, then the window's own - the
library's docked inspector - over every other. Each is one layer holding the
views declared together. A page that stops being shown - a page pushed over
it, a tab chosen away - takes its overlays with it; nothing is restored,
because nothing was overwritten.

## A popover

A view's popover is a slot of its own (`.popover`): its parent never lays it
out, and its host shows it in the platform's popover by the view its parent
shows (`presenter`) while `isPresented` is true, taking it away when it turns false - AppKit's
`NSPopover`, UIKit's popover presentation (a popover on a phone too), Android's
`PopupWindow`, WinUI's `Flyout`, GTK's `GtkPopover`, the browser's popover.
What it holds is a tree laid out on its own and sized by its content.
The platform taking it away while the tree asks for it is the user's
dismissal - false onto the state, then `isPresentedChanged`; taken away while the
tree no longer asks, it is the application's own write coming back, heard by
nobody (`MountedElement.reportDismissed`).

A popover shows only by an anchor standing in a window. One the tree shows
from the start, or in a page coming, may ask before that window is made: a
host whose windows are made once the render stands - AppKit, UIKit - lets it
wait (`waitForItsWindow`) and tries again after the render
(`MountedTree.takeWaitingPopovers`), each waiting popover once a render, so
one whose anchor stands nowhere costs nothing. Android, WinUI and GTK wait
for the anchor themselves - attached, loaded, mapped.

A popover written on a view whose branch flips stands on that view's anchor,
and the view it shows by is made anew: the host layer hands the shown popover
back after the render the same way (`showsAnew`), and every host shows it by
the new view - AppKit showing it again there, UIKit moving its source view,
Android updating its popup, GTK popping it down unheard and up on the new
widget, WinUI showing the flyout at the new target, the browser placing it
anew. Nothing of it is heard as the user's.

## The window's chrome

A window composes one chrome from what it shows (`WindowChrome`): the title
of the page that names it (`titledPage`) - the visible page, but tabs on a
stack are its last place and name the window by their own title, else by the
page beneath, never by a page they show, their pages naming their tabs alone;
a chosen tab that is itself an arrangement names the window as that
arrangement does - else the window's, else the host's own; the way back, in the
words the page beneath gives, else "Back"; the actions the visible page's
path declares (`chromeActions`) - none where the page hides its bar - each
showing its words beside its picture where it says so and always where it
has none (`showsActionWords`); the title view the path declares in the
title's place (`chromeTitleView`); the line under the title and the title
area its sidebar's page names the application with ([a page's title
area](#a-pages-title-area)); the bars' colors the path declares ([the bar a
path declares](#the-bar-a-path-declares)); the menus
its path declares
(`chromeMenus`); and the split view the window shows (`splitView`), with its
sidebar's toggle unless the split view offers none (`showsSidebarToggle`) - a
bar in two parts stands over the split view either way. A host lays these out
in its own chrome. A page saying it shows no title (`showsTitle`) still names the window to the system and
the way back from the page above it; the chrome shows none for it. A host whose pages each stand under a header bar of their
own takes the same parts page by page: a page's actions (`chromeActions`),
its title view (`chromeTitleView`), its bar's colors and the line under its
title (`barSubtitle`).

A stack shows its bar over what stands on it once (`showsTheStacksBar`): over
a page that keeps its bar, and over tabs or a split view only where the page
they show stands in no stack of their own - that stack's bar is the one, so
tabs of stacks never stand under two bars.

## A render that touches the chrome

A render shows the windows and their chrome again only where it changed what
they are made of (`MountedElement+ChromeSources`, `MountedTree.
takeChromeTouched`); every host takes the answer as `presentRendered(
touchedChrome:)`, as a frame's walk hands it `presentFrame(movedChrome:)`.
The chrome is made of the application, its scenes and windows, the
arrangements of pages and the pages, and the declarations a page's path
gives it - its actions, its title view, its menus, its overlays - with what
each holds. A render touches it where it makes or lets go of one of them,
or changes one's values, handlers or children; where it puts children in a
new order and one of them holds a declaration, whose order the composed
actions keep; and where it turns the enablement of a branch holding a
declaration, whose actions are disabled with it. A page's content changing
beside them - its words, a layout's cards in a new order - touches nothing:
composing the chrome walks the whole page's tree, and writes the bar again,
for every render otherwise. An element a render makes is told by its type
alone - what it stands in is told as its parent's children change - so
mounting a list's rows walks no path.

What a host does after every render whatever it touched stays outside the
answer: the scenes it keeps, the Web's reading of what moved on the page and
its split view's first room, GTK's facts of the display once its window is
realized, UIKit's windows told the phase they stand in.

## Menus

A menu is walked the same way on every host (`MenuEntry`): its items, its
separators and its submenus in order, each submenu holding entries of its
own, each entry with its caption, its picture, whether the user can choose
it, whether choosing it destroys something and its identifier; a menu bar
holds only its menus. A host builds its toolkit's menu
from the walk, and an item's element hears it chosen.

## The Edit menu

A menu joining `StandardMenu.edit` keeps the platform's own entries before
the application's. AppKit and UIKit keep an Edit menu of their own and join
it there; a host whose platform keeps none - WinUI, GTK, the Web - takes the
entries from the host layer (`ChromeMenus.editing`): Undo and Redo, Cut,
Copy, Paste and Delete, Select All, sections apart, in the library's words in
the system's language (`EditWords`) and with the field's own keys beside them
- the field takes those keys itself, so the menu only shows them. Each entry
is an `EditCommand` the host does with its toolkit's own act on the field the
user last typed into in the window: the menu takes the focus as it opens, so
a host keeps that field as the focus leaves it and hands the focus back as
the entry acts. A window with no such field does nothing.

## A checked entry

A setting's entry - a `MenuToggle` - stands checked or not
(`MenuToggleContract.isOn`), which each host shows as its toolkit marks a
setting: a check beside it. Choosing an entry is one rule on every host
(`MountedElement.chosen`): a setting's turns the other way - `toggled` with
the way it turned to, written through a binding - and a `MenuItem`, which
acts and shows no mark, is clicked. A setting on a bar - a `ToolbarToggle` -
turns by the same rule, and the picture it shows on the bar and behind its
overflow is its `on:` picture while it stands on, else its own
(`MountedElement.itemPicture`, which every host's entry reads).

A menu is walked from the tree, never a channel of its own, so the two-way
`MenuToggle(_:isOn: $state)` reads its state where the menu is built: the state turning
builds that body again, and the walk shows the new mark on every host the
same way a caption changing does.
