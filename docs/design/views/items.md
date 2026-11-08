# Items

`ItemsView` shows items with the platform's own collection. StateUI says which
items there are and builds the one the platform asks for; the platform
scrolls them, holds each in a cell it reuses, lets the user choose and open
one, and tells assistive technology about them. Nothing of StateUI's own
virtualization stands inside the platform's.

## Identities in order

Every entry has a host token. `ItemsViewContract.items` carries them in the
order the list shows: its header, each section's header, items and footer,
then its footer. The token is an address within this list, not a description
of the authored value. Selection, activation and scrolling map between the
token and the value on the Swift side.

`ItemsBook` keeps the token each value stood under while it remains in the
list. A retained value keeps that token across reorder and movement between
sections. Every token of the previous build is reserved before naming a new
value, including values leaving in this build, so new content cannot inherit
a departing row's state. An authored string keeps its name when available;
another Hashable value receives a monotonically allocated token, independent
of its description, hash-table order or address. Item and section allocations
have separate prefixes, a group separator followed by `i` or `s` and a number.
Allocated tokens are never reused during the book's lifetime.

A section is matched by the value `.id` gives it, and by its position where
it has none. A position has its own key type, distinct from every authored
value. Its host name is the position's decimal number where available; an
explicit string keeps its name and another explicit value receives a token.
Sections reserve their previous names just as items do.

The same authored value twice is invalid data and is reported. The book
keeps the token of each occurrence in writing order so that collision handling
is stable as other names leave. This does not distinguish equal authored
values semantically: selection and scrolling still name the first occurrence.
A new occurrence uses the first occurrence's token with a group separator and
an unused suffix. Two unequal values with equal descriptions remain distinct.

Decorations have their own domain: a record separator, the section's token
and another record separator before `header` or `footer`; the list's own
header and footer omit the section. An empty section name therefore still has
two separators and cannot equal the list's own decoration. Authored strings
have NUL, group separator and record separator replaced by U+FFFD before
naming. The generated tokens contain no NUL, so GTK and WinUI can carry them
through their native C-string interfaces without truncating identities.

The entries cross as an ordinary property and are sent only when they change.
The common host layer computes the removals, insertions and moves native
collections need. A host and its tests use the tokens actually emitted;
converting an authored ID to text cannot reconstruct one.

## Built when a cell asks

The element's children are the entries within reach of the host's cells, and
no others. The host says which in an event, `realizedChanged`, whose identities
the ItemsView - a composed view - writes into a `@State` of its own; the
next render reconciles the children to them. The host layer sends the event
and renders at once, so the platform's synchronous call for a cell finds the
entry's subtree mounted. An entry the host lets go leaves the tree, its
state with it.

The ItemsView keeps, with the identities, the positions they stood at as the
host said them, and builds the entries standing at those positions too
(`ItemsReach`). A change that moves the entries - one put first, one taken
out - brings others to the places the cells stand at, and they are built in
the render of the change: the patch mounts them before the host takes the
new entries, so the collection measures them as it lays the change out,
where an entry built a turn later would be laid out at an estimate and move
every row after it once measured. The host's next word replaces both.

Each entry is a composed view of its own, `ItemsEntry`, keyed by its
identity: a state one item reads builds that item alone, and a change to it
reaches the host as any child's does.

## A source a build

What one build of the ItemsView holds - its sections, the identities worked
out from them, and how each entry is made - is one object, `ItemsSource`, made
by the view's initializer and so new each time the parent builds the list
again. `.header` and `.footer` make the copy they return a source of its own,
since the source holds them: two copies of one list each show their own, and
a list kept as a value, given its header in the parent's body, shows the one
the parent's last build gave it. An entry's inputs are its identity and that object: while only the
host's cells change, the ItemsView is built again from the same value, the
entries already built are carried whole, and only the one asked for is
built. When the parent builds the list again, every entry held is built again
too, as `ForEach` builds its rows - a value the item closure captured may have
changed. The identities are worked out once for the object, not once a
build. An entry is one value to compare - its identity and that object
(`ItemsEntry` is `Equatable`) - since every render of the list compares each
entry it keeps: it is compared whole, with no walk of its parts.

## Empty

The empty view is StateUI's: while the list has no items, the ItemsView is
that view in the list's place. A header or a footer alone is no item.
