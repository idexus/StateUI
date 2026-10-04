# Items

`ItemsView` shows items with the platform's own collection. StateUI says which
items there are and builds the one the platform asks for; the platform
scrolls them, holds each in a cell it reuses, lets the user choose and open
one, and tells assistive technology about them. Nothing of StateUI's own
virtualization stands inside the platform's.

## Identities in order

Every entry the list shows has an identity, and the element carries all of
them in order as one property, `ItemsViewContract.items` (`ItemsEntries`):
the list's header and footer, and each group's header, items and footer. A
list with no groups is one section with neither. An item's identity is
`String(describing:)` of its id, and in a list of groups the group's name, a
unit separator, and that - so two groups may hold equal items. A header or a
footer is named after its group with a record separator (`\u{1E}header`),
which no author writes. Two items that describe alike are told apart as two
repeated `.id()`s are, and a complaint says so: a platform's collection
refuses two cells of one identity.

The entries cross in the patch as any property does, so they are compared,
sent only when they change, and printed by the inspector. What a host needs
from one list to the next - removals, insertions and moves - is worked out
once in the host layer.

## Built when a cell asks

The element's children are the entries within reach of the host's cells, and
no others. The host says which in an event, `realizedChanged`, whose identities
the ItemsView - a composed view - writes into a `@State` of its own; the
next render reconciles the children to them. The host layer sends the event
and renders at once, so the platform's synchronous call for a cell finds the
entry's subtree mounted. An entry the host lets go leaves the tree, its
state with it.

Each entry is a composed view of its own, `ItemsEntry`, keyed by its
identity: a state one item reads builds that item alone, and a change to it
reaches the host as any child's does.

## A source a build

What one build of the ItemsView holds - its groups, the identities worked
out from them, and how each entry is made - is one object, `ItemsSource`, made
by the view's initializer and so new each time the parent builds the list
again. An entry's inputs are its identity and that object: while only the
host's cells change, the ItemsView is built again from the same value, the
entries already built are carried whole, and only the one asked for is
built. When the parent builds the list again, every entry held is built again
too, as `ForEach` builds its rows - a value the item closure captured may have
changed. The identities are worked out once for the object, not once a
build.

## Empty

The empty view is StateUI's: while the list has no items, the ItemsView is
that view in the list's place. A header or a footer alone is no item.
