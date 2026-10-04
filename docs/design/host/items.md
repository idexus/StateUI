# Items

What a platform's collection holds of one ItemsView, and what it tells the
tree, is decided once in the host layer (`ItemsCells`); a host's half is the
toolkit's collection and its calls. A collection paints nothing behind its
rows on any host: what it stands on shows through.

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

## Within reach

Every render walks the whole tree, so a render a cell would make a scroll
cost as much as the application is large. The tree builds the entries
within reach of the cells instead: as many before and after each cell as
the cells hold, eight at least. A cell coming on screen finds its entry
built and costs no render; one reaching past the built entries tells the
tree once, and the render builds a reach at a time. A cell that ends
showing its entry tells nothing: the entry stays built while it is within
reach, and leaves with the next render once the cells have moved away.
Cells far apart, after a jump, build around each and nothing between.

## Changes one by one

A collection that applies a snapshot works out its own changes. One told its
changes one at a time - a recycler's adapter, a list model - takes them from
`ItemsChanges`: the positions removed from the old list, last first, then
the positions inserted into the new one, first first. The identities in both
that keep their order against each other - the longest rising run of their
new places - stay; every other one is removed and inserted, which is how a
move is told. `removedRuns` and `insertedRuns` gather neighbours into runs,
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

## Scrolling to an item

`ScrollAnchor.place` says where the scroller stands for the item to stand at
the start of the room, its centre or its end. Nearest leaves an item wholly
in view where it is; otherwise it moves it the shorter way - to the start
when it stands before the room, to the end when after it. The scroller keeps
the place within its reach.
