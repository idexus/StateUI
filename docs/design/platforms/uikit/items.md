# Items

An ItemsView is UIKit's collection view: a diffable data source over the
list's identities, one section a group, and a compositional layout. The host
makes the view itself, since each cell asks the tree for what it holds
through the host layer's `ItemsCells` ([items](../../host/items.md)).
UIKit scrolls, reuses its cells, shows the user's choice and touch - each
cell is UIKit's own list cell - and tells VoiceOver about the items.

What the list holds for a cell is an entry's subtree: the cell provider
realizes the identity, and the subtree - mounted before the call returns,
or with the turn under way - stands in the cell. A cell that ends showing
lets its entry go. The user's choice is the collection's selection -
none, one or many as the tree says - told back in the list's order; what
the tree selects is selected inside `ProgramWrite` and told nobody. An item
opened is the collection's primary action, which a tap performs.
`scrollTo` scrolls to the item's index path at the anchor it names; nearest
scrolls only where the item is not wholly in view, the shorter way. The end
reached is watched as the collection scrolls and lays out.

## The layout

A list is one full-width item under another, a row one item beside another
as tall as the list, scrolling across, and a grid a group of as many
columns as the width holds (`ItemsGrid`) sharing it, `spacing` apart both
ways. Every item's size along the list is estimated and then asked of the
entry. A group's header and footer are the section's supplementary views,
and the list's own header and footer are the layout's; UIKit fixes the
layout's own when it makes the layout, so the layout is made again when the
list gains or loses one.

## A cell

A cell holds its entry's subtree in a single-child view, placed by the
layer's arithmetic, and answers UIKit's question for its size with what the
entry asks for: its height at the cell's width, or its width at the cell's
height in a row. An entry whose size changes has its cell measured again by
reconfiguring its item - UIKit measures the same cell. A whole invalidation
of the layout is never the answer: UIKit then configures fresh cells for the
items on screen, and a subtree, which stands in one cell at a time, leaves
the cell on screen empty. An entry mounting for the first time is measured by
the cell taking it, so nothing is measured again for it.

The list itself asks for its width and no height: its room is what its
layout gives it - a height, or a row of a grid that fills.

A cell at rest is clear, and the page shows through the list as it does on
every host; the list cell's own colour comes only with the user's choice, a
touch or the focus. The list cell's look at rest is the system background,
which a page of another colour - or the dark theme's black against a grey
page - shows as a block.

## One cell an entry

The cell provider, `willDisplay` and `didEndDisplaying` - of an item and of a
header or a footer - are the host layer's three moments, `hold`, `show` and
`endShowing` ([one cell an entry](../../host/items.md#one-cell-an-entry)).
Scrolled back, UIKit shows again a cell that ended showing its item a moment
before without asking the data source for it; its `willDisplay` is what
gives it its entry back.
