# Items

What a platform's collection holds of one ItemsView, and what it tells the
tree, is decided once in the host layer (`ItemsCells`); a backend is the
toolkit's collection and its calls.

The entries cross as one property, every identity in order. A backend takes
them as they change (`takeEntries`) and shows one cell for each. When the
collection asks for a cell, `realize` tells the tree the identities the
cells hold - the ItemsView's `realizedChanged` - and the turn that follows
builds the entry and mounts it as a child of the list, before the call
returns: the cell shows the subtree at once. Asked while a turn is under
way - the toolkit calling back from inside a patch - the entry arrives with
that turn instead, and the backend puts it in its cell as it appears. A
cell the collection lets go is told with `release`, and its subtree leaves
the tree with its state.

What the user chooses is told in the order the items show, and a choice the
tree already holds is not told again; what the program selects, inside
`ProgramWrite`, is not the user's. An item opened is told by its identity; a
header or a footer is never chosen or opened.

## Changes one by one

A collection that applies a snapshot works out its own changes. One told its
changes one at a time - a recycler's adapter, a list model - takes them from
`ItemsChanges`: the positions removed from the old list, last first, then
the positions inserted into the new one, first first. The identities in both
that keep their order against each other - the longest rising run of their
new places - stay; every other one is removed and inserted, which is how a
move is told.

## The end reached

`EndReachedWatch`: the end is told as the last item in view comes within
`endReachedWithin` items of the last one, once. It is told again only after
the user scrolls away from the end, or once the list gains or loses items,
so a list waiting for more is not asked for more on every frame.

## A grid

`ItemsGrid`: a grid holds as many columns as fit items at least the
narrowest width, `spacing` apart, and one at least; the columns share what
is left of the width.
