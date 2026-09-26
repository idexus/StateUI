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
view moved elsewhere keeps no word it once had.

## A page's phases

A page tree shown hears it in its turn (`setPagePresented`): a page is
appearing, and navigated to where it came by a move; hidden, it is navigated
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
before the state the choice carries hears it.

A window's page - its top sheet, else its arrangement - hears it is shown as
the window presents it, and the one before it that it is not: a move where a
sheet came or went, the window's coming otherwise (`WindowPresentation`).
The window then hears that it was made, before the host shows it.

## Tabs

A tabbed view's choice (`TabChoice`) is none until the tree or the user makes
one. A tab the tree asks for anew is chosen, so the application can move the
user; the same tab asked for again changes nothing, so the user's own choice
is not argued with. The user's choice stands where it is another tab that
exists, and says which tab showed before it.

## A sidebar on the first room

A split view's one adaptation (`SidebarAdaptation`): the first room it is
given wider than nothing decides once whether its sidebar shows - it does,
said as the user's, where the room is at least the platform's own breakpoint
and it was hidden. After that the user and the application decide. The
breakpoint is each platform's, a host's parameter.

## The way back

A window's way back (`WindowPresentation.wayBack`) takes the top sheet first:
its own stack's top page where it can go back, else the sheet itself; with no
sheet, the arrangement's stack. A stack can go back where it holds more than
one page and its top page shows its bar and its way back. Going back tells the
stack it is one page shorter, or the window how many sheets remain
(`HostRuntime.goBack`).

## Slots

A page's title view and a title bar's leading content, content and trailing
content are slots. What stands in one is the first element under the slot
that shows a view of its own (`slotContent`); an element with no view of its
own is shown by the first under it that has one (`presentingElement`).

## The window's chrome

A window composes one chrome from what it shows (`WindowChrome`): the visible
page's title, else the window's, else the host's own; the way back, in the
words the page beneath gives, else "Back"; the visible page's actions - none
where it hides its bar - by priority, then in the order written, those placed
in the overflow apart; the title bar's content in the title's place, else the
page's title view, and the title bar's leading and trailing content beside
it; the bars' colours (`barColors`) from the nearest stack or tabbed view
around the visible page, else the title bar, and what stands on them from the
nearest stack, else the title bar; the visible page's menu bar; and the
sidebar's toggle where the window shows a split view. A host lays these out
in its own chrome. A host whose pages each stand under a header bar of their
own takes the same parts page by page: a page's actions (`chromeActions`)
and its bar's colours.

## Menus

A menu is walked the same way on every host (`MenuEntry`): its items, its
separators and its submenus in order, each submenu holding entries of its
own, each entry with its caption, whether the user can choose it and its
identifier; a menu bar holds only its menus. A host builds its toolkit's menu
from the walk, and an item's element hears it chosen.
