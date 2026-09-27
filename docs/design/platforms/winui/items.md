# Items

An ItemsView is a StateUI layout holding WinUI's own `ItemsView`, its
source an observable vector of the list's identities and its item template
an element factory of the relay's: each entry's cell is a panel of the
host's, stood in an `ItemContainer`, holding the entry's subtree it asks the
tree for through the host layer's `ItemsCells` ([items](../../host/items.md)).
WinUI scrolls, reuses its containers, chooses, invokes and tells Narrator.
The list is a room: it asks for none, and stands where its layout puts it
([its room](#its-room)).

The factory's `GetElement` and `RecycleElement` are the host layer's `hold`
and `endShowing` ([one cell an entry](../../host/items.md#one-cell-an-entry)).
WinUI asks for a cell again for an entry it shows again, so nothing stands
for `show`. The relay keeps every container it made for the list's life -
each is put aside and taken again by its kind - so the host keeps each cell
for as long as the list stands. WinUI's container cannot refuse to be chosen,
so a header or a footer can be: such a choice is not the user's, and the
list shows the tree's choice again; opening one is heard by nobody.

A list is a vertical `StackLayout`, a row a horizontal one, `spacing` apart,
and a grid a `UniformGridLayout` of items at least the narrowest width,
`spacing` apart both ways, stretched to share the width. WinUI's lists know
no groups: a header or a footer stands among the items, in a grid in a cell
of its own, and a uniform grid gives every item the first one's height.

The choice is WinUI's own - none, one or many - told back in the list's
order; what the host selects is told nobody. An item is invoked by a click,
or by Enter or Space on it, where something hears one opened. What stands in
view is told as the scroller's view changes and as its extent does: entries
changed stand in view only once laid out, and the view may not move at all -
a list cut short under a view standing past its new end is brought back by
WinUI a moment later, and no view change says it.

## Its room

WinUI's `ScrollView`, the one an `ItemsView` holds, takes its viewport from
the room it is MEASURED in, not the one it is arranged in: measured with no
room the way it scrolls - as a ScrollView's `ScrollViewer` is
([scrolling](layout.md#scrolling)) - it stands 400 tall with a viewport of
0 and realizes one item; measured with no bound it asks for its items'
length and stands that tall. So the list is measured in exactly the room it
is placed in, as it is placed, and in that room again at every measure
after; before it stands anywhere it is measured in none, and realizes
nothing.

## A cell

A cell is a StateUI panel WinUI places, so it answers WinUI's measure with
the room its entry takes. A cell whose entry is still on its way keeps the
room of a row: measured of nothing, every cell would fit in view at once and
the list would ask for every entry. An entry whose size changes is measured
again by the cell holding it; the list's own size never follows its items.

## Changes wait for the list

WinUI asks for cells while it measures, and a cell asked for makes the tree
render at once - where the entries, the layout or the choice may change. The
relay applies what the host says at once when it can, and otherwise once the
list is done asking, in the order said, from the UI thread's queue.
