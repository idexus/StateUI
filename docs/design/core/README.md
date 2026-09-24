# The core

The core is `lib/StateUI/Sources/Core`: state, invalidation, keys and
diffing, the display cycle, acts, the UI thread's executor and the typed
boundary a host reads. It holds the reasons behind the code; the code's
comments say what a thing is and point here. Every note describes the
current design, its reason and its trap.

The core's sources stand in one folder per topic, one element to a file, and
[Where things live](#where-things-live) says which folder holds what.

## The notes

| Note | What it covers |
| --- | --- |
| [render.md](render.md) | the renderer, the three roads of a render, generations, handlers in the message, starting a handler |
| [invalidation.md](invalidation.md) | reads and changes, live readers, writes during a render, `debugInfo()` |
| [identity-and-diffing.md](identity-and-diffing.md) | keys, state surviving a rebuild, carrying a view, the clean walk, what a patch carries, recycling |
| [state.md](state.md) | storage and box, bindings, model state, carried state, kept and scene-kept state, the environment |
| [journeys.md](journeys.md) | the journey lanes, the law on the image, moving and waiting, readings, conversions, motion laws |
| [cycle.md](cycle.md) | the board, where a write lands, host reports, engines, state numbers, the ticker |
| [acts.md](acts.md) | acts, completion ids, aims, focus, dialogs, host events |
| [concurrency.md](concurrency.md) | `MainActor` on every platform, the doorbell, draining jobs, the lock and its order |
| [contracts.md](contracts.md) | contracts and tiers, member facts, values that cross, tokens, realizations |
| [scenes.md](scenes.md) | the scene tree, sessions, what the platform keeps, connecting and ending scenes |
| [diagnostics.md](diagnostics.md) | the tally, the inspector, complaints |

## The core at a glance

```text
  application     Application -> Scene -> Window -> Page -> views
                  bodies READ @State; handlers WRITE @State and call acts
        |
        v
  +---------------------------- StateUI core -----------------------------+
  |                                                                        |
  |   @State box --adopt--> State.Storage ---------------------------+     |
  |                          | read at build: ReadScope records it   |     |
  |                          | write: Renderer.stateChanged          |     |
  |                          v                                       |     |
  |   Renderer --- render(baseline) ---> Differ                      |     |
  |     changed, readers,     walk / build / complete                |     |
  |     generation            keys, adoption, carry, handlers        |     |
  |                           |                                      |     |
  |                           v                                      |     |
  |                     RenderedNode tree  +  HostPatch (sparse)      |     |
  |                                                                  |     |
  |   handed on as $x ---------------------------------------------- +     |
  |     HostStorage image  --  CycleBoard: latch, engines, publish         |
  |                                                                        |
  |   act queue, completions        UIThreadExecutor (MainActor), doorbell |
  +------------------------------------------------------------------------+
        |  typed: HostRender, HostCycle, HostActCall (StateUIHost)
        v
  a Swift host in this process
```

Two reactive paths leave the same state. A body that read a state is rebuilt
when it is written, diffed, and arrives at the host as a patch (reactive path
1). A state handed on as `$x` is carried by the host on an image both sides
rewrite; it moves on the display cycle with no rebuild at all (reactive path 2).

## The typed boundary

Every host is Swift in the application's process. It links the core's dynamic
library and calls `StateUIHost`, behind `@_spi(Host)`: `render(baseline:)`
answers a typed `HostRender` holding the sparse `HostPatch`, `cycle` a
`HostCycle`, `takeActCalls` typed `HostActCall`s, and the reports come back
the same way - `dispatch`, `report`, `reply`, `raise`, one setter per standard
provider. One process holds one copy of StateUI's types, and nothing
serializes the patch between the core and a host. Code in a platform's own
language - Java through JNI, C++ behind a C ABI - is a relay beneath the Swift
host and never calls the core.

## A state write from start to finish

```text
  handler: count += 1                        on MainActor, or from any thread
     |
     v  State.wrappedValue.set -> Storage.write     under the storage's lock
     |
     v  Storage.askForRender()
  never read at build? -------------------> nothing more: one load
     |
     v  Renderer.stateChanged(storage)
  no live reader and no render running? --> refused, counted in the tally
     |
     |  dirty = true; changed += storage; its name kept for debugInfo()
     v  UIThreadExecutor.poke()
  doorbell thread wakes, posts one turn onto the UI thread
     |
     v  host turn:  run jobs -> a pending cycle -> RENDER -> take acts
  Renderer.render(baseline: the generation the host holds)
     |  take and clear the changes in one locked step
     |
     |  clean walk   every cause named its state, none read by the root
     |  build        the root built again and reconciled
     |  complete     baseline != generation: every element in full
     v
  Differ: elements whose reads meet the changes are built again;
          composed views built with the same inputs are carried;
          children matched by .id(), builder path, position
     |
     v  settle passes: .onDestroying, .onCreated, .onChanged run now,
     |  what they write is walked and merged - up to three passes
     v
  HostPatch -> HostRender
     |
     v  the host applies it and keeps the generation only if it went in whole
```

## The display cycle

```text
  host frame tick (now, ms)
     |
     |  the host animates carried values with HostMotionLaw and reports
     |  the user's changes and its frames, lane by lane
     v                                    StateUIHost.report
  CycleBoard.cycle(now)
     1  latch     pending writes -> image; reported lanes are never echoed
     2  engines   by ascending priority - a conversion's back (-2) and
                  forward (-1) engines ahead of the author's (0 unless said) -
                  each only with a reason: armed by a render, stirred by a
                  followed write, or awake after answering .again
     3  publish   image -> published; dirty lanes collected
     |
     v                                    HostCycle.changes
  the host writes each moved value onto every control bound to that state
     |
     |  a state some body read asks for a render; a journey's frame asks only
     |  the bodies that read the journey
     v
  the frame clock stays held while an engine answers .again or anything waits
```

## The UI thread

```text
  UI thread (the host's)                       any other thread
  -----------------------------------------    ----------------------------------
  event   StateUIHost.dispatch(id, payload)    a Task.detached or async let child
          Renderer.dispatch                      writes @State, sends an act,
          Task.immediate on MainActor            writes a board between cycles
          -> the handler runs to its first           |  poke(), outside every lock
             await, inside the event                 v
                                               doorbell thread (the host made it)
  turn    StateUIHost.runJobs: MainActor's jobs  parked in waitForWork
          (Apple: the main queue's instead)      wakes, counts the work, posts
          a pending cycle, a render, the acts    ONE turn onto the UI thread
                                                 and parks again
  resume  a continuation's job lands on
          MainActor's executor -> next drain   nothing ever runs on it
```

The library never calls the host back: a resume produces its job on a pool
thread, and entering a runtime from a thread it has never seen can deadlock the
UI thread under a debugger. The host asks instead (concurrency.md).

## Where things live

Each folder of `lib/StateUI/Sources/Core` is one topic, and the note beside it
holds its reasons. A type's extensions stand in its folder, named
`Type+Responsibility.swift`.

```text
  Core/State        @State and its storage, Binding, kept state,          state
                    @Environment, element sessions, the @Observable refusal
  Core/Carried      what a carried value is: StateValue and its image,    state, cycle
                    the attachments, HostStorage's three copies
  Core/Journey      Journey and its lanes, the law on the image, the two  journeys
                    motion laws, readings, conversions, .multi
  Core/Cycle        the board, engines, the ticker                        cycle
  Core/Render       the renderer, with its cycle, act queue and dispatch; render, acts,
                    read scopes, debugInfo()                              invalidation
  Core/Diff         the differ, Node, RenderedNode, placeholders and      identity-and-diffing
                    inputs, .onChanged, .onCreated, .onDestroying, rows
  Core/Acts         acts and replies, aims, focus, dialogs, the screen    acts
                    reader, host events
  Core/Threads      the UI thread's executor, the doorbell, the lock      concurrency
  Core/Boundary     the typed SPI: StateUIHost, HostRender, HostPatch     (this note)
                    and the values it carries, SVG path data
  Core/Contract     contracts and tiers, members, their facts and         contracts
                    values, the tokens
  Core/Realization  a host's registry and reports, realizations and       contracts
                    declarations
  Core/Scenes       scenes, their records and element, a value as text    scenes
  Core/Diagnostics  the inspector, complaints                             diagnostics
```
