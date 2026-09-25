# Motion on GTK

How the GTK host moves what the core's motion elements say
([motion](../../host/motion.md)): which properties it draws on the way, how a
widget is moved, turned and scaled, and when every animation arrives at once.
The frames come from the window's tick callback ([runtime](runtime.md#one-frame)).

## What moves

A host moves only a value it draws, so the GTK host keeps a closed set:
`GTKTransitionSurface` names, for each element, the properties whose frames
reach GTK - opacity, the sizes, margin and the planar transforms on every view
it presents; padding and spacing on a stack; a slider's value. Any other
property arrives at its value at once, rather than keeping an animation alive
that nothing on screen would show.

A property's animation begins where the element stands: the opacity the host
last wrote, the value a slider's thumb shows. GTK keeps a widget's opacity in
256 steps, so what it draws is the nearest step; the animation runs on the
host's own number, exactly.

## Moved, turned and scaled

A widget's transform is part of its allocation: its parent hands GTK the place
and the transform together. The host draws the place's corner, then a placing
run's drawing, then the widget's own transform - each the core's
`HostDrawingTransform` matrix for the size allocated, handed to GSK as it is,
since both act on row vectors. So the translation, the turn in the plane, the
tip in depth about either axis - seen from the core's perspective distance -
and the scale all pivot where the core says, and moving one never moves the
layout's arithmetic. A transform the tree changes asks the parent for a new
allocation, which draws it.

## Less motion

A user who turns the desktop's animations off - GTK's `gtk-enable-animations`
false, which GNOME's Reduce Animation sets - asks for less motion, and StateUI
hears it so: every animation arrives at its destination at once, and a
journey's waiter hears it arrive.

## Joining and leaving

A stack is a travelling layout: when a patch reaches it, its children travel
to their new places ([layout motion](../../host/motion.md#layout-motion)). The
display's frame writes each travelling child's place before GTK lays the frame
out, and the place lands in the allocation it asks for
([a place between passes](layout.md#a-place-between-passes)); that
allocation asks for the same places and keeps the running animation.

A child that joins a standing stack fades in while the others make room. A
child the tree hides fades out first, still holding its room, and only then
goes: the stack closes over it as over a row a patch removed. A child shown
again comes up from nothing, or, shown again on its way out, from where the
fade has reached. Under a layout that moves nothing, or with less motion, it
goes and comes at once.
