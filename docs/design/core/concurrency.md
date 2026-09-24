# Concurrency

The library has no thread and no run loop of its own. Everything it does
happens inside a call the host makes - a render, an event, an act answered, a
cycle - on the host's UI thread, whose actor is Swift's `MainActor` on every
platform. A handler runs on `MainActor` and may suspend; it resumes on
`MainActor`'s executor.

## MainActor on every platform

```text
  Apple                        MainActor's executor is the main queue, drained
                               by the platform's own event loop on the thread
                               it draws on. Nothing here replaces it.

  Android, Windows, Linux      the main queue would be libdispatch's, and
                               nothing drains it: the UI thread turns its own
                               loop (Looper, the message pump, GTK's main loop),
                               and a handler would suspend at its first await
                               and never wake. So MainActor's executor is
                               UIThreadExecutor, installed through Swift's
                               executor factory before the first task; it
                               queues each job, and the host drains the queue
                               on its UI thread through StateUIHost.runJobs.
```

The executor is installed as the renderer is made, before anything here starts a
task: `MainActor`'s executor is chosen when it is first used. The factory is
`@_spi(ExperimentalCustomExecutors)`; its shape is that of the one Swift release
the project builds with.

Nothing waits for the platform's main queue in shared code - nothing drains it
on Android or Windows - and nothing uses a run-loop timer, which hangs off a run
loop nothing turns there. A timer is `Task.sleep` (cycle.md).

## Handlers run where their event arrives

A handler starts with `Task.immediate`, which runs it on the UI thread up to its
first suspension before the call that raised the event returns. A handler with
no `await` finishes inside its event, and the host renders what it wrote in the
same turn. Only a handler that really awaits comes back later, on the same
thread (render.md).

Every async function in the library is `nonisolated(nonsending)`, or names
`@MainActor` outright: it runs on its caller's executor. A plain async function
runs on Swift's cooperative pool whoever calls it, so a handler awaiting one
would come back on a pool thread with the host drawing beside it. A test holds
every async declaration in the library to one of the two spellings.

## The host is never called back

Handing each job to a host function pointer is a trap. `resume()` produces its
job on a cooperative-pool thread, so such a callback enters the host from a
thread its runtime has never seen. A relay in a platform's own language - Java
through JNI - attaches that thread on the way in, and on Android, with a
debugger attached, the attach can deadlock the UI thread: the app freezes at
the first `await` in a handler and stops receiving touches, while the same
build without a debugger is fine. So nothing here calls out; the host asks,
through `StateUIHost.runJobs()`.

## The doorbell

Work can arrive when no act is in flight at all: `Task.sleep` coming due, a task
an author started finishing, a stream yielding. So the host parks a thread of
its own in `StateUIHost.waitForWork()`, and that thread is
the doorbell:

```text
  doorbell thread (the host created it, so its runtime has always known it)
    |  parked in UIThreadExecutor.waitForWork()
    |  woken by: a job enqueued, a state write, an act sent, a save recorded,
    |            a value written to a board between cycles   (poke)
    v
  answers how much is waiting:
    jobs queued + acts and saves not taken + a dirty tree + a board awake
    |
    v  posts ONE turn onto the UI thread, the toolkit's own thread-safe way
  host turn on the UI thread:  run jobs -> a pending cycle -> render -> acts
```

Nothing runs on the doorbell thread; it only asks. A wake is signalled at most
once per park - the armed flag folds a thousand wakes inside one drain into
one - and the count may be zero when another turn got there first. On Apple
the doorbell rings for the work the main queue does not carry; `MainActor`'s
jobs are the main queue's.

## Draining jobs

`drain()` runs every queued job on the calling thread and answers how many ran.
It loops, because a job can queue another - a handler that awaits twice comes
back through here each time - and is bounded, so a job that requeues itself for
ever cannot take the UI thread with it; the host asks again. Jobs run outside
the queue's lock, or a job that queues another would deadlock. A second drain
entered meanwhile returns at once: two threads must never run `MainActor`'s jobs
side by side.

Where something does turn the platform's main queue - a test's run loop, a tool
calling `dispatchMain` - the executor posts one drain there too, so
`MainActor` works in those processes as well. The post is a work item, not a
closure: a closure handed to the main queue is `MainActor`'s, and the runtime
asks the executor whether the thread running it is `MainActor`'s before the
first statement - on Windows a thread of the queue's own, where the answer is no
and the process stops. A work item is isolated to nobody, and what runs inside
it is the executor's own drain.

## Isolation checks

The runtime asks the executor whether the calling thread is its isolation
whenever code claims to be where it belongs already: `MainActor.run` from
`MainActor`, `assumeIsolated`, `assertIsolated`, a resume that could stay on its
thread. An executor that does not answer gets the default, which stops the
process. `UIThreadExecutor` answers by remembering the thread its last drain ran
on: jobs run inside a drain and nowhere else, and a drain is serial, so the
draining thread is where `MainActor` stands - and on Windows, where the main
queue has a thread of its own, the draining one rather than the host's. It is
not the thread the executor was made on, which may be a pool thread enqueueing
the first job.

## The lock

`Lock` (Lock.swift) is what state more than one thread touches
stands behind: a storage's value, the renderer's bookkeeping, a board's images,
the act queue. It is a `Mutex` guarding nothing, with the state beside it
rather than in it, because what it guards is often no value a mutex could hold:
a `@State`'s value is whatever type its author declares, `Sendable` or not, and
a value handed into a mutex has to be `sending`, which a property setter cannot
promise. An uncontended hold costs a few nanoseconds.

It is not reentrant: a body that asks for the same lock again deadlocks. So what
a body takes out - a continuation to resume, a handler to call - runs after
`withLock` returns, and a wake only signals outside every lock.

## Lock order

```text
  State.Storage's lock   before   the persistent store's and a scene record's
                                  (a save is recorded from under the storage)
  State.Storage's lock   before   a board's hold   (carry() makes the image)
  a board's hold         never around an engine's run, nor around a wake
  the renderer's lock    never around a wake - the executor's lock is never
                         taken inside it
```

Where a lock would take two of these in the other order, the read goes without
it: an engine's `stirred()` reads a storage's write count as an atomic under the
board's hold (cycle.md), and `hydrate` lands stored values after letting go of
the store (state.md).

## Unchecked sendability

The renderer, a `State`, a `Binding`, a board, the stores and the executor are
`@unchecked Sendable`. What makes each safe is either its lock or a fact the
compiler cannot see: a host calls in from one thread, and the handler registry
is touched only on `MainActor`. `@unchecked` is written where that promise is
made, rather than by loosening a type for everyone - a `Sendable`
`EventHandler` would stop authors capturing their own state in handlers.

The pieces written only by the thread that renders - the build frame, the
inspector's record, the event and reply buffers - are `nonisolated(unsafe)`
statics for the same reason.
