# Layout on WinUI

StateUI's layouts place their children by the core's arithmetic
([layout](../../host/layout.md)); WinUI measures and draws each child.

## A layout is a panel

Every StateUI layout is the relay's panel, a `Panel` whose `MeasureOverride`
and `ArrangeOverride` call the host, which answers with the core's arithmetic
and measures and places each child through the relay. WinUI lays out by
asking: a child is placed only inside its parent's arrangement, and a place
written at any other time does nothing, so a layout never places a child
outside the pass WinUI runs.

## Measured every pass

WinUI keeps each element's measure itself, and a child left unmeasured in a
pass that marked it stays marked, which sets the pass going again - a pass
that does not settle ends the process. So each measure the panel answers
measures every shown child again; WinUI answers a child it measured at the
same size from what it kept. The sizes the host keeps last for one pass,
where the arithmetic asks for a child's size more than once.
