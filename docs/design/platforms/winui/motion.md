# Motion on WinUI

How the WinUI host moves what the core's motion elements say
([motion](../../host/motion.md)): which properties it draws on the way, how an
element is moved, turned and scaled, and when every animation arrives at
once. The frames come from `CompositionTarget.Rendering`
([runtime](runtime.md#one-frame)).

## What moves

A host moves only a value it draws, so the WinUI host keeps a closed set:
`WinUITransitionSurface` names, for each element, the properties whose frames
reach WinUI - opacity, the sizes, margin and the planar transforms on every
view it presents; padding and spacing on a stack; a slider's value. Any other
property arrives at its value at once, rather than keeping an animation alive
that nothing on screen would show.

A property's animation begins where the element stands: the opacity it is
drawn at, the value a slider's thumb shows.

## Moved, turned and scaled

An element is moved, turned and scaled by a `CompositeTransform`, its render
transform, drawn over the place its layout gave it, so moving one never moves
the layout's arithmetic. A translation is in DIPs, a rotation in degrees,
clockwise in the screen's plane; `scale` multiplies both axes over `scaleX`
and `scaleY`. StateUI's pivot is a fraction of the element's size and the
transform's centre is in DIPs: the host puts it back each time the element is
placed at a new size. The element's own `Translation`, `Rotation`, `Scale` and
`CenterPoint` go unused: a layout cut to its outline takes the element's
visual ([a box and its brush](drawing.md#a-box-and-its-brush)), and WinUI
refuses those four to such an element.

## Less motion

A user who turns Windows' animation effects off - `UISettings.AnimationsEnabled`
false - asks for less motion, and StateUI hears it so: every animation arrives
at its destination at once, and a journey's waiter hears it arrive.

## Joining and leaving

A stack is a travelling layout: when a patch reaches it, its children travel
to their new places ([layout motion](../../host/motion.md#layout-motion)). The
display's frame writes each travelling child's place between WinUI's layout
passes, and the place lands in the arrangement it asks for
([a place between passes](layout.md#a-place-between-passes)); that
arrangement asks for the same places and keeps the running animation.

By the host layer's rule ([showing and
hiding](../../host/motion.md#showing-and-hiding)), a child that joins a
standing stack fades in while the others make room. A
child the tree hides fades out first, still holding its room, and only then
goes: the stack closes over it as over a row a patch removed. A child shown
again comes up from nothing, or, shown again on its way out, from where the
fade has reached. Under a layout that moves nothing, or with less motion, it
goes and comes at once.
