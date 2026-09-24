# Views on AppKit

What the AppKit half's views are given by the host rather than finding for
themselves.

## Pictures

What crosses the boundary for a picture is a name, and the files behind it
belong to the renderer: it knows the application's resource directory and
keeps the cache over it, so one name is loaded once however many views draw
it. A registration is made once for the whole process and has no renderer to
ask, so the host hands every view it makes, through `AppKitPictureResolving`,
the means to resolve a name. A name the application has no file for resolves
to nothing.

## Accessibility on the control

A host view that wraps one native control hands assistive technology that
control in its own place, through `AppKitAccessibilityPresenting`. The
author's words, the role and whether the element takes part are written where
VoiceOver meets the control, not on the view around it.

## A layout's own box

A stack, a grid or a ZStack paints its own box. A plain colour on a plain
rectangle is its layer's background colour: the view draws nothing and keeps
no backing store, which is what almost every layout is. An outline, a
rounded or oval shape, or a gradient makes the view draw instead - the
background on the shape, the outline inside the bounds, half its width either
side of the shape's edge, in a colour alone (AppKit's brush strokes no
gradient). With `clipsContent` the layer cuts what the layout holds: to its
bounds, its rounded corners, or an oval mask; without it nothing is cut.

A scroller's box is its layer's alone: a colour behind what it shows, a
colour's outline on a rectangle or a rounded one, and the cut of what it shows
to its shape, always. AppKit repaints a scroller's layer as it displays it and
clears its colour and outline, so the scroller puts them back each time it
updates its layer. An oval scroller cuts and draws no outline.

