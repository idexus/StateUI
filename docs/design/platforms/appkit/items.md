# Items

An ItemsView is AppKit's collection view in a scroll view: a diffable data
source over the list's identities, one section a group, and a compositional
layout. The host makes the view itself, since each cell asks the tree for
what it holds through the host layer's `ItemsCells`
([items](../../host/items.md)). AppKit scrolls, reuses its items, holds the
selection and tells VoiceOver about the items. The list is a room: nothing
inside it changes what its own layout measures.

The item provider, `willDisplay` and `didEndDisplaying` - of an item and of a
header or a footer - are the host layer's three moments, `hold`, `show` and
`endShowing` ([one cell an entry](../../host/items.md#one-cell-an-entry)).
The user's choice is the collection's selection - none, one or many as the
tree says - told back in the list's order; what the tree selects is set
inside `ProgramWrite` and told nobody. An item is opened by a double-click
or by Return on the chosen item, as on a Mac. A chosen item is drawn on a
rounded band of the platform's accent at a fifth of its strength, over the
page, as every host's list shows the user's choice; an item at rest draws
nothing, and the page shows through. The selected content colour is the
accent at full strength, which stands as a block against a page of another
colour.

## The layout

A list is one full-width item under another, a row one item beside another
as tall as the list, scrolling across, and a grid a group of as many
columns as the width holds (`ItemsGrid`) sharing it, `spacing` apart both
ways. A group's header and footer are the section's supplementary views,
and the list's own the layout's. A new layout forgets the item classes
registered before it - the collection then refuses to make an item, "must
register a nib or a class for the identifier" - so the classes are
registered again each time the layout is set.

## A cell

A cell holds its entry's subtree in a single-child view, placed by the
layer's arithmetic, and answers AppKit's question for its size with what the
entry asks for: its height at the cell's width, or its width at the cell's
height in a row; a cell whose entry is still on its way keeps the size AppKit
estimated. AppKit tells a cell's view its size may have changed as it merely
places it, so the list measures the entry again only where it asks for
another size than its cell stands at, and invalidates that item alone: a
whole invalidation makes AppKit ask for every item again, and the measure
that follows loops until AppKit gives up on the window's constraint passes.

## Scrolling to an item

AppKit's own scroll to an item goes by the sizes it estimated, and lands
short once the cells on the way are measured. `scrollTo` without motion
brings the item near first, lets the layout measure what it shows, and then
stands the clip view where the anchor says from the item's frame as the layout
holds it ([scrolling to an item](../../host/items.md#scrolling-to-an-item)).
With motion, the clip view glides to where the anchor says from the frames the
layout holds now, and settles once more as it stops.
