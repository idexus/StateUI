# Items

An ItemsView is a StateUI layout holding GTK's own list view in a scrolled
window - a `GtkListView` down or across, a `GtkGridView` in columns - over a
`GtkStringList` of the list's identities, its rows made by a signal factory.
Each row's child is a panel of the host's, holding the entry's subtree it
asks the tree for through the host layer's `ItemsCells`
([items](../../host/items.md)). GTK scrolls, reuses its rows, chooses,
activates and tells the screen reader. The list is a room: it asks for
none, and stands the scrolled window over the place it is given.

The factory's `bind` and `unbind` are the host layer's `hold` and
`endShowing` ([one cell an entry](../../host/items.md#one-cell-an-entry)):
GTK binds a row again for an entry it shows again, so nothing stands for
`show`. A row is `setup` with its cell and `teardown` lets it go. A header's
or a footer's row is neither selectable nor activatable. GTK binds rows far
beside its view - up to two hundred around where it stands - and maps some
beside it while it measures rows it has not yet, so neither says what is in
view: once GTK has laid the list out, the entries of the cells standing
within the list's own bounds - the list is its own viewport - are what the
host layer hears as shown.

The choice is a selection model over the string list - none, one the user
may take back, or many - told back in the list's order; what the host
selects is told nobody. An item is activated by a double click or by Enter,
as in GNOME's applications.

GTK's list views know no groups and a grid view shares its width equally
among its columns, so the host layer places every entry without spanning
([a collection without groups](../../host/items.md#a-collection-without-groups)):
a header or a footer takes a cell of a grid as an item does, and each
cell's margins are its entry's room. A grid's columns follow the width the
list is given.

## A cell

A cell is a StateUI panel GTK places, so it answers GTK's measure with the
room its entry takes, and the list stands each row at its natural size (the
scrollable's natural policy): at its least, a panel's nothing, every row
would stand in view at once. A cell whose entry is still on its way keeps the room
of a row: measured of nothing, every cell would fit in view at once and the
list would bind every entry. An entry whose size changes is measured again
by the cell holding it; the list's own size never follows its items.

## Changes wait for the list

GTK binds its rows as it allocates the list, and a row bound makes the tree
render at once - where the entries may change. The host changes the string
list at once when it can, and otherwise once GTK has laid the frame out,
in the order said.

## Scrolling to an item

GTK brings the item into view, the shortest way; once it is laid out, the
scrolled window stands where the anchor says, by the host layer's rule
([scrolling to an item](../../host/items.md#scrolling-to-an-item)).
