# The C bridge

A runtime in another language reaches the core through C functions, all of them
in one file, Bridge/Exports.swift. A Swift host uses the typed `StateUIHost`
SPI instead; both reach the same `Renderer`.

```text
  runtime in another language              Swift host
        |  stateui_* (C ABI, Wire bytes)        |  StateUIHost (typed, @_spi(Host))
        v                                       v
  Bridge/Exports.swift  ------------------>  Renderer.shared, Scenes, stores,
                                             UIThreadExecutor, HostEvents
```

## One file of exports

Every `@_cdecl` in the library lives in Exports.swift. `@_cdecl` is an
underscored, compiler-private attribute, so keeping every use together makes a
move to an official spelling a local change, and it keeps the exported surface
easy to audit: what is there is the whole API such a runtime can reach. A test
refuses an export anywhere else, and the Windows build's export scan reads the
sources with comment lines dropped, so a name shown in a comment is never
exported.

The dependency runs application to library, never back. An application module
registers its `Application` through `stateUIUseApp` and exposes its own entry
point for the host to call; the library knows nothing about any application,
which is what lets it be published on its own.

## C types only

An export is a global function whose parameters and results are representable in
C: integers, doubles and pointers - no `String`, array, class, generic or
`throws`. A value crosses as Wire bytes (wire.md) or as a UTF-8 C string.

## Memory is freed where it was allocated

Memory handed to the caller is allocated here with `allocate` and released here,
through `stateui_free_buffer` or `stateui_free_string`. Allocation and release
happen on the same side with the same allocator on every platform; mixing
allocators crashes unpredictably, and on Windows several C runtime copies can
coexist, which makes `strdup` and `free` unreliable. Buffers the caller passes
in are read before the call returns and never kept, so there is nothing to
free. An empty message is a null pointer - the acts taken on a quiet turn, the
keys of an application that keeps nothing - so the common case allocates
nothing.

## The wire suffix

The exports that carry Wire bytes end in `_wire`: render, dispatch, take act
calls, set realization. The suffix names the format, so a half built for another
format calls a name that is not there and fails to find the entry point - a
clean, nameable error - where one name over two signatures would read a register
as a pointer. `stateui_wire_version` is asked before the first render, and a
library too old to have it fails the same check one step earlier.

## Answers

```text
  1 / count   done; a handler ran; how many heard it
  0           nothing to do, or an id nobody holds - an event for an element
              that has left the tree is not an error
  -1          a buffer that would not read: the host reports version skew
```

A reply that cannot be read still resumes the handler waiting on it, with a
failure, never a hang. A payload that cannot be read is treated as empty, so the
typed readers leave handler and binding alone. A batch of acts the host could
not read is failed back by `stateui_fail_taken_act_calls` from the receipt
(acts.md).

## Jobs are asked for

`stateui_run_jobs` runs whatever a suspended handler has waiting, on the
caller's thread, and is where a handler comes back to life after an `await`. It
is a call into the library, never a callback out of it: a resume arrives on a
pool thread, and entering a runtime from a thread it has never seen can
deadlock the UI thread when a debugger is attached (concurrency.md).
`stateui_wait_work` parks a thread the host created - one its runtime has always
known - until work lands; it is a doorbell, not a worker, and nothing runs on
it.

## The cycle exports

`stateui_cycle_write` takes a batch of the host's writes (the state batch,
cycle.md), `stateui_cycle_run` runs one cycle and answers how many states have
lanes waiting with `0x4000_0000` set where an engine has more to do - so one
call answers both "is there anything to write onto a control" and "keep the
clock running" - and `stateui_cycle_read` reads out what moved, or one state
whole. `stateui_cycle_awake` lets a still page cost no frames at all.

## Diagnostics exports

`stateui_renders` and `stateui_alive` read the tally, `stateui_cycle_trace` the
last cycle as a line, `stateui_inspecting`, `stateui_inspect_applied`,
`stateui_inspect_scene` and `stateui_inspect_log` feed and read the inspector
(diagnostics.md). `stateui_platform` answers which platform and architecture the
Swift side was compiled for, a smoke test that the right library loaded.

## Before the first render

`stateui_connect_scene` hands over a platform window and what the platform kept
for its scene, before the render that fills it. `stateui_set_environment` pushes
one standard provider's values, once for every domain before the first render
and again whenever a platform event moves one, which rebuilds exactly the views
that read that provider. `stateui_persistent_keys` and `stateui_set_persistent`
are the two halves of hydrating kept state, both before the first render
(state.md).
