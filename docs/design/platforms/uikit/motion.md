# Motion

UIKit draws a change that travels frame by frame, as every host does
([motion in the runtime](../../host/motion.md)): the host layer walks each
value on the display link's frames, and the element puts each frame's value
on its view. The element answers what it moves from the host layer's
surface ([what travels](../../host/motion.md#what-travels)); UIKit's own
animations are never asked for, so one clock drives every value and a
hand-wound one reproduces every frame.

A layout's children travel to their places by the host layer's rule
(`TravellingPlaces`): each patch that reaches a layout tells its places
what they travel under and that a patch arrived, so a row inserted, a card
grown or a box resized moves its neighbours rather than snapping them. A
child that joins a standing layout fades in, and a change of visibility is
crossed - faded out before the layout closes over it, faded in as it opens.
A view fades by its drawing (`UIKitViewDrawing`): its own opacity, times
the one its placing layout draws it with, and whether UIKit shows it.
