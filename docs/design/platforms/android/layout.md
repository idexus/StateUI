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
