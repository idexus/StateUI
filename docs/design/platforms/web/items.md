# Items on the Web

An ItemsView is a scroller over one cell for each of its entries, laid out by
the browser: a column down, a row across, or a grid of as many columns as fit
items at least the narrowest width - CSS's `auto-fill` over `minmax`, the
host layer's rule (`ItemsGrid`) in the browser's own terms - with a header
and a footer across the whole grid. What a cell holds, which entries the
tree builds and what the user chose are the host layer's (`ItemsCells`,
`ItemsTap`); the browser scrolls, and says which cells are near the view. The
list is a room: it asks for none (`contain: size`), and stands where its
layout puts it.

## A cell an entry

The page has no collection of its own that reuses its rows, so every entry
has a cell - an empty one costs a `<div>`. A cell holds its entry's subtree
while the browser says it is near the list's view - within the view's whole
size before and after it (`IntersectionObserver`) - and lets it go as it goes
away; the tree builds the entries within reach of the cells held, and lets
the others go with its next render ([within
reach](../../host/items.md#within-reach)). A cell whose entry never came
keeps a row's room, 44 points; one that lets its entry go keeps the room the
entry took, so the cells after it stand where they stood.

The browser tells nearness once a frame, every cell it saw in one call, and
the cells take their entries together ([cells told
together](../../host/items.md#cells-told-together)). The cells going read
the room they keep before any of them changes: a read after another cell's
change makes the browser lay the whole list out for it. A cell is told near
a frame after it came near, and shows its entry a frame after that, so the
margin is the lead a fling has: half the view left a fling of 20 000 points
a second with empty cells in view, the whole view leaves none.

The trap: the browser's own skipping of what is off screen
(`content-visibility: auto`, with a size kept for it) measures nearness
against the page's view, not the list's. Cells of no height all stand at
the top of the list, near that view, so none is ever skipped and none takes
the size kept for it: a thousand rows stood in 863 points.

## A tap

A tap on a cell, but for one on a control inside it, is the list's
(`ItemsTap`): it opens the item, or chooses it as the list chooses. A list
that chooses is a listbox, each item an option, the chosen ones selected
and tinted in the accent colour
([the chosen band](../../host/items.md#the-chosen-band)).

## Scrolling to an item

An item scrolled to is scrolled to at once, and again as the cells near it
come and as their entries are built - after every batch of cells taking
their entries - while the host layer holds it ([scrolling
to an item](../../host/items.md#scrolling-to-an-item)) - a cell keeps a row's
room until its entry takes its own size. A wheel, a touch, a press or a key on
the list is the user taking it, and lets the item go. A scroll gliding there
would bring every cell it passed near the view, each would take its entry's
own size, and the item would stand elsewhere when the scroll arrived: row 500
of rows a little smaller than a row's room stood 47 rows away.

## Scrolled

A list the user scrolls moves every item in the window, which no observer
of the page tells: each scroll of the list counts as laid out, so an item
whose frame the tree reads says where it now stands.
