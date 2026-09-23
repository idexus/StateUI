# Motion on Android

How the Android Views host moves what the core's motion elements say
([motion](../../host/motion.md)): which properties it draws on the way, how a
view is moved, turned and scaled, and when every animation arrives at once.
The frames come from the UI thread's choreographer ([runtime](runtime.md)).

## What moves

A host moves only a value it draws, so the Android Views host keeps a closed
set: `AndroidTransitionSurface` names, for each element, the properties whose
frames reach the view - opacity, background, the sizes, margin and the
planar transforms on every view it presents; padding and spacing on a stack;
the text's size and colour on a label, a button and a field; a slider's value
and tint. Any other property arrives at its value at once, rather than
keeping an animation alive that nothing on screen would show.

A property's animation begins where the view stands: the opacity it is drawn
at, the value a slider's thumb shows. A thumb the user holds is where the
next animation of its value starts.

## Moved, turned and scaled

A view's translation, rotation and scale are the view's own properties on
Android, drawn over the place its layout gave it, so moving one never moves
the layout's arithmetic. A translation is in points and becomes pixels at the
display's density; rotations are in degrees, clockwise in the screen's plane,
and a positive turn about either axis in depth sends the top, or the right
edge, away - Android's own directions are StateUI's. `scale` multiplies both
axes over `scaleX` and `scaleY`.

StateUI's pivot is a fraction of the view's size; Android's is in pixels. At
the centre Android keeps the pivot there itself as the size changes; any other
pivot is put back in pixels each time the view is placed.

## Less motion

A user who turns the system's animations off - the animator duration scale
at zero, which `ValueAnimator.areAnimatorsEnabled()` reports - asks for less
motion, and StateUI hears it so: every animation arrives at its destination
at once, and a journey's waiter hears it arrive.
