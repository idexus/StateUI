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
view down the window's stacks and split view details (`tabsStandInWindow`):
one in a sidebar, in a tab of another, in a sheet or inside content keeps a
row of its own. It is read from where the tabbed view stands, each time, so a
view moved elsewhere keeps no word it once had. A split view's sidebar is its
first child as the patch writes it, so the answer is already right while the
tree that holds the tabbed view is still being made.

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
and it was hidden. After that the user and the application decide. The
breakpoint is each platform's, a host's parameter.

## A sidebar's material

A split view says two materials for its sidebar: what it stands on beside the
detail (`sidebarBackground`) and what it stands on while it slides over the
detail (`flyoutBackground`). Each host knows which place its sidebar stands
in - a drawer, an overlay pane, a collapsed split - and asks the split view
for that place's material (`sidebarMaterial(over:)`); an empty one is the
platform's own there. Beside the detail the platform's own lets the window
through, as a desktop sidebar does; over the detail it is the platform's
drawer or overlay surface, never the window's - a clear window would leave a
flyout with nothing under its words. The sidebar page's own background still
paints the page on top. A split view saying either material gives its
sidebar to the application to paint (`paintsSidebar`): a host whose platform
draws a sidebar's material of its own leaves it out then.

## The way back

A window's way back (`WindowPresentation.wayBack`) takes the top sheet first:
its own stack's top page where it can go back, else the sheet itself; with no
sheet, the arrangement's stack. A stack can go back where it holds more than
one page and its top page shows its bar and its way back. Going back tells the
stack it is one page shorter, or the window's modal stack how many sheets
remain (`HostRuntime.goBack`).

## Slots

A title view is a slot. What stands in it is the first element under the
slot that shows a view of its own (`chromeTitleView`); an element with no
view of its own is shown by the first under it that has one
(`presentingElement`).

A declaration - a toolbar, a title view, a menu bar, a context menu - is a
child of whatever element it is declared on, a page, a stack or a button,
and furnishes the chrome from there: no layout places it, and no element
with no view of its own is shown by it (`arrangedChildren`). Every host
lays out and flattens through that one list, so a title view's field stands
in the bar alone, measured by itself, and never also in the page's room.

## The visible path

A page's chrome takes what is declared on its path (`declared`): the slots of
each arrangement around the page, from the outermost in, then what the
page's own tree declares, in the tree's order. Each carries its level - the
outermost arrangement's 0, the page's own last. The path ends at the window
and at a sheet's modal stack, so a sheet starts one of its own - a modal
stack's root stands on the path around the stack - and so does a split
view's sidebar, which is not on the path; a native
collection's items belong to no page. A page that goes takes its
declarations with it, and what the levels around it declare stands as it
stood: nothing is restored, because nothing was overwritten.

## The actions of a path

One toolbar group is one declaration: its items share one background where
the platform groups a bar's actions. A group whose `.id` was declared further
out joins that group, which stands where its outermost declaration put it.
At each edge the groups stand by their `order`, then with the outer ones in
place at the edge - first at the leading edge, last at the trailing - so an
action of the window keeps its place from page to page and a page's own come
in from the title's side; then as declared. The same key orders the
declarations inside a joined group. An item whose `.id` an item further out
has stands in that item's place, which the others of that id leave; a group
left with nothing is none. The items placed in the overflow leave their
groups for it, in the order composed (`ChromeActions`). A bar that draws no
groups takes the trailing actions in reading order (`primary`).

## The menus of a path

The menu bar a page's window shows is composed from the menu bars its path
declares (`ChromeMenus`), by the rule the actions follow. A menu whose `.id`
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

What an arrangement declares of the bar - its colours, and the application's
name, the line under the title and its mark - is a value on the arrangement
(`BarElement`), not a declaration: each value of a page's bar is the nearest
on its path, its own arrangement included (`barValue`), so a stack further in
paints its own bar and the window's page still names the application. The
path is the declarations' (`arrangementsAround`), but for a split view's
sidebar, which wears its own split view's bar - a split view's bar is both its
panes', so its colours paint a sidebar's own bar where a platform draws one
(`barArrangements`) - and nothing from around the split view; a sheet takes
nothing from around it. The colours are `barColors`; the name, the line and
the mark are the title area (`titleArea`), none where none is declared, an
empty line or picture none. A host shows the title area where its platform
names the application - a desktop's window chrome - and the line under the
title wherever a bar has one.

## The overlays of a window

A window lays over what it shows the overlays declared along each page it
shows (`WindowPresentation.overlays`): the arrangement's visible path, the
outer under the inner, then each sheet's in turn, then the window's own - the
library's docked inspector - over every other. Each is one layer holding the
views declared together. A page that stops being shown - a page pushed over
it, a tab chosen away - takes its overlays with it; nothing is restored,
because nothing was overwritten. A modal stack standing as the window's page
is shown as its root under its sheets.

## The window's chrome

A window composes one chrome from what it shows (`WindowChrome`): the title
of the page that names it (`titledPage`) - the visible page, but tabs on a
stack are its last place and name the window by their own title, else by the
page beneath, never by what they show, their pages naming their tabs alone -
else the window's, else the host's own; the way back, in the
words the page beneath gives, else "Back"; the actions the visible page's
path declares (`chromeActions`) - none where the page hides its bar - each
showing its words beside its picture where it says so and always where it
has none (`showsActionWords`); the title view the path declares in the
title's place (`chromeTitleView`); the title area and the bars' colours the
path declares ([the bar a path declares](#the-bar-a-path-declares)); the menus
its path declares
(`chromeMenus`); and the sidebar's toggle where the window shows a split view. A host lays these out
in its own chrome. A host whose pages each stand under a header bar of their
own takes the same parts page by page: a page's actions (`chromeActions`),
its title view (`chromeTitleView`), and its bar's colours and the line under its title.

A stack shows its bar over what stands on it once (`showsTheStacksBar`): over
a page that keeps its bar, and over tabs or a split view only where the page
they show stands in no stack of their own - that stack's bar is the one, so
tabs of stacks never stand under two bars.

## Menus

A menu is walked the same way on every host (`MenuEntry`): its items, its
separators and its submenus in order, each submenu holding entries of its
own, each entry with its caption, its picture, whether the user can choose
it, whether choosing it destroys something and its identifier; a menu bar
holds only its menus. A host builds its toolkit's menu
from the walk, and an item's element hears it chosen.
