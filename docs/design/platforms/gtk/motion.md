# Motion on GTK

How the GTK host moves what the core's motion elements say
([motion](../../host/motion.md)): which properties it draws on the way, how a
widget is moved, turned and scaled, and when every animation arrives at once.
The frames come from the window's tick callback ([runtime](runtime.md#one-frame)).

## What moves

A host moves only a value it draws: the GTK host moves what the host layer's
surface names ([what travels](../../host/motion.md#what-travels)), less what
GTK paints only at rest (`GTKTransitionSurface.atRest`) - what a class of the
host's style sheet paints, a class a value, which a value on its way would add
every frame: a label's padding and background, a button's box, a field's
font and colours, a slider's tint, the bars' colours; and a window's place and
size, which the desktop keeps. Those arrive at once.

A property's animation begins where the element stands: the opacity the host
last wrote, the value a slider's thumb shows. GTK keeps a widget's opacity in
256 steps, so what it draws is the nearest step; the animation runs on the
host's own number, exactly.

A label whose place travels is allocated at the size it is bound for, its
place travelling around it: GTK breaks a label's words at the width it is
allocated, so at the widths the place passes through words that fit the
destination on one line would stand on two
([words at their destination](../../host/motion.md#words-at-their-destination)).

## Moved, turned and scaled

A widget's transform is part of its allocation: its parent hands GTK the place
and the transform together. The host draws the place's corner, then the widget's
own transform drawn under a placing run's by the host layer's rule
(`HostDrawingTransform.under`) - the core's matrix for the size allocated,
handed to GSK as it is, since both act on row vectors. So the translation, the turn in the plane, the
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

By the host layer's rule ([showing and
hiding](../../host/motion.md#showing-and-hiding)), a child that joins a
standing stack fades in while the others make room. A
child the tree hides fades out first, still holding its room, and only then
goes: the stack closes over it as over a row a patch removed. A child shown
again comes up from nothing, or, shown again on its way out, from where the
fade has reached. Under a layout that moves nothing, or with less motion, it
goes and comes at once.
