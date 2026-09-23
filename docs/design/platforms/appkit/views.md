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
