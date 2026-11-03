# Items

`ItemsView` shows items with the platform's own collection. StateUI says which
items there are and builds the one the platform asks for; the platform
scrolls them, holds each in a cell it reuses, lets the user choose and open
one, and tells assistive technology about them. Nothing of StateUI's own
virtualization stands inside the platform's.

## Identities in order

Every entry the list shows has an identity, and the element carries all of
them in order as one property, `ItemsViewContract.items` (`ItemsEntries`):
the list's header and footer, and each section by its name with its header,
items and footer. A list with no sections is one section with neither. An
item's identity is `String(describing:)` of its id, whatever section holds it:
an item's value stands once in the whole list, so a choice, an activation and
a scroll name one row by the value alone, and an item moved to another section
keeps its identity - the host moves its cell. A header or a footer is named
by the list: a record separator, its section's name and a second separator
before its role (`\u{1E}Fruit\u{1E}header`), the list's own with no section
between (`\u{1E}header`) - so a section of empty words is no "no section".
Every name the list makes begins with a separator and no item's words hold
one (below), so an entry named by the author and one named by the list are
never one, whatever the author's words.

A section is known by the value `.id` gives it, as an item is by its own, and
one given none by its place; its name is that value's words - the place's
number - and the list keeps the name each section stood under across builds
(`ItemsBook`), so a section keeps its name wherever it moves. Every name of
the build before is kept from a new section as it is from a new item (below),
a section gone included: its header and footer are named from it, and a new
section under it would carry their state. Two sections given one id are a
repeat, told apart and said; a place whose number reads as an author's id is
no repeat, only told apart.

An item is known by its value, as `ForEach` and `MotionLayout` know theirs,
and its words only name it. The list keeps, from one build to the next, the
identity each value stood under (`ItemsBook`), and a value still on the list
stands under it again, wherever it now is, before any new value is named. Two
values that describe alike are two items, the second named with a variant of
the words, and each keeps its own across a reorder: were the identities
handed out by words in order, two such items swapping places would leave every
identity where it was, and the host would move nothing. Every name of the
build before is kept from a new value for that build, the names of values gone
included: the entry under such a name is leaving as the new one comes, and a
new entry under it would carry what it left - the state of a row that looked
alike. The same value twice
is a repeated identity, told apart as two repeated `.id()`s are, and a
complaint says so: a platform's collection refuses two cells of one identity.
The value names its first row; the repeat is reached by no choice nor scroll.

A variant is the words, a group separator (`\u{1D}`) and a number. An
author's words hold neither separator nor a NUL - each is read as U+FFFD - so
a value's words never read as a variant or as a name of the list's own, and
GTK and WinUI, which hand the identities to their toolkits as C strings ending
at a NUL, see each identity as its own.

The entries cross in the patch as any property does, so they are compared,
sent only when they change, and printed by the inspector. What a host needs
from one list to the next - removals and insertions, an entry that moved being
one of each - is worked out once in the host layer.

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
