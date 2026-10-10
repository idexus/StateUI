# Diagnostics

Three instruments tell what the core is doing without changing it: the tally
of renders and live elements, the inspector's record of each render, and the
complaints the library says where it could not do what it was asked as
written. `debugInfo()`, which explains a single build in the author's names,
is in invalidation.md.

## The tally

```text
  renders    how many renders this process made
  empty      how many carried no patch - a write that changed no property
  refused    how many writes asked for nothing, because no live element read
             the state (invalidation.md)
  alive      how many rendered elements are alive now
  runs       how many runs are under way or wait their turn now (runs.md)
```

`empty` is how a write that should have asked for nothing is found; `refused`
is the other half, what counting live readers spared beside what got through.
`alive` is counted in as each rendered element is made and out as it goes, so a
page that was left and still stands in memory shows as a number that does not
come back down. It tells a leaked page from memory the allocator has not handed
back yet, which a process's resident size cannot. `runs` is the same count
for work: a run that its element's leaving does not end - a loop that never
looks at its cancellation - holds the number up after the page is gone. A host reads the tally
through `HostBoundary.tally` - a Swift runtime writes it with its own totals
under `STATEUI_TALLY=1` (host/patches.md): this side has no environment to
read.

## The inspector

While an inspector records, the renderer opens a pass around every render and
the differ writes an entry for every composed view it reaches:

```text
  pass    road (walk, build, complete), causes in the author's names,
          microseconds describing, and the host's half: applying, per scene
          too, and the controls walked, made and kept
  entry   built  - with the reason it could not be carried
          carried - whole: not built, not compared, not sent
          walked  - only as the path to a view below it that was built
          each with its inclusive and its own time
```

Nothing runs while nobody looks: every hook in the differ is one read of
`recording`, false until an inspector opens, so an application that never opens
one pays a branch per composed view. A host that wants every pass as text
(`STATEUI_INSPECT=1`) asks for the log once, and recording then stays on.

The inspector is not its own subject. It is a tree like any other, built again
whenever a pass lands, so its own views are muted - their time is kept apart and
they write no entries - and a pass caused by nothing but its own state, or one
that built nothing but its own views, is not kept, whichever road it took.
Otherwise every pass would record the inspector drawing the pass before it,
and after a failed apply a complete render the inspector kept would ask it to
draw again, for good.

A pass keeps at most `most` entries, and the record keeps the last `kept`
passes; the host's report is matched to its pass by generation.

## Complaints

`complain` says, once, what the library could not do as written - a value held
to what it can be, a write it refused or dropped, a mistake it can only see
the sign of (a repeated identity, a write built on a value gone, a kept key no
list names) - and the caller carries on with what it did instead. The
complaint itself refuses nothing, and nothing depends on one being read. It
exists because the alternative is silence - a value quietly held to what it
can be, and an author left wondering why the constant they wrote does nothing.

Each message is said once per process, because a place that complains is often
a modifier, and a modifier runs on every render: an author who wrote 1.4 where
a fraction belongs would otherwise be told so as fast as the interface is
described. It goes to standard output, outside the lock: a terminal on macOS,
the console on iOS, a shell on Windows and Linux, logcat on Android, whose
host routes the process's output there. An application that wants them
elsewhere - its own log, a crash reporter - routes them (`Complaints.route`),
and each comes to it on the thread that complained, outside every handler's
run: a route posting what it heard to a state is not refused with a run that a
refusal complained of. Every one said is kept in order (`Said`), and an open
inspector is told of each and lists them. What was said is held to a thousand
different things, so complaints naming ever new values cannot grow without
end: past it, that is said once, and nothing after it. So a complaint is a
development aid and may never be the only thing between an application and
working.
