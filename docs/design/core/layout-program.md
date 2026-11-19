# A layout's program

A layout that places its children by arithmetic - a motion layout - hands
the host a program: the typed way the room reaches the arithmetic and the
children's places reach the host. No state carries either. This note says
what the program is and what works it out again; what the arithmetic does
is [the motion layout's own note](../views/motion-layout.md), and what a
host does with the answer [the host layer's](../host/layout.md#a-layout-program).

## The program

A `HostLayoutProgram` crosses in the patch as it is, in one process, with
nothing serialized:

```text
  slot       which layout's program this is - one number while the layout stands
  revision   which description of the layout made it - another at every build
  layOut     the host says the room it laid the layout out in
  placed     the host reads where each child stands, in the children's order
```

`HostPatch.layout` carries it: `.replace(program)` where the description
made another, `.clear` where the element runs none any more, nil for no
change - and none, in a complete message. The differ keeps the slot and the
revision it told (`RenderedNode.layout`) and compares them alone: a closure
is never compared, and a program built again with the same revision is not
told twice.

The slot is the layout's own object (`LayoutProgramSlot`), kept in its
state, so it stands while the layout does: it holds the room the host said
last, where the run last put every child, and the stamp a new room moves.
A new description makes a new program over the same slot, so a room the
host said once stays said and a hand holding the run is not let go.

The trap is a state for the room or for the places. Either would cross
twice - out as lanes and back as a report - and a report of a room is a
write a render could read; the program hands both over typed, and neither
is anybody's state.

## What runs it again

The arithmetic runs on the cycle, in the board's own order, by the entry
the layout declares beside its program: it follows the slot - whose stamp
a room the host said moves - the parameters and where they are shown, the
hand, and every state named in `following(_:)`. Each run writes where the
children stand onto the slot and names the slot in the cycle's answer
(`HostCycle.stirred`), which is all the host needs to read `placed` again.
A layout whose views are still on their way answers `.again`, so the
frames go on as for any engine.

```text
  the host says a room        slot's stamp moves, a turn is asked for
  the cycle                   the entry runs: places onto the slot, the slot stirred
  the host, after the cycle   reads `placed` of each stirred slot, presents what moved
```

The trap is working the arithmetic out when the host asks rather than on
the cycle. A run writes states of its own - where the hand holds it, where
its motion set out - and on the cycle a write of its own wakes it no second
time; worked out from outside, each of those writes is a foreign one, and
the layout would run itself again at one time for ever.
