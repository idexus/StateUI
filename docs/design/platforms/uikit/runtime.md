# The UIKit runtime

The UIKit host is the runtime every host shares
([the runtime](../../host/runtime.md)), over UIKit on iOS and iPadOS: the
host layer supplies the mounted tree, the patch intake, the animator, the
state channels, the display cycle, the windows' roster and presentation and
every layout's arithmetic, and the UIKit half supplies what only the toolkit
can - the display link, the main queue the core is woken on, the views, and
the scenes around them.

## The UIKit runtime

`UIKitRenderer` owns the runtime's elements as every runtime does: the
runtime (`HostRuntime`), its frame clock - a `CADisplayLink` running only
while something holds it - and the roster of the windows it shows. The core
is woken as on every Apple host: a thread of the host's parks until the core
has work, and each ring puts a turn of the pump on the main queue. The
application's delegate starts the runtime as the application launches, and
tells it what the device, the display and the application are.

## Scenes

A StateUI scene is a window scene of UIKit's own. Each scene iOS connects -
the one it opens at launch, and each window the user opens on an iPad - tells
the core to connect a scene, and the StateUI window that scene's render holds
stands in it: a window of the scene's, its root view showing the window's
arrangement of pages within the safe area, the title of the page the user
sees the scene's title. A window the tree lets go of lets its scene go with
it. The application's `Info.plist` says it supports many scenes, so an iPad
opens as many as the user asks for.

## Drawing

A view is placed by its bounds and its centre, which hold under any
transform, never by its frame. How it is drawn over its place is one matrix
on its layer: the element's own move, turn and scale, then a placing
layout's (`UIKitViewDrawing`), both as the host layer computes them about the
view's top left, carried to the layer's middle, about which a layer turns;
its opacity is its own times the one it is placed with.
