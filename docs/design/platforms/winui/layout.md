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

## A place filled

A control's style aligns it inside the place its parent arranges it in - a
`Button` to the left and to the middle, at the size it asked for - where a
StateUI layout decides the place itself. So every element the host holds is
told to stretch across whatever place it is arranged in, once, as it is made:
the layout's place is the control's size.

## No room asked

WinUI arranges an element at no less than the size it last asked for in
`Measure`, and cuts it to the place it was given - so a child placed smaller
than its content would be laid out at its content's size and clipped, where
StateUI places it at its place and lets it draw past its edges. A StateUI
layout that another StateUI layout places therefore asks WinUI for no room:
its parent reads its size from the core's arithmetic (`naturalSize`), and
WinUI arranges it exactly where the parent puts it. A layout WinUI itself
places - the window's content, a scroller's document - answers with the room
its children take, within the room offered. A native control keeps its own
measure, and WinUI clips it as it clips any control given too little room.

Measuring a child again inside an arrangement, at its place, is no answer: the
child's new size tells its parent to measure again, the next measure asks for
the whole content, and the pass never settles.

## A change told upward

WinUI hears of a child's new size only as a change in what the child asks
for, and a StateUI layout placed by another asks for no room, as a picture
does. So a layout WinUI measures by itself - a picture read below it, words
changed - whose natural size has changed tells the layout placing it, which
measures again, and so on up; a layout measured inside its parent's own
measure is read there and tells nothing. A picture read after its layouts
were measured tells the layout holding it through the relay.

## Where a view stands

A view whose frame the tree reads - a state its frame drives, or a handler
for its changes - says where it stands on the display's next frame after a
layout pass or a scroll: its frame in its parent, its place in the window's
content, and that place from the page's corner, all in DIPs. The host hears
every StateUI layout WinUI arranges and every scroller's movement, and asks
only the views that are read, in the order they were made; a view that did
not move says nothing. It speaks on a frame rather than inside WinUI's pass,
so what a handler renders is laid out in a pass of its own.

## Scrolling

A ScrollView is a StateUI layout holding WinUI's `ScrollViewer`, which holds
the document the core's scroll arithmetic lays out - never smaller than the
viewport, and several children stacked down. The scroller is measured with no
room in the directions it scrolls: it measures its document without bound
there itself, so the extent is the document's, and asking for no room it
stands exactly where the layout places it.

The scroller says where its view stands through `ViewChanged`, and that the
user holds it through `DirectManipulationStarted` and `Completed`. The user's
movement is joined up to the display's next frame, which reports it to its
state and its handlers, and rests once it has stood still, as on every host
([a scroller's movement](../../host/runtime.md#a-scrollers-movement)).

## The program's move

`ChangeView` moves the view in a later frame, and its `ViewChanged` comes long
after the program's write has ended, so `ProgramWrite` cannot know it. The
host keeps the target it moved to - kept within the scroller's reach, as the
scroller keeps it - and takes the view arriving there as the program's; a
target the view already stands at is not moved to at all, as the scroller
would say nothing of it, and a user's hold forgets the target.
