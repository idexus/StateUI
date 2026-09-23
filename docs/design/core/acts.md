# Acts

The tree says what the interface is. Some things are not a shape but something
that happens - navigate, show an alert, copy to the clipboard, put the keyboard
on a field - and Swift can no more perform those than it can create a label:
they are calls on the host's native objects. So the same split applies: Swift
describes the act and the host performs it.

```text
  handler: try await Dialogs.alert("Saved", message: "…")
     |
     v  Renderer.send -> ActCall(act, arguments, completion: -7) in the queue
     |                   (completion ids count down from -1)
     |  the handler suspends; the host is woken
     v
  host turn: takeActCalls / stateui_take_act_calls_wire     receipt kept: [-7]
     |  the host performs each act on its native objects
     v
  StateUIHost.reply(-7, with:) / stateui_dispatch_wire(-7, reply bytes)
     |
     v  Renderer.dispatch(-7): the continuation resumes on MainActor
  handler: the next line runs with the alert gone
```

## An act is a member

An act is a member of a contract - the library's are `ApplicationContract`'s and
its elements' - whose documentation says what the host does for it. On the wire
it crosses as the session dictionary's number for its name, announced by the
first batch that uses it (wire.md). An act of an element is aimed through an
`@Aim`; an act of the application aims at nothing and is called with
`stateUICall` or `stateUISend`. Arguments and answers are the values the
member declares, checked on the way back: an answer of another shape throws.

## The act queue

Acts wait in the renderer's queue until the host takes them, at the end of its
turn, after the render - so an act lands on the interface its handler just
changed. The queue and the completion registry are behind the renderer's lock
because they are the one part of it a child task reaches: `async let` runs its
child on the cooperative pool, so two animations started that way send from
pool threads while the UI thread takes acts and dispatches completions.
Unguarded, that race loses a continuation (a handler frozen at its `await`) on
a good day and corrupts memory on a bad one.

## Waking the host for an act

An act queued from a plain `Task` runs on the pool and lands no job on the UI
thread's executor, so nothing else would tell the host it exists - it would sit
in the queue until the next event, a pressed card never coming back up. So
`send` wakes the host after queueing, outside the lock; the executor's armed
flag folds a burst of sends into one wake. The doorbell counts queued acts and
waiting saves as work (concurrency.md).

## Completion ids

A continuation waiting for an act is registered under a negative id, counting
down from -1. Element handler ids are positive, so the two kinds stay apart on
a boundary that carries nothing but a number. The same counter serves an
animation's waiter (journeys.md), so a completion the host answers can never be
read as anything else. Completions belong to no element: they are one-shot,
outlive the render that created them, and are never swept when the tree is
rebuilt.

## Awaiting an answer

`Renderer.call` and every async API here are `nonisolated(nonsending)`: they
run, and resume, on the executor of whoever called them, which for a handler is
`MainActor`. A plain async function would run on the cooperative pool, and the
caller would come back to life beside a render the host is running. The reply
crosses as tagged values, so nothing is parsed: `focus` reads one bool, the
clock its numbers, and a failure throws `StateUIError` with the host's reason.

A resume is counted the moment the continuation is resumed and uncounted by the
handler as the first thing after its `await`. The job a resume produces does not
exist yet when the outcome is reported - it lands a moment later and wakes the
doorbell - so a test waiting for a quiet queue reads this count to tell "the
resume has not landed yet" from "nothing to wait for". `dispatch` runs nothing
for a completion, for the same reason.

## A batch is not a transaction

The host takes the queue in order and starts each act in that order, but an act
that waits - a dialog waiting for the user, a scroll animating to a row - does
not hold up the one behind it, so answers come back in whatever order the host
finishes them. What puts one act after another is `await`: a handler that
awaits the first queues the second only once the answer is in.

## The receipt

Taking a batch keeps its completion ids as a receipt, overwritten by every take.
A batch the host cannot read at all has lost its ids inside the very bytes that
would not read; only this side still knows them, and `failTakenActCalls` fails
each one through the ordinary reply path, so every awaiting handler resumes by
throwing instead of waiting for ever. It is not a timeout: an act may wait
without bound - a dialog waits for the user - so the failure is causal, told by
the side that failed. Failing twice fails nobody twice, and an act answered in
the meantime is safe, `dispatch` answering false for a completion already gone.

A Swift host never needs the receipt: it takes typed calls and answers each by
its id (`StateUIHost.reply`, `StateUIHost.fail`). A reply that cannot be read
resumes its handler with a failure, never a hang.

## Saves ride as acts

The values kept states and scenes are waiting to save become acts when the queue
is taken: one per key, holding the last value, sorted by name. A key written five
times between two takes is one act (state.md). A handler that throws is reported
the same way, as an ordinary act the host logs.

## Aims

An act aimed at a control has to say which control, and a description rebuilt
every render has no object to point at. What survives a render is the
element's key, and an `Aim` is that key, declared where the view declares its
state:

```text
  @Aim(WebView.self) private var browser         declared, typed by the control
  WebView(address).aim(browser)                  put on a view
  try await browser.goBack()                     an act the control's type offers

  the differ, reaching the element, writes its key into the aim's box
  the act sends it as argument 0: a number, or the .id() name as text
  the host resolves either back to its control
```

What an author holds is declared one way for each kind: a value with `@State`,
which is written; a control with `@Aim`, which is called. Which member is which
follows what the native toolkits share: a value every host can hold and set is a
property, and something that happens is an act. Focusing, moving a map to a
region and stepping a web view back are acts - the platforms keep that state
read-only, or it means "again", which no value can say on a wire where an
absent field means unchanged. A scroller's offset is state both ways instead,
because this side has an engine to move it with.

`Node.aim` holds an untyped `AimBox`, because a node is not generic; the typed
`Aim<Target>` is what the author holds, and its type parameter is only surface:
it offers `goBack()` on a web view's aim and nowhere else. A fresh aim adopts
its predecessor's box by the path the walk found it at, as a fresh `@State`
adopts storage, so a handler captured three renders ago aims where one captured
now does. The differ refills the box on every walk that visits the element; the
key is stable, so the write is idempotent.

An aim takes no part in matching: a view carrying only an aim is identified by
its builder path or position, as if nothing were written on it. A named row
that an act can also reach is `.id("row-7").aim(row)`. The identity of a manual
key crosses as text, exactly as an element's own manual id does; it is not a
vocabulary entry the dictionary numbers.

An aim put on two views in one walk is a conflict; the next act reports it and
the next walk's first attachment clears it. An act on an aim that reached no view
throws. An aim whose view left the tree keeps its last key, and the act reports
that no such view is on screen.

## An aim a view is handed

`@Aim` declares an aim; a plain stored property holding one - a child given its
parent's - borrows it. A borrowed aim is compared by the box it aims through and
never adopted, or a child handed another aim in the same place would take over
the one its parent holds. The walk tells the two apart by name: a wrapper's
backing property is the declared name with a leading underscore. An aim in a
model is the model's; the walk never enters a model.

## Focus and the keyboard

Focus is an act with two forms: `field.focus()` on a known view, and
`OnScreenKeyboard.hide()` for whatever has the keyboard. The focused control is
whichever one the user touched last, so the host asks its native focus system,
and StateUI does not mirror that identity as state. The second form lets a Done
button close a keyboard it did not open. On iOS a search field on the
navigation bar takes the whole bar while it has focus, the back button with it;
`hide()` is what gives the bar back, which is why the keyboard sample offers it.

## Dialogs

A dialog is not a shape, so it is an act: the handler suspends while the dialog
is up and resumes with the answer. Asking, waiting and branching is one
sequential thought; an act keeps it in one place where a binding would split it
into a state write here and a result closure there. No dialog names a page:
a handler holds a description of a page, not the page, so the host shows the
dialog on the page the user is looking at, the top of the modal stack
included, which only the host can know.

## Announcements

`ScreenReader.announce` is an act for the same reason every act is one: it is
something that happens, at a moment, and no value on a tree can say "again".
It is for a change the user is not looking at - a finished search, a deleted
row - and nothing happens where no screen reader runs.

## Host events

An event the host raises by name has no element behind it - connectivity
changing, the battery reporting - so the application declares it in an
`ApplicationTier`, registers the raise with the host, and subscribes with
`HostEvents.on`. The name crosses in the buffer and the values arrive as the
types the member declares; a raise of another shape is reported once and does
not reach the handler. Handlers run in subscription order, each started on
`MainActor` exactly as a control's handler is, taken under the lock and started
outside it. Subscription ids are never reused, so a cancelled subscription
cannot take a newer listener with it. A raise nobody subscribed to is an
ordinary zero, and prefixing event names with the application's own keeps them
from ever meeting one this library adds.
