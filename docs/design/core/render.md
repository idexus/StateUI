# The render

`Renderer` turns the application into the patch a host applies. It holds the
application, knows what changed since the last render, runs the differ, and
hands the result to the host typed, as a `HostRender`.
There is one renderer per process, `Renderer.shared`, because there is one
host per process.

## One renderer

The renderer is entered only from the host's UI thread, synchronously, through
the typed `HostBoundary` SPI. It is `@unchecked Sendable` rather than
`@MainActor`: isolating it would add an `assumeIsolated` to every entry point
for a promise the compiler cannot check across a relay's callbacks anyway. The part that can suspend - a handler - is what `@MainActor` names.

What more than one thread touches stands behind the renderer's `guarded` lock:
the change bookkeeping, the live reader counts, the act queue, the completion
registry and the counters beside them. A write to a `@State` may come from a
`Task.detached` or an `async let` child on the cooperative pool, and an act
may be sent from one. Closures taken out of the registry are always invoked
after the lock is released, because a resumed continuation can re-enter `send`
and the lock is not reentrant.

## Three roads

A render takes one of three roads, decided before anything is built:

```text
  describeAll = baseline != generation || nothing rendered yet
  walks       = something rendered, !describeAll, every cause named its state,
                and no cause is among what the root build read

  walks        -> Differ.revisit(current, changed:)    the clean walk
  otherwise    -> build the root, Differ.reconcile(...) a build
  describeAll  -> the patch carries every element in full (a resync)
```

The clean walk skips the application's closure entirely: only the elements
whose recorded reads intersect the changed states are built again, and their
ancestors contribute only the path of patches down to them. It is sound only
when every cause of the render named the state it wrote; a plain
`setNeedsRender()` names nothing and forces a build.

The root build reads the open scenes, whatever the application's `scene`
reads, and the application session's styles and motion. Those reads are kept
as `rootReads`; a change to any of them means the application has to be
built again.

## Generations and baseline

A patch means something only against the exact tree it was computed from. The
host quotes back the generation of the last message it applied in full, and
gets a sparse patch only while that matches. Anything else - a first render, a
host that failed half way through a message, a second host showing the same
interface - gets the complete tree.

The complete tree is still reconciled against the tree this side holds, never
against nothing: a resync changes what the message carries, not who anything
is. Keys, handler ids and every `@State` survive it. Reconciling against
nothing would reset every state to its initial value and leave the previous
handler registry reachable from stale controls.

Zero is the host's own "start over" and is never a generation this side
issues; a counter that wraps skips it.

## Taking the changes

The changed states, their names and the untracked flag are taken and cleared
in one locked step before anything is built, and `rendering` is set in the
same step. A write that lands while the render runs then stays on the books
and asks for the next render instead of being wiped by this one's clear. The
cost is at most one clean walk that finds nothing; the other direction would
be a control left stale and a handler left waiting on an update nobody draws.

## Handlers in the message

What an element says as it comes into the tree belongs in the message that
brings it. `.onCreated` is where a page gets its title and buttons and a
window its size, and the platform acts on the message that makes the element:
a page presented without its style is presented wrong.

So after the walk, the handlers it found - `.onDestroying` of what left, then
`.onCreated` and `.onChanged` in the order they were reached - run at once,
each up to its first suspension. What they wrote is walked and merged into
the same message, up to `settleLimit` passes. Three passes cover a handler
that writes, a view that arrives with a handler of its own that writes, and
one more; a longer chain is a loop and takes a render per step.

The handlers never run from inside the walk: a handler may write `@State`,
and a write landing mid-walk would be cleared by that walk's bookkeeping.
Handlers found by the last pass, with no pass left to run them, are queued on
`MainActor` rather than started: started at once, their writes would land
after the host's "does anything need rendering" look and wait for the next
event.

## Self-dirtying renders

A render that ends with the tree dirty again is, once, a write that crossed
from another thread while it ran. A streak of `selfDirtyLimit` such renders is
a body that writes the state it reads, which the bookkeeping would otherwise
turn into a render loop. The streak is how that author error is told apart
from a legitimate crossing without knowing which thread wrote: nothing that
crosses legitimately does so on every consecutive render. The error is
reported and the pending change dropped once, which ends the loop. The check
runs before the settle passes, so a handler's write is never taken for a
body's.

## Starting a handler

Every handler runs on `MainActor`, inside a task, which gives it somewhere to
suspend. There are three ways in, one path each:

```text
  start(handler)   an event the host dispatched: the payload is read NOW,
                   then begin(...)
  run(handler)     a handler a render's walk found, run in a settle pass
  queue(handler)   a handler found with no settle pass left: Task on MainActor,
                   a later turn of the UI thread
```

`begin` uses `Task.immediate`, which starts the task on the calling thread -
the host's UI thread, which is `MainActor`'s - so a handler with no `await`
finishes before the dispatch returns and the host renders what it wrote in
the same turn. Where the runtime cannot start the task inline, it lands in
the UI thread's queue and the drain that follows runs it.

`dispatch` answers whether a handler was found, not whether it finished. An
unknown id is an event for an element that has already left the tree, or an
act already answered; ignoring it is correct.

## The event and reply buffers

An event's payload reaches its handler through `EventBuffer`, and an act's
outcome reaches its continuation through `ReplyBuffer`. A side channel keeps
`HostBoundary.dispatch` to one id and one payload instead of a variant per
event shape. `start` reads the payload before the task begins, so a handler
that suspends keeps the payload it started with. The two buffers stay apart
because an outcome is values or a failure and an event is only values.

`CarriedHandler` hands a handler into its task. The handler lives in the
differ's registry, which the compiler reads as shared state; the task is
isolated to `MainActor` and the registry is only touched there, so the
promise is made in this one place instead of making `EventHandler` `Sendable`
and stopping authors from capturing their own state.

## A new application

Registering an application starts a new tree: the previous tree is forgotten
(handlers, engines, root reads), the application session is reset, one scene
waits for the platform's first window, and the next render describes the
whole of the new application - every element arriving, which is what
`.onCreated` is told. The application's own `@State` properties are named by
reflection once, as it registers, because the application is never walked
like a view.

Until an application registers, the tree is an application with one scene,
one window and a page holding a label, in the shape a real one produces, so a
host has one thing to read.
