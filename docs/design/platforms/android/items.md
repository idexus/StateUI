# Items

An ItemsView is AndroidX's `RecyclerView` in the relay's
`StateUIItemsView`, its adapter over the list's identities. The recycler
scrolls, reuses its cells and tells TalkBack; each cell holds one entry's
subtree, which it asks the tree for through the host layer's `ItemsCells`
([items](../../host/items.md)). The list is a room: it measures as wide as
it is offered and as tall as it is given, never by its items, so the
recycler never lays out every item to learn its size.

The adapter's bind, a cell attached to the window and a cell recycled are
the host layer's three moments, `hold`, `show` and `endShowing` ([one cell
an entry](../../host/items.md#one-cell-an-entry)): the recycler attaches a
cell it kept aside again without binding it. The relay keeps the identities
as the Swift view last gave them and hands the bound one over with each
call.

The recycler holds no choice of its own and hears a tap and nothing more,
so a tap on an item's cell goes to the host layer's rule
([a tap](../../host/items.md#a-tap)). A chosen item is drawn on a band of
the theme's accent, the cell activated; TalkBack hears it selected, or
checked where many may be chosen. An item takes a touch - the theme's
ripple - only where a tap does something: where items may be chosen, or
something hears one opened.

## The layout

A list is a vertical `LinearLayoutManager`, a row a horizontal one whose
cells are as tall as the row, and a grid a `GridLayoutManager` of the
columns the width holds. The recycler knows no groups, so the host layer
places every entry ([a collection without
groups](../../host/items.md#a-collection-without-groups)), spanning: the
span lookup gives each entry its columns, and an item decoration its room.
The columns are worked out from the width the list's layout gives it,
before the recycler lays its cells out in that width.

## A cell

A cell is the relay's `StateUIItemCell`, a StateUI layout the recycler
measures and places, holding the entry's subtree as a page holds its child.
A cell whose entry is still on its way keeps the room of a row: measured of
nothing, every cell would fit in view at once and the recycler would ask
for every entry. An entry whose size changes is measured again by the cell
holding it; the list's own size never follows its items.

The recycler's pool keeps every cell it is given. A cell it dropped would
leave its Swift view behind, so the list owns each cell it made for as long
as it stands, and a cell whose view is still moving is recycled all the
same.

## Changes wait for the recycler

The recycler refuses a change to its items while it lays out or scrolls,
and a cell bound there makes the tree render at once - where the entries,
the layout or the choice may change. So the relay applies what the Swift
view says at once when it can, and otherwise once the recycler is done, in
the order said. The entries and their room change together, and the
changes are told as runs (`ItemsChanges.removedRuns`, `insertedRuns`),
animated unless the list was empty or motion is reduced. The items in view
are told once a scroll or a layout is over, never from inside the
recycler's scroll callback: a list that loads more there would change the
recycler while it scrolls.

## Scrolling to an item

With motion, the recycler's smooth scroller glides to the item and asks
the host layer's rule where it stands ([scrolling to an
item](../../host/items.md#scrolling-to-an-item)). Without, an item laid out
is moved there at once; one far off is brought to the start first and
stood where it was asked once the recycler has laid it out.
