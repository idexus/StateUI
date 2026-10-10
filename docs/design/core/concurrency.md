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
                               on its UI thread through HostBoundary.runJobs.
```

A host's start installs the executor: its first call, before anything starts a
task, is `HostBoundary.claimUIThread()`, which installs it and drains once on
that thread. A job running when `MainActor`'s executor is replaced was started
by the one before, and `Task.immediate` from it no longer finds itself on
`MainActor`. So nothing else installs it - not the renderer, which a test makes
in the middle of its first `@MainActor` test. A process with no host, such as
a test of the core, keeps the platform's main queue, which its run loop drains
as on Apple. The factory is `@_spi(ExperimentalCustomExecutors)`; its shape is
that of the one Swift release the project builds with.

Nothing waits for the platform's main queue in shared code - nothing drains it
on Android or Windows - and nothing uses a run-loop timer, which hangs off a run
loop nothing turns there. A timer is `Task.sleep` (cycle.md).

## WebAssembly

```text
  WebAssembly                  one thread, and the browser's event loop around
                               it: no thread parks, and nothing turns a main
                               queue. UIThreadExecutor is every task's executor
                               - MainActor's, the default one and a sleep's - and
                               the Web host drains it in the turn every call
                               from the page ends with.
```

A program in a page runs only inside a call the page makes - its start, a
listener, a display frame, a wake - so whatever a call leaves is collected by
the turn that ends it. The Web host says no way to post a turn, and nothing
waits on the one thread the page has.

Every task runs on the one executor: a task the application starts, an `async
let`'s child and a detached task alike, as no other executor is drained in a
page. A sleep is a job kept for later in the executor's timetable, ordered by
the time it comes due (`Timetable`); a drain moves the jobs due by then to the
queue before it runs them. `Task.sleep` reaches the default executor, so the
executor answers as the default one for a sleep to be kept at all.

Instead of a doorbell the page is told when to call again:
`HostBoundary.nextWake` answers at once where jobs, acts or a render wait,
else the time until the next job kept for later comes due, and nothing with
nothing to come. A cycle is a display frame's, which the display cycle holds
the clock for, so it is no reason to call - a host that called for it would
call without end while an engine runs.

## Handlers run where their event arrives

A handler starts with `Task.immediate`, which runs it on the UI thread up to its
first suspension before the call that raised the event returns - unless its
gate holds it back: a run that waits starts when the run before it ends, and
one let go never starts. A handler with
no `await` finishes inside its event, and the host renders what it wrote in the
same turn. Only a handler that really awaits comes back later, on the same
thread (render.md).

Every async function in the library is `@MainActor`, or runs on its caller's
executor: every manifest compiles its Swift with that as the default
(`NonisolatedNonsendingByDefault`), so no declaration spells it. Without it, a
plain async function runs on Swift's cooperative pool whoever calls it, and a
handler awaiting one would come back on a pool thread with the host drawing
beside it. A test holds every Swift target of every manifest to the setting.

## The host is never called back

Handing each job to a host function pointer is a trap. `resume()` produces its
job on a cooperative-pool thread, so such a callback enters the host from a
thread its runtime has never seen. A relay in a platform's own language - Java
through JNI - attaches that thread on the way in, and on Android, with a
debugger attached, the attach can deadlock the UI thread: the app freezes at
the first `await` in a handler and stops receiving touches, while the same
build without a debugger is fine. So no job is handed to the host: the core
only rings the doorbell - the host's own thread-safe post (`postTurns`), which
enters no runtime - and the host runs the jobs on its UI thread through
`HostBoundary.runJobs()`.

## The doorbell

Work can arrive when no act is in flight at all: `Task.sleep` coming due, a task
an author started finishing, a stream yielding. Each is a job queued from
another thread; and work the UI thread makes outside a turn - an application's
own callback writing a state - has no turn after it either. The doorbell is how
both reach the UI thread: the host says once, at its start, how a turn is put on
its UI thread's queue from any thread (`HostBoundary.postTurns`), and the core
posts one whenever there is work and none waits:

```text
  a job enqueued, on whatever thread queued it      the UI thread: a state written,
                                                    an act sent, a save recorded, a
                                                    value written to a board
                                                    between cycles
                    \                               /
                     v                             v
  askForTurn: ONE turn posted, the host's own thread-safe way (postTurns),
              until that turn's drain begins
  host turn on the UI thread:  run jobs -> a pending cycle -> render -> acts
```

No thread waits for work: the post happens on the thread that made the work,
inside the executor's `enqueue` for a job, outside its lock. A turn is asked
for at most once until its drain begins, so a thousand jobs inside one drain
post one turn, and what comes after the drain began posts the next. Saying how
to post posts one turn at once, for whatever was queued before the host said.
Where the loop turns by itself the host says no way to post: Apple has no
doorbell - `MainActor`'s jobs are the main queue's, and its hosts take a turn as
each pass of the main run loop ends (../host/runtime.md#the-turn-on-apple) - and
the Web host turns as every call from the page ends. An `async main` with no
host runs the executor's own loop (`MainExecutor.run`, away from Apple), whose
way to post is a signal it waits for itself.

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

## What stands behind a lock

A state is the UI thread's, and so is everything the renderer, a board, the
stores and a storage keep: none of it stands behind a lock. What another
thread does touch stands inside a `Mutex` of its own, as the value it holds:
the executor's queue, its turn flag and the host's way to post a turn; a
state's posts waiting in its mailroom for the UI thread (state.md#posting); the
application's events raised and waiting (`RaisedEvents`); and the complaints
said (`Said`). A run's superseded flag and the count of superseded runs are
atomics, which a write reads from any task under the run; in a debug build
the stamps of what a run read stand in a `Mutex` beside them.

A `Mutex` is not reentrant: a body that asks for the same lock again
deadlocks. So what a body takes out - a job to run, a write to book - runs
after `withLock` returns, and a wake only signals outside it. No body holds
two: a post books its entry under the mailroom's one lock and starts the job
after letting it go.

## What the compiler checks

The core makes no promise the compiler cannot check: it has no `@unchecked
Sendable`, no `nonisolated(unsafe)` and no `assumeIsolated`, which
`UIThreadTests` holds. The renderer, a `State`, a `Binding`, a board and the
stores are `@MainActor`; what crosses threads is `Sendable` by what it holds -
the executor, a mailroom, the raised events and the complaints said over a
`Mutex`, a handler's run over atomics. Where a platform calls in on its UI
thread, a fact the compiler cannot see, the host says it once as the call
enters, with `MainActor.assumeIsolated`.
