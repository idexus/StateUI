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
  slot           which layout's program this is - one number while the layout stands
  revision       which build of the layout made it - another at every build
  layOut         the host says the room it laid the layout out in
  place          where the layout puts each child at parameters the host names, set out from where it names
  answered       the same where the parameters stand, for a host that has no sample of them
  axes           the marks along each axis by which the host keeps where a motion set out
  frontItemUnit  the host asks how far the front view goes for a unit of an axis
  measuredBy     the host says how a child is measured, and again that one may measure otherwise
  measure        the layout's own size in a width offered; none where it takes its room
```

`HostPatch.layout` carries it: `.replace(program)` where the layout was
built again, `.clear` where the element runs none any more, nil for no
change - and none, in a complete message. The differ keeps the slot and the
revision it told (`RenderedNode.layout`) and compares them alone: a closure
is never compared.

A program is one build's. Its closures hold the run that build made - its
items, its arithmetic, its views' bodies - so the handlers, the entry on
the cycle and the program an element holds always come of the same build,
and the slot numbers each (`LayoutProgramSlot.program`). A view built again
alone, in the holder its layout keeps it in, is no build of the layout: the
program stands, and reads that view's body anew
([bodies](../views/motion-layout.md#bodies)).

The slot is the layout's own object (`LayoutProgramSlot`), kept in its
state, so it stands while the layout does: it holds the room the host said
last, what measures its views, and the stamp a new room moves. A new build
makes a new program over the same slot, so a room the host said once stays
said.

The trap is a state for the room or for the places. Either would cross
twice - out as lanes and back as a report - and a report of a room is a
write a render could read; the program hands both over typed, and neither
is anybody's state.

## What runs it again

The arithmetic runs where the host asks it, and writes nothing. What the
cycle does is say when to ask: the layout declares an entry beside its
program, which follows the slot - whose stamp a room the host said moves,
and a measure said again to a layout that measured - the parameters'
state, and every state and journey named in `following(_:)`. A journey
followed makes the layout a consumer of its channel while it stands
([a channel's life](journeys.md#a-channels-life)), so the arithmetic reads
the frame's sample of it. A run of the entry tells a named target
([a target named](../views/motion-layout.md#a-target-named)) and names the
slot in the cycle's answer (`HostCycle.stirred`); it never answers
`.again`.

```text
  the host says a room        slot's stamp moves, a turn is asked for
  the cycle                   the entry runs: the slot stirred
  the host, after the cycle   asks the program of each stirred slot, presents what moved
  a frame of the parameters   no cycle: the host asks at the sample its channel walked
```

A layout built again is a program in the patch, and its new entry runs in
the same cycle, so the places and the children they are for leave one
cycle together: a host never holds the places of one build beside the
children of another.

The trap is a state the arithmetic's run keeps - where it last stood,
where its motion set out, the last change. Asked from outside the cycle,
each write of one is a foreign write, which wakes the layout again at one
time for ever; and asked on the cycle instead, a frame of the parameters'
way is a cycle of the core, its places one frame behind the sample the
host shows. So the run keeps none: what lasts between two askings is the
host's ([asked in the host's frame](../host/layout.md#asked-in-the-hosts-frame)).

## The answer

The layout says where each child goes; bringing the child there is the
host's. So the program answers no finished picture: a `HostLayoutAnswer`
names, child by child in the children's order, what the host needs to make
one.

```text
  key     the layout's own number for the child's item - the same while the item stands
  target  where the layout puts the child at the parameters asked
  body    the body the child says itself; none said: its layout's bodies decide, on the host
```

The key is what lets a host know a child across two builds: a view
leaving is a key gone, one joining a key never answered, a new order the
same keys at other places. Measuring what a build moved, by those keys, is
the host's; so is where the hand holds a child, and the speed it lets it
go at.

The trap is answering where a child is drawn. The core would then own a
second geometry - a solver beside the host's own layout motion - stepped on
its cycle, a cycle a frame for as long as one child moved. The answer is
where the child goes and why; where it is on the way is worked out once, by
the host layer.

## The places at any parameters

`HostLayoutProgram.place` answers where the layout puts every view at the
parameters the caller names: the layout's numbers in its axes' order, where
its motion set out, and a room. It asks the arithmetic - through the
keyframes where an axis has them - and writes nothing: no state of the
layout moves and no cycle is asked. A host asks it in its own frame, at the
samples its channel walked that frame, so a frame of the parameters' way
needs no turn of the core.

`answered` is the same asked where the parameters stand, the motion
setting out there, in the room the host said last
(`Run.placed(at:from:in:)` under both): what a host reads before the
parameters have a channel, and what a program placing by no numbers
answers at all.

Where the motion set out is the host's to keep. The program says by what:
each axis that has segments is a `HostLayoutAxis` - its place among the
parameters' numbers, where its segments begin, and its turn where it comes
round - and `passed(from:to:)` says the last mark a motion passed going
from one place to another, either way.

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
  the host says again  what was measured is forgotten; a layout that measured is asked again after the next cycle
```

A working-out is the arithmetic asked its places once (`place`,
`answered`) - in a room of nothing too, where it answers no place: a
layout as tall as its views stands in a room of no height while they
measure nought, and what it measured then must not outlive that asking.
What was measured lives for one, keyed by the view's place and the whole
room offered, both sides. The host says its measure again when
the tree changed what a view measures - other children, a property of a
child that sizes it, a size moved on a frame - and only a layout whose
arithmetic measured a view moves its stamp for it: one that reads no size
stands as it stood, however its views change.

A layout asked before the host has its children measures its views as
nought; the patch lands, the host says its measure, and after the next
cycle it asks the layout again by the sizes that stand - the same turn a
room said for the first time takes.

The layout's own size (`measure`) is the same arithmetic of the same
views: the host asks it while it measures the layout, at the parameters as
they stand, and what the views answered is remembered until the next
working-out or the host's next word.

The trap is a view whose size changes with nothing the tree changed - a
picture that arrives. The toolkit measures it again by itself and tells no
one, so the layout places it by its new size at its next working-out, not
before.
