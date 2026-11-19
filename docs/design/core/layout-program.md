# A layout's program

A layout that places its children by arithmetic - a motion layout - hands
the host a program: the typed way the room reaches the arithmetic and the
children's places reach the host. No state carries either. This note says
what the program is and what works it out again; what the arithmetic does
is [the motion layout's own note](../views/motion-layout.md), and what a
host does with the answer [the host layer's](../host/layout.md#a-layout-program).

## The program

The layout's contract declares the program as a member,
`MotionLayoutContract.layout` ([a program](contracts.md#a-program)), and a
`MotionLayout` writes its definition onto its element
(`LayoutProgramDefinition`). The differ takes the `HostLayoutProgram` out of
it, which crosses in the patch as it is, in one process, with nothing
serialized:

```text
  slot        which layout's program this is - one number while the layout stands
  revision    which description of the layout made it - another at every build
  layOut      the host says the room it laid the layout out in
  placed      the host reads where each child stands, in the children's order
  measuredBy  the host says how a child is measured, and again that one may measure otherwise
  measure     the layout's own size in a width offered; none where it takes its room
```

`HostPatch.layout` carries it: `.replace(program)` where the description
made another, `.clear` where the element runs none any more, nil for no
change - and none, in a complete message. The differ keeps the slot and the
revision it told (`RenderedNode.layout`) and compares them alone: a closure
is never compared, and a program built again with the same revision is not
told twice.

The slot is the layout's own object (`LayoutProgramSlot`), kept in its
state, so it stands while the layout does: it holds the room the host said
last, where the run last put every child, what measures its views, and the
stamp a new room moves.
A new description makes a new program over the same slot, so a room the
host said once stays said and a hand holding the run is not let go.

The trap is a state for the room or for the places. Either would cross
twice - out as lanes and back as a report - and a report of a room is a
write a render could read; the program hands both over typed, and neither
is anybody's state.

## What runs it again

The arithmetic runs on the cycle, in the board's own order, by the entry
the layout declares beside its program: it follows the slot - whose stamp
a room the host said moves, and a measure said again to a layout that
measured - the parameters and where they are shown, the hand, and every
state and journey named in `following(_:)`. A journey followed makes the
layout a consumer of its channel while it stands
([a channel's life](journeys.md#a-channels-life)), so the arithmetic reads
the frame's sample of it. Each run writes where the
children stand onto the slot and names the slot in the cycle's answer
(`HostCycle.stirred`), which is all the host needs to read `placed` again.
A layout whose views are still on their way answers `.again`, so the
frames go on as for any engine.

```text
  the host says a room        slot's stamp moves, a turn is asked for
  the cycle                   the entry runs: places onto the slot, the slot stirred
  the host, after the cycle   reads `placed` of each stirred slot, presents what moved
```

The places and the children they are for leave one cycle together - the
patch and the slots it stirred - so a host never holds the places of one
description beside the children of another.

The trap is working the arithmetic out when the host asks rather than on
the cycle. A run writes states of its own - where the hand holds it, where
its motion set out - and on the cycle a write of its own wakes it no second
time; worked out from outside, each of those writes is a foreign one, and
the layout would run itself again at one time for ever.

## Measuring the views

The arithmetic is handed its views as handles (`LayoutSubviews`): each
names its item and measures through the slot's `LayoutMeasuring`, which
asks the host's measure (`HostChildMeasure`) by the view's place among the
items - a width and a height offered, a size and a first baseline
answered. The host says its measure once the layout stands on it
(`measuredBy`); before that, and where no toolkit stands behind the views,
a view measures nought.

```text
  one working-out      a view and a room are asked of the host once; asked again, answered from memory
  the next             nothing measured is kept: every view is asked anew
  the host says again  what was measured is forgotten; a layout that measured is worked out in the next cycle
```

What was measured lives for one working-out, keyed by the view's place and
the whole room offered, both sides. The host says its measure again when
the tree changed what a view measures - other children, a property of a
child that sizes it, a size moved on a frame - and only a layout whose
arithmetic measured a view moves its stamp for it: one that reads no size
stands as it stood, however its views change.

The first working-out of a layout runs before the host has its children,
so its views measure nought; the patch lands, the host says its measure,
and the next cycle works the layout out by the sizes that stand - the same
turn a room said for the first time takes.

The layout's own size (`measure`) is the same arithmetic of the same
views: the host asks it while it measures the layout, at the parameters as
they stand, and what the views answered is remembered until the next
working-out or the host's next word.

The trap is a view whose size changes with nothing the tree changed - a
picture that arrives. The toolkit measures it again by itself and tells no
one, so the layout places it by its new size at its next working-out, not
before.
