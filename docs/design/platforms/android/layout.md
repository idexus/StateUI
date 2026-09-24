# Layout on Android

StateUI owns layout on Android as it does on every host: a layout's children
are measured and placed by the core's arithmetic
([layout](../../host/layout.md)), and the toolkit contributes only what a
child measures natively.

## A layout is a view group

A StateUI layout is a `StateUIViewGroup`. Android asks it to measure and to
place its children, and it forwards both to Swift with its number: the
measure to the arithmetic's size for the width offered, the placement to the
arithmetic's rectangles. A child is measured through Android's own
`measure`, so a text measures its words and a nested layout answers through
the same arithmetic. Each child is measured again at exactly its rectangle
before it is placed, as Android expects of every view it lays out.

## Points and pixels

The arithmetic works in points; the views in pixels. The host converts at the
display's density, rounding each edge of a rectangle rather than its size, so
neighbours meet without a gap. A text's size is in scaled pixels, so the
user's font scale applies to it as it does to every application's text.

## Measured once

A layout keeps the sizes it measured for each width offered. Anything that
can change a size - a child arriving or leaving, a spacing, a padding, a
property of a descendant that is not only drawn - forgets the kept sizes from
that element up to the root and asks Android to lay out again.

## Children past the edges

A StateUI layout does not cut its children off at its edges: a child moved,
turned, or still on its way to a place a patch gave it, is drawn where it
stands. Android's view groups cut their children off by default, so every
layout view group is told not to, at its content and at its padding.


## Scrolling

A ScrollView is a StateUI layout like any other to its parent, measured by
the core's scroll arithmetic, and inside it stands Android's own scroller: a
`ScrollView` to scroll down, a `HorizontalScrollView` to scroll across, and
the second inside the first to scroll both ways, each axis native. The
innermost holds the document, a StateUI layout that stands the content where
the arithmetic says. The scroller fills its viewport with the document, so a
short content still has the whole room to stand in, and the scroller's
padding is the document's own rather than the native scroller's. Several
children are stacked down inside the document, as one.

The native scrollers take the element's direction rather than the
activity's: one right to left starts at its end, one left to right at its
first column, so a block of code told `.leftToRight` starts at its first
column in a language written right to left.

What the user does is Android's - the drag, the throw, the edge's glow - and
the host hears each move of either scroller and when a finger takes hold and
lets go. The movement says on the display's frame where it went and when it
rested ([a scroller's movement](../../host/runtime.md#a-scrollers-movement)):
a finger let go leaves the scroller to throw on, and it rests once it has
stood still. The tree's offset is written as the program's write, only where
it differs from where the scroller stands, and waits for the first layout
when the scroller has none yet; each scroller keeps it within what it can
reach.

## Where a view stands

A view whose frame the tree reads - a state its frame drives, or a handler
for its changes - says where it stands on the display's next frame after
Android laid the window out or scrolled it: its frame in its parent, its
place in the window, and that place from the safe area's corner, all in
points. The host hears every layout pass and scroll of the window once, and
asks only the views that are read; a view that did not move says nothing. A
view reports on a frame rather than inside Android's layout pass, so what a
handler renders is laid out in a pass of its own.
