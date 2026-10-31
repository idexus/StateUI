# Items

What a platform's collection holds of one ItemsView, and what it tells the
tree, is decided once in the host layer (`ItemsCells`); a host's half is the
toolkit's collection and its calls. A collection paints nothing of its own
behind its rows, so what it stands on shows through: AppKit, UIKit and GTK
clear the background their toolkit paints there; Android, WinUI and the Web
set none and keep their collection's default.

The entries cross as one property, every identity in order. A host takes
them as they change (`takeEntries`) and shows one cell for each. When the
collection asks a cell for an entry (`hold`) that the tree has not built,
the host tells the tree which entries to build - the ItemsView's
`realizedChanged` - and the turn that follows builds them as children of the
list before the call returns: the cell shows its subtree at once. Asked
while a turn is under way - the toolkit calling back from inside a patch -
the entry arrives with that turn instead, and the host puts it in its
cell as it appears.

What the user chooses is told in the order the items show, and a choice the
tree already holds is not told again; what the program selects, inside
`ProgramWrite`, is not the user's. An item opened is told by its identity; a
header or a footer is never chosen or opened.

## One cell an entry

A subtree stands in one cell at a time, and a collection does not promise
one cell an item: it may ask a second cell for an item before the first has
ended showing it - a row measured again, an item fetched ahead - and it
shows again, without asking, a cell that ended showing its item a moment
before, when the user scrolls back. So `ItemsCells` keeps the one cell
holding each entry (`ItemsHolding`), and three moments decide it:

- `hold` - the collection asked a cell for an entry: the cell takes it,
  from a cell before, which then shows nothing;
- `show` - a cell comes on screen: one that no longer holds its entry takes
  it again;
- `endShowing` - a cell ended showing its entry: the cells stop holding it
  only while that cell still holds it. Let go by the cell it left, the
  entry could leave the tree under the cell showing it - a hole.

After every patch to the list, `childrenChanged` holds each cell to the
subtree its entry has now: one built with the turn under way, or built
again after the one before was let go.

## A cell before its entry

A cell keeps, before its entry is measured, the room the host layer says
(`ItemsCells.estimatedExtent`): a row's 44 points down a list and a grid, an
item's 100 points across a row. Measured of nothing, every cell would fit in
view at once and the collection would ask for every entry; an estimate too
narrow across would make a row ask for more entries than it shows. A cell
shows its entry anew (`ItemsHolding.showsAnew`) only where it is another
entry, or where its view and the entry disagree on whether there is a
subtree to show.

## Within reach

Every render walks the whole tree, so a render a cell would make a scroll
cost as much as the application is large. The tree builds the entries
within reach of the cells instead: as many before and after each cell as
the cells hold, eight at least. A cell coming on screen finds its entry
built and costs no render; one coming within half a reach of the end of the
built entries tells the tree, before any cell finds its entry unbuilt, so
each render of a scroll builds about half a reach - short renders, often,
rather than long ones a reach apart. A cell that ends
showing its entry tells nothing: the entry stays built while it is within
reach, and leaves with the next render once the cells have moved away.
Cells far apart, after a jump, build around each and nothing between.

## Cells told together

A collection that learns which cells came near its view and which went away
once a frame - a browser - tells them all at once
(`ItemsCells.hold(_:endingShowing:)`): the cells gone let their entries go
first, the cells near take theirs, and the tree is told once, for where the
cells stand now. A collection asking for a cell in its own layout pass tells
one at a time, a batch of one.

The trap: told one by one, a fast scroll keeps the cells gone held while the
cells near ask - each render builds a reach around where the list stood a
frame before, and each cell costs a render and a layout of its own. The list
chases where it was, and the cells in view stand empty until it stops.

## Changes one by one

A collection that applies a snapshot works out its own changes. One told its
changes one at a time - a recycler's adapter, a list model - takes them from
`ItemsChanges`: the positions removed from the old list, last first, then
the positions inserted into the new one, first first. The identities in both
that keep their order against each other - the longest rising run of their
new places - stay; every other one is removed and inserted, which is how a
move is told. `removedRuns` and `insertedRuns` gather neighbors into runs,
each told in one call, in the same order.

## The end reached

`EndReachedWatch`: the end is told as the last item in view comes within
`endReachedWithin` items of the last one, once. It is told again only after
the user scrolls away from the end, or once the list gains or loses items,
so a list waiting for more is not asked for more on every frame.

## The view moving

A toolkit moves a list's rows as it scrolls, often laying nothing out: a
view in a row stands elsewhere in its window though no layout placed it, and
a scroll of less than a row brings no row in whose layout would say so. Each
host tells the entries in view (`showing`) once the list's view has moved,
and the host layer then says that whoever reads a frame says it on the
display's next frame (runtime.md, `Where a view stands`). A host keeps no
road of its own for it.

## A grid

`ItemsGrid`: a grid holds as many columns as fit items at least the
narrowest width, `spacing` apart, and one at least; the columns share what
is left of the width.

## A collection without groups

A recycler and a grid view know no groups, and share a grid's width equally
among their columns. `ItemsPlacement` stands the entries in one run for
them: in a list or a row the items of a group stand `spacing` apart and a
header or a footer keeps no room; in a grid each entry keeps room beside it
that makes it a column's width, `spacing` from the next, and a row after the
first keeps `spacing` above it. Where the collection lets an entry span
columns, a header or a footer spans them all and a group's last item what
its row has left, so every group starts a row; where it does not, every
entry takes the next cell.

## A tap

A collection that holds no choice of its own - a recycler - hears a tap and
nothing more. `ItemsTap` decides it: a list choosing none opens the item; a
list choosing one chooses it and opens it; a list choosing many adds the
item to the choice or takes it away, and opens nothing. A collection that
holds its choice itself tells what it holds (`userChose`) and what it opens
(`userActivated`).

## The chosen band

Where a host draws the band behind an item the user chose from the accent, it
draws the accent's hue at a fifth of its strength (`ChosenBand`): AppKit over
the platform's accent, UIKit over the cell's tint, Android over the theme's
accent, the Web over its own. GTK shades a chosen row in the color of its
words, as GNOME's sidebars do, and WinUI's item container draws its own.

## Scrolling to an item

`ScrollAnchor.place` says where the scroller stands for the item to stand at
the start of the room, its center or its end. Nearest leaves an item wholly
in view where it is; otherwise it moves it the shorter way - to the start
when it stands before the room, to the end when after it. The scroller keeps
the place within its reach.

A host that works the place out itself does so from the frames its layout
holds, and those are estimates for the cells not measured yet. The cells a
scroll brings into view take their entries a turn later - the tree builds
them - and a cell measured as its entry comes moves the items after it. So
the host layer holds the item scrolled to (`ItemsCells.scrollTarget`) until a
cell shows its own entry and no cell waits for one - the cells near the place
it was scrolled to may come after a pass, as a browser tells them: the host
stands it again after every pass that brought entries (`laidOut`), once more
as the last one comes, and then lets it go. The user moving the list lets it go at once, and so does the next
scroll; a scroll that glides stands its item again as it stops.

Whether a scroll to an item glides is one rule,
`ItemsScrollTarget.glides(reducingMotion:)`: it glides unless the user asks
for less motion, and stands there at once when they do.


Once let go, the item stands where the program put it while nothing else
moves the list: a room that changes - the list's size, or what it keeps
clear of the bars over it - stands it again (`ItemsCells.roomChanged`), until
the user scrolls, the program scrolls elsewhere, or an entry comes or goes.
## An item's actions

An item's actions are its context menu (`.contextMenu` on the item's view):
declared once, offered where the platform offers an item's actions. Every
host offers the menu as it offers any view's; a list whose platform swipes an
item - UIKit's - offers the menu's items the user can choose as the item's
swipe actions too, in order, a destructive one marked
(`ItemsCells.actions(of:)`). A line and a submenu stand in the menu alone: a
swipe shows neither.
