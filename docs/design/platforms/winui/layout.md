# Layout on WinUI

StateUI's layouts place their children by the core's arithmetic
([layout](../../host/layout.md)); WinUI measures and draws each child.

## A layout is a panel

Every StateUI layout is the relay's panel, a `Panel` whose `MeasureOverride`
and `ArrangeOverride` call the host, which answers with the core's arithmetic
and measures and places each child through the relay. WinUI lays out by
asking: a child is placed only inside its parent's arrangement
([a place between passes](#a-place-between-passes)).

## Measured every pass

WinUI keeps each element's measure itself, and a child left unmeasured in a
pass that marked it stays marked, which sets the pass going again - a pass
that does not settle ends the process. So each measure the panel answers
measures every shown child again; WinUI answers a child it measured at the
same size from what it kept. The sizes the host keeps last for one pass,
where the arithmetic asks for a child's size more than once.

## A place between passes

A child's `Arrange` written outside its parent's arrangement does nothing, so
a view keeps the place it was last given and writes it according to when it
comes. Inside a pass - the host counts the arrangements under way - the place
is arranged at once. Between passes, as a display frame moves a travelling
child, the view asks the layout that placed it to arrange again
(`InvalidateArrange`); WinUI runs that arrangement before it draws the frame,
and the layout's arrangement gives the child the place it keeps.
