# Input on WinUI

How the WinUI host hears what the user does to an element with a finger, a pen
or the mouse - a tap, the pointer, a press dragged, a pinch - and reports it
as the element's events ([a user's change](../../host/runtime.md#a-users-change)).
A control's own input - a button's click, a switch turned - is the control's,
and stays there ([controls](controls.md)).

## Listening

A view listens only for what its element's handlers and channels ask: taps
for a tap handler, the pointer for a pointer handler, a press dragged for a
pan, a swipe or a state a pan carries, a pinch for a pinch handler; and what
it hears becomes the element's events by the host layer's rule ([what the
user does with a finger](../../host/runtime.md#what-the-user-does-with-a-finger)).
The relay takes what a view listens for in the host layer's own bits, and
hangs its handlers on the element once, each naming the view by its number,
and each asks what the view listens for as it runs; a view that stops
listening, or leaves the tree, takes them off again once the event running
is over. WinUI raising a routed event reads the element's list of handlers
after each one returns, and a handler that renders runs the whole turn
inside the event: a tap that closes what was tapped - an inspector's close -
would take the handlers off under the list being read, and XAML reads past
its end. Until they come off, each asks what the view listens for and
answers nothing.

A panel draws nothing between its children, and WinUI hits nothing there. A
panel with no background of its own is painted clear while it listens or
offers a context menu, so a row answers a click past its words as well as on
them; once it does neither, the clear paint goes, and an author's background
is never touched.

## A disabled view

A view's enablement reaches the control it answers through - its own, or the
scroller or the list a layout of it holds (`WinUIView.answering`) - as WinUI's
`IsEnabled`, and a control in a disabled branch is off with it. A view that is
no control - a figure, a picture, a panel, a block of words - keeps no enabled
state on WinUI: the host layer hears nothing of the hand in it.

## Taps

A single tap is the view's press, taken as a button takes one by the host
layer's rule ([a press as a button takes it](../../host/runtime.md#a-press-as-a-button-takes-it)):
from `PointerPressed`, the view capturing the pointer as a `Button` does, to
`PointerReleased`, each phase told with where the pointer stands in the view;
`PointerCaptureLost` and `PointerCanceled` - a scroller's manipulation taking
the touch - are the press taken away. The press is the first view's to hear
it: a view around one leaves it, so a tappable row inside another answers
alone; a control under the pointer handles its own press, which never reaches
the view around it. Assistive technology's invoke taps at once.

WinUI tells a tap, and a second tap soon after as a double tap in place of a
tap; these count a run of taps alone. The relay counts a quick run: a tap
within the system's double-click time of the last one continues it. A view
asking for `count` taps answers each time the run reaches a multiple of it.

## A press held

A hold is WinUI's `Holding` as it starts, which Windows raises for a finger
and a pen after its own time: a mouse button held is no hold, and a view
keeps no time of its own. A press held raises no tap.

## Pressed by assistive technology

A panel that listens for taps is a button to UI Automation: its peer offers
the invoke pattern, and pressing it runs the tap handler once, whatever
count the view asks for - as a screen reader's press, and a test's, do.

## A press dragged

A press of the primary button, or a finger or a pen down, becomes a drag by
the host layer's rule ([a press dragged](../../host/runtime.md#a-press-dragged))
once it has moved past the system's drag distance along either axis
(`SM_CXDRAG`, `SM_CYDRAG` at 96 DPI, so in DIPs as the press is measured).
The relay tells the press alone - down, moved, let go, taken away - and holds
the pointer for the view as the rule says it is a drag: from there the view holds the
pointer, so the drag goes on outside it, and the drag is handled, so a view
dragged inside another drags alone. It is measured on the window's content,
where the view it moves does not move the measure. A drag says its phases -
began, moved by how far since it began, ended or cancelled - and a pan's
states move by that from where they stood as it began. Ended, it is a swipe
by the host layer's rule ([a swipe](../../host/runtime.md#a-swipe)). A pan
that asks for more than one pointer is not recognized.

## The hand over a layout

A layout an engine moves hears the hand two ways (`Input.cpp`). Each press
of the primary button, finger or pen on it is told to the host as it goes
down, moves and lifts, and the host layer reads them as one hand past the
system's drag distance (`HandRecognition`), answering where it stands: still
asking, taken by the layout - which then holds the pointer and handles each
move - or left, the pointer going on to whatever holds the layout and its
moves told no more. Each report carries the pointer's own
time (`PointerPoint.Timestamp`), from which the host layer reads the speed at
the lift; a lost capture or a cancel takes the hand away.

A trackpad and a wheel are heard as WinUI's own scroller hears them: the
layout's visual is a `VisualInteractionSource` redirecting both
(`CapableTouchpadAndPointerWheel`) to an `InteractionTracker`, along the
layout's axis alone - the other goes on to whatever holds the layout. The
tracker's states are the hand: fingers down (`InteractingStateEntered`) begin
it and stop a throw under way, its moves are the fingers' (`ValuesChanged`),
and the lift (`InertiaStateEntered`) carries the platform's own speed; the
tracker's inertia after it moves nothing, as the layout throws the run. A
wheel's step enters inertia with no fingers down, and how far the platform
would scroll for it - its resting place from where the last step aimed - is
told as a wheel; so a mouse's notch goes as far as the platform scrolls for
it rather than to the next target, the tracker telling no notch
(`handStepped` stands `–`). Nothing is bound to the tracker's position.

## A pinch

A view that listens for a pinch takes WinUI's scale manipulation - two
fingers on a touch screen - and says each step's scale since the last, and
where, as shares of its size. Taking the manipulation keeps the platform's
own panning off that view's touches.

## A button held down

A button held down - by the pointer, or by Space or Enter on the keyboard -
is told as pressed, and let go as released, apart from its click: the relay
follows WinUI's own `IsPressed`, which the button's pressed look follows too.
A scroller taken hold of and let go arrives by the same road, each view
answering what holding means for it.

## The keyboard coming in

A view whose element hears `isFocusedChanged` is told when the keyboard comes
into it - to it, or to what stands in it, as a number box's own field - and
when it leaves. WinUI's `GotFocus` and `LostFocus` bubble from inside the
element, so as each arrives the relay asks where the keyboard is now, the
act of moving the focus asking the same, and tells only a change.

## A drag between views

A view's drags are WinUI's own drag and drop, through the relay
(`Drags.cpp`): what the view offers stands in a table by its number, and its
handlers, hung once on each element it stands as, ask it as they run - a
password field's new box gets them again as it takes the field's place, and
a view offering nothing, one that left among them, is gone from the table.
A view that can be dragged has
`CanDrag`; its `DragStarting` puts the view's words on the drag's data as
text, to be copied, and its `DropCompleted` says the drag ended wherever it
ended. A view taking drops has `AllowDrop`; a drag whose data holds text
where it takes words, or storage items where it takes files, is accepted
over it - `DragEnter` and `DragOver` say it is over, `DragLeave` that it
went - and its `Drop` reads the text, or each item's path and name, holding the
drop's deferral until they are read. The host layer's rule makes over once
and no leave after a drop.
