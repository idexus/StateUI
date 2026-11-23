# Changelog

What each release changes for an application and for a host, newest first. A breaking change says how to move
over. StateUI is before 1.0: a release may break what the one before it promised, and says so here.

## 0.9.0 - 2026-11-19

### Breaking changes

- **A state's value is where it is going; where the host shows it is its journey's sample.** `$x.journey` is a
  handle: it holds no value and reading it starts nothing. `Journey.value`, `Journey.velocity` and
  `Journey.destination` are gone, and every setter with them. The destination is the state itself, and where the
  value stands is `journey.sample` - a `JourneySample` with its `value`, the `destination` the host is taking it to,
  its `velocity` and the frame's `time`, all of one frame - nil where nothing shows the state. A body that reads the
  sample is rebuilt on every frame the value moves; an engine following the journey reads it with no build:

  ```swift
  // before
  Text("\(Int($fade.journey.value * 100))%")

  // now
  Text($caption)
      .engine(following: $fade.journey) { _ in
          guard let sample = $fade.journey.sample else { return }
          caption = "\(Int(sample.value * 100))%"
      }
  ```

  `journey.snap(to:)` puts a value there at once and `journey.stop()` halts it where it stands, as before;
  `journey.reach(_:)` answers nil where nothing shows the state.
- **A movement answers a `MotionRun`, which ends one way.** `Arrival` and `arrived() -> Bool` are gone.
  `journey.move(to:)` answers a `MotionRun`, and `try await run.result()` a `MotionResult`: `.reached(.animated)`,
  `.reached(.immediate(reason))` - already there, motion off, the user asking for less motion - `.superseded` by a
  newer destination, a snap or the user's hand, `.stopped`, `.detached` as the last control showing the state went,
  or `.notStarted(reason)` where no movement was made: the state shown nowhere (`.noReceiver` - the value is written
  all the same), a destination its validator refused, a conversion with no way back. `run.outcome` reads the same
  without waiting. `try await $x.journey.move(to: 1).arrived()` becomes `.result()`; code that tested the `Bool`
  compares with `.reached(.animated)` or switches over the result.
- **A state's motion is the state's, whichever control shows it.** A write that names no motion animates under the
  state's own - `@State(motion:)`, changed later with `try $x.journey.setMotion(_:)` - else the application's, else
  the library's standard one. The `.motion(_:)` of a control showing the state no longer decides it: two controls
  showing one state travel alike whichever was built first. An element's `.motion(_:)` animates its own described
  properties as before. `journey.motion = ...` becomes `try journey.setMotion(...)`, and `journey.motion` is
  optional: nil for a state an engine animates.
- **A conversion works out a destination from destinations.** `$x.convert { ... }` and
  `.multi($a, $b).convert { ... }` give the result's destination from their sources' destinations and nothing else;
  a control showing the result animates it under the result's own motion - `motion:` on `convert`, the state's
  default where none is given - and never under a source's. `Journey.convert` and `Binding.multi` over journeys are
  gone: what must follow a value frame by frame as it moves is an engine following the journeys and writing a state,
  as above. The way back runs when the result itself is written - by the user through a control, or by the program -
  and never on a frame of the result's animation, so a rounded result no longer rounds its source while it travels.
  A conversion with no `back:` is read-only: a write to it is refused and said, and `move(to:)` answers
  `.notStarted(.readOnlyDerived)`. A program's write to a result is one the conversion gives back unchanged, or it is
  refused. A conversion's closures read only the states they are handed and write none.
- **A reading samples a journey.** `.samples($fade, into: $shown, cadence)` becomes
  `.samples($fade.journey, into: $shown, cadence)`. It is taken on the display's frames, so its pace is counted in
  the time the host animates by, and the last sample of a movement always arrives.
- **An engine that animates a state is registered for it.** A state declared `@State(animatedBy: .engine)` is
  animated by `.engine(animating: $x) { cycle, motion in ... }`: `motion.value`, `motion.destination` and
  `motion.velocity` are where it stands, `motion.update(value:velocity:)` shows a frame and `motion.finish()` lands it
  and ends the movements waiting on it. An engine that wrote `journey.value` and `journey.velocity` under
  `.engine(tracking:)` moves there. One state has one animator; `move(to:_:)` with a motion of its own is refused on
  such a state as `.notStarted(.incompatibleAnimator)`, and `move(to:)` hands the destination to the engine.
  `.engine(following:)` and `.engine(tracking:)` take journeys beside states: a state wakes the engine as it is
  written, a journey on every frame its sample moves.
- **A spring's numbers are held alike wherever one runs.** A motion's and a layout body's spring take the same
  floors - a response to the millisecond and at least 1, a damping of at least 0.05 - so a layout body's damping
  below 0.05 is 0.05, as a motion's always was.
- **A motion layout's views are bodies it names.** `LayoutDynamics` and `.dynamics(_:)` are gone:
  `.dynamics(.spring(response:damping:))` is `.layoutBodies(.onChange(response:damping:))`, and
  `.dynamics(.none)` is `.layoutBodies(.none)`. `LayoutBody` has three values - `.none`, the view at its place at
  once; `.onChange(response:damping:)`, a spring answering a change of the layout, which every view is unless said;
  and `.followsLayout(response:damping:)`, which lags behind a moving place too - and a view's own
  `.layoutBody(_:)` wins over its
  layout's: a view saying `.followsLayout` in a layout of `.none` now moves, where it stood still before.
- **A motion layout's parameters travel under their state's motion.** `.parameterMotion(_:)` is gone: say the
  motion where the parameters are declared, `@State(motion: .spring(response: .milliseconds(240))) private
  var turn = 0.0`, and change it later with `try $turn.journey.setMotion(_:)`. A hand let go short of a rest comes
  onto it under the same motion.
- **What the hand moves is one declaration, `.interaction(_:)`.** A motion layout's `.axis(_:input:range:keyframes:
  snaps:periodic:)` no longer says the hand: an `Interaction` names the state and the input - for parameters of
  several axes, the axis too (`.value($orbit, axis: \.turn, input: ...)`) - and says the
  rest - `.interaction(.value($turn, input: .translation(.horizontal, unit: .frontItem))
  .reversed(true).range(0...6).snaps(.every(1)))`. Several axes moved at once are `Interaction.simultaneous([...])`;
  an interaction said again takes the other's place, and two values moving one axis are refused together.
  `LayoutInput` is `InteractionInput`: `.scroll(way)` is `.translation(way, unit: .frontItem)`, `lengthPerUnit: n`
  is `unit: .points(n)`, `.pages(way)` is `.swipe(way, unit: .containerLength)`; magnification and rotation keep
  their names. A unit is a point unless said - say `.frontItem` where the hand should carry the view in front.
- **A value grows as the hand moves right or down.** It grew as the hand moved left or up. A row of cards whose
  growing number moves them left says `.reversed(true)`; every `.scroll`, `.swipe` and `.pages` moved over says it.
- **A throw is the interaction's release.** `.throwMotion(_:)` is `.release(.projected(_:))` on the interaction -
  on several at once, every one of them - and on a `GalleryView`, `.release(_:)`. Unless said a value is thrown on
  as a glide of 800 ms at the longest, where a layout threw by 400 ms of `cubicOut`: say
  `.release(.projected(.eased(.milliseconds(400), curve: .cubicOut)))` to keep the throw it had.
- **An axis maps, and names its segments.** `.axis(_:range:keyframes:segments:periodic:)` - `.axis(range:...)`
  for parameters that are one number - says where the
  arithmetic is asked and where a segment begins, for the hand and the program alike. A layout whose arithmetic
  takes where the motion set out says `segments:` where it said `snaps:`; keyframes no longer take the hand's
  snaps in - name them among the keyframes where the layout should rest on the arithmetic's own answer. The
  mapping's range and the hand's are two: the hand's is the interaction's `.range(_:)`.
- **A swipe given no snaps moves nothing,** and says so, where it swiped from end to end of its range.
- **A value the hand holds stands under the hand.** While a hand moves a motion layout's parameters, their state's
  channel shows them where the hand has them: `$turn.journey.sample` answers that place, bound for the snap the
  state itself names, and every control wearing the same state follows the hand, where it stood on the snap last
  passed. A value with no snaps is going where the hand holds it, written as the hand moves - it was written only
  once it rested. Of two snaps as near, a value let go takes the one the hand was going toward.
- **A write of the program takes a value from the hand.** Written while a hand held it, a value went where the
  program sent it until the hand's next move took it back. The write ends the hand's gesture now: the value
  travels where the program sent it from under the hand. Say `.programWrites(.deferLatest)` on the interaction for
  a hand that keeps the value until it lets go.
- **What the hand moves is every view's `interaction` program.** `ViewContract.interaction` takes the place of a
  motion layout's `translationOrientation`, `pans`, `magnifies`, `rotates`, `translationUpdated`, `wheelStepped`
  and `pinchRotationUpdated`: the hand's hold, its move and its release are the host layer's
  (`InteractionSessions`), on the state's own channel, and the core hears their reports. A host goes on handing
  what its toolkit tells to `MountedElement.hear` and reading `hearing` and `handWay`; the host layer registers
  the program for every element (`everyElementRuns`), and a realization records `ViewContract.interaction` only
  where its toolkit tells less of the hand. `HostPatch.interaction` carries the program, and a layout program
  answers `frontItemUnit`.
- **`panX(_:)` and `panY(_:)` are an interaction.** `.panX($x)` is `.interaction(.value($x, input:
  .translation(.horizontal)).release(.stay))`, and down alike with `.vertical`; both on one view are
  `Interaction.simultaneous([...])`. The state is carried as a journey now, so a write of the program travels on
  the same value. `ViewContract.panXChannel` and `panYChannel` are gone, with `HostRuntime.takeGestureValue`.
- **Reading a frame changes no motion.** A layout whose frame, or a frame under it, was read stood every child at
  its place at once, and a stated size in it changed with no travel. A reader changes nothing now: children travel
  under their layout's `.motion(_:)` and a size under its view's, read or not. A size or a place worked out from a
  measurement says `.motion(.none)` itself - on the view for its size, on the layout for where it puts its
  children. A host built on `StateUIHost` no longer sets `TravelingPlaces.framesRead`.
- **A frame is read where the layout puts the view.** `.onFrameChanged` and `.frame(into:)` report the layout's
  rectangle: a view traveling to a new place reports where it is going, once, where it reported every step of the
  way. The steps are the presentation's (`stage: .presentation`, below). In the contracts
  `VisualElementContract.frame` is `layoutFrame` and `ViewContract.frameChanged` is `layoutFrameChanged`.
- **A hand's speed is no longer written into a journey.** `$x.journey.velocity = update.velocity.x` is gone with the
  setter. A throw is a movement of its own: a cubic-out journey sets out three times as fast as it averages, so one
  to `update.total.x + update.velocity.x * seconds / 3` over `seconds` goes on at the hand's speed and slows to rest.
- **A placement is no value a state carries.** `Placement.carried`, `Placement.init(carried:)` and
  `Placement.lanes` are gone, and `Placement` is no `LaneValue`: a motion layout hands the host its views' places
  typed, so nothing reads a placement as twelve numbers any more. A `Placement` is what `placements:` answers, as
  before.
- **A motion layout's arithmetic is handed a context.** `placements:` takes a `LayoutContext` in place of the room's
  `Rect`: the room is `context.bounds`, and `context.subviews` are the views, which the arithmetic may measure.

  ```swift
  // before
  } placements: { room, turn in
      names.indices.map { Placement(Rect(Double($0) * 80 - turn, 0, 72, room.height)) }
  }

  // now
  } placements: { context, turn in
      names.indices.map {
          Placement(Rect(x: Double($0) * 80 - turn, y: 0, width: 72, height: context.bounds.height))
      }
  }
  ```
- **For a host: a report says who wrote, and a movement's end says how.** `HostBoundary.report(_:through:origin:)`
  and `report(_:updating:through:at:origin:)` take a `WriteOrigin` - `.user` for a control the user moved,
  `.animation` for a frame, `.measurement` for a size read, `.program` for a halt the application asked for - and
  the frame's time; `complete(_:as:)` takes a `HostMotionOutcome` in place of a `Bool`, and the movements an engine
  ended come in `HostCycle.finished`. A state followed by an engine or a reading with no property showing it reaches
  the host in `HostPatch.followed`. The host layer does all of it; a host built on `StateUIHost` changes nothing.
- **For a host: a layout says its room.** `TravelingPlaces.begin(width:)` is `begin(width:height:)`: a view
  entering or leaving wholly out of its room is moved out of sight: past its layout's room where that clips its
  content, else past the nearest scroller or page above, read off the frames the host reports.
- **For a host: a layout says how a child comes.** `LayoutMotion.place` and `TravelingPlaces.place` take `enter:`
  in place of `fadeIn:`, handed a `LayoutEntry` - `.joining(under:)` a layout already standing, under the law its
  children animate by, or `.appearing` with its layout - for every child given its first place;
  `Arrangement.fades` is `joins`. `MountedElement.fadesIn(presentsOpacity:)` and `fadeIn(_:under:)` are
  `entersMoving(presentsOpacity:)` and `enter(_:as:)`, which decides the entry: by the view's transition, else the
  fade. A host built on `StateUIHost` hands the entry on as it handed the law.
- **For a host: a view may be kept as it leaves.** `NativeElement` gains `keepsExits` - whether the view keeps a
  child that left, drawn where it stood and out of its layout; a view keeps none unless it says so.
  `MountedElement.presentedChildren` is what stands in the native view, the active and the kept, beside
  `arrangedChildren`, the active alone: a host takes a kept view out as it arranges its holder again, which the
  tree asks as the exit ends. The
  tree keeps a dropped child that declares an exit, within a window's budget (`MountedTree.exits`, a `KeptExits`),
  and `PresentationOperation.Result` gains `.limited` and `.detached`. `MountedTree.removeMotions` and `unmounted`
  are gone.
- **For a host: an element leaves in two steps.** `NativeElement.leave()` is `deactivate()`: the element stops
  being the application's, and everything its native half attached outside the tree lets go. A mounted element has
  a `lifecycle` - `.active`, `.exiting`, `.released` - with `deactivate()` and `release()` between them, each said
  again doing nothing, and `leave()` both at once. What an element answers by itself is guarded by it in the host
  layer: a toolkit's callback already on its way as its view left hears no input, tells no handler, writes no
  state, opens no link and moves no focus. `MountedElement.isLeaving`, a view fading out as it is hidden, is
  `isFadingOut`. A host built on `StateUIHost` renames the one method.
- **For a host: a motion layout runs a layout program.** Its room and its views' places cross typed in
  `HostPatch.layout` (`HostLayoutProgram`), and `HostCycle.stirred` names the layouts to ask again; the host layer
  says the room, asks the places and tells the program how a view is measured. A host's `NativeElement` answers
  `measured(width:height:)` - its view's own size and first baseline in a room offered - and its ZStack hands
  `ZStackArithmetic.size(of:padding:width:motionLayout:program:)` the element's `programSize`. `LayoutSize` is
  declared in `StateUI`: a source naming it imports `StateUI` beside `StateUIHost`. The program answers where the
  layout puts each child at the parameters the host names (`place`, a `HostLayoutAnswer`: a view's key, target and
  body) and writes nothing, so the host layer asks it in its own frame, at the sample its channel walked: a frame
  of the parameters' way costs no cycle of the core, and the views stand where that frame's sample puts them. The
  host layer keeps where a motion set out, by the marks the program's axes name (`HostLayoutAxis`), measures what
  a layout built again moved, keeps each child's way and steps it on the display's frames, and tells the layout
  once it rests (`MotionLayoutContract.settled`). A host built on `StateUIHost` changes nothing for it.
- **A platform's own icon as a picture is `.platform(_:)`.** `ImageSource.icon(_:)` is `ImageSource.platform(_:)`,
  so a button's icon no longer says the word twice: `.icon(.icon(.share))` is `.icon(.platform(.share))`, and
  `Image(.icon(.star))` is `Image(.platform(.star))`.
- **A grid's run of rows or columns is made by its factories alone.** `GridTracks(_:count:)` is gone:
  `GridTracks(.fixed(90), count: 3)` is `.fixed(90, count: 3)`, as `.automatic(count:)`, `.fill(count:)` and
  `.proportional(_:count:)` say the others.
- **A rectangle and a point are written with their labels.** `Rect(_:_:_:_:)` and `Point(_:_:)` are gone:
  `Rect(0, 0, 120, 40)` is `Rect(x: 0, y: 0, width: 120, height: 40)` and `Point(20, 0)` is `Point(x: 20, y: 0)`,
  the one spelling each has.
- **A view the hand takes by itself says so itself.** `MotionLayout.itemDrag(begins:)` and `ItemDragStart` are gone:
  the view says `.interaction(.drag(_:begins:))`. `.itemDrag(begins: .longPress)` is
  `.interaction(.drag(.both, begins: .longPress))` on each view, and `.itemDrag(begins: .perpendicular)` on a
  layout that scrolls sideways is `.interaction(.drag(.vertical, begins: .directional))`; `.onItemDragged` and
  `.onItemDismissed` are told as before. Said inside the view's own body, the drag leaves the layout building no
  view again as its order changes.
- **A view says its own dismissal.** `MotionLayout.onItemDismissed(directions:threshold:_:)` is
  `.onItemDismissed(_:)`, with its `policy:` and `gate:` forms: which throw dismisses a view is the view's to say -
  `.interaction(.drag(.vertical, begins: .directional).dismissal(directions: .up, threshold: 120))` in its own body.
  A view whose item no handler removes now comes back to its place, once every handler has ended.
- **A press held is a long press.** `.onHeld(minimum:_:)` is `.onLongPressed(minimum:_:)`, with its `policy:` and
  `gate:` forms; a button's menu a held press opens is `.menu(.longPress)` (`ButtonMenuKind.held` is gone). An
  extension reads `ViewContract.longPressed` and `ViewContract.longPressDuration` for `held` and `holdDuration`,
  and a test sends `UserAct.longPress`. "Hold" names only the hand's hold on a value or a view it moves.

### New

- **A view the hand has taken taps nothing as it is let go.** A drag of the view's own - `.interaction(.drag(_:begins:))`
  - takes the press it began from, as a pan does: a view lifted by a long press and put down where it stood is no
  longer tapped open by its release, whatever its platform tells.

- **Two views of one transition id are one to the eye.** `.transition(id:)` shares a view's presentation on its
  page: as a view of that id leaves and one of the same id comes elsewhere on the page in the same change - in
  another holder, or another kind of view in its place - the one coming takes over from the one leaving where it
  was drawn, how fast it was moving and its corner, and grows onto its own place under its own `.motion(_:)`;
  going back during the movement turns it from where it has got to, as fast as it was going. The two stay two
  views, of any kinds: what is shared is where each is drawn, its size and its corner. `.transition(id:scope:)`
  narrows where the views meet to those naming the same scope, so a component's title written once meets only
  the title of the same card. A transition id is what a view is drawn as, not who it is: `.id(_:)` and a
  `ForEach`'s items share nothing, and among the same siblings one `.id(_:)` on two views of one kind is one view
  continued. One change carries as many transition ids as it holds: a row of tiles laid out again as a grid
  sends each tile onto its own cell, with no `MotionLayout`. Where no single partner is found - none, two of one
  id, another window or page, a view coming with a `MotionLayout` laid out in a room of nothing, which places
  nothing - each goes by its own `.transition(_:)`; a transition id standing on more than one view of the page as
  the change runs - two leaving, two coming, or one staying beside them - is said once on the standard output,
  or where `Complaints.route` sends it; a view coming with the `MotionLayout` that places it - a card coming back
  from its detail into its deck - is one with its partner. A host compares no value: the core hands it numbers.
  On its way the entering view is drawn in front of what it passes over - every sibling in a stack, what stood
  before it in a layout that layers its children - until it lands. Where the layout that held the leaving view
  keeps a view that leaves - a stack, a grid, a ZStack - the two are drawn as one: the leaving one goes along
  onto where the entering one lands; they cross over near the smaller, a rounded corner - a rectangle's, a
  layout's rounded shape - going from the one's to the other's as drawn, whatever either is scaled to, and only
  the one in front, the larger, fades, so the two never let through what lies under them. What goes along is the
  view with the transition id, with what it holds: anything else that left with it - a caption under a picture -
  stands where it is drawn and fades out there, so a view meant to travel whole has the id itself.
- **For a host: a layout draws its children in one order.** `DrawingOrder.of(_:placedBy:inFront:)`, and
  `TravelingPlaces.drawingOrder(of:placedBy:)` over the children's mounts, replace
  `ZStackArithmetic.drawingOrder(of:placedBy:)`: a run's ranks, else the tree's order, and last a child a shared
  entry carries in front (`LayoutMotion.drawsInFront`). `NativeElement` gains `orderChildren()` - draw the
  children again in that order, at once, with nothing placed again. The order covers the views kept as they
  leave too: `TravelingPlaces.drawingOrder(of:kept:placedBy:)` takes every view a layout presents by its mount,
  in the order they stand (`MountedElement.presentedMounts(item:)`), and stands each kept one after the view it
  stood after (`DrawingOrder.of(presented:placedBy:inFront:)`) - one place on every host, where each drew it its
  own way before; a host's layout is told its kept views with their mounts. A driver's `drawingOrder(of:)` reads
  the views a layout presents, the kept ones among them.
- **For a host: a motion layout's first pass asks its program.** A host's motion layout view stands its children
  by `MountedElement.placementInRoom` in the room of the pass that lays it out - the run shown where it places
  every child the layout holds, else its program asked then - and takes that run without asking for another
  pass: each child's first place is its program's, never across the layout's room.

- **A change says how what it started ended.** `Aim.presentationChange { ... }`, on the aim of any view, runs
  the writes at once and answers a `PresentationChange`: `applied()` waits until the host took them, and
  `settled()` until every movement they started under the aimed view has ended - `.settled`,
  `.interrupted` with why (`.superseded` by a later write, `.stopped`, `.detached` as a view left,
  `.unsupported` for an exit not drawn where the view stood, `.limited` for one cut short), or
  `.notPresented` where nothing shows the view. It watches the properties the writes move under a view's own
  `.motion(_:)`, the places a layout carries its views to, the entry of a view the writes bring, the exit of
  one they drop, and the states the writes send somewhere that the view shows - a motion layout such a state
  runs, until it rests; a movement started later is no part of it, and it stops nothing. For a host: nothing to write - a render carries the
  change beside its patch (`HostRender.changes`) and the host layer answers it.

- **A view's aim says how it stands now.** `Aim.presentationSample()`, on the aim of any view, answers a
  `PresentationSample`: `layoutFrame`, where its layout puts it; `frame`, the rectangle around what is drawn of
  it; and `translation`, `scaleX`, `scaleY`, `rotation` and `opacity` as it is drawn at that moment -
  mid-movement, where the movement has got it to. One reading, following nothing; a view not yet laid out or no
  longer shown throws. For a host: `NativeElement.frameNumbers()` hands the numbers a frame report says, on
  demand, and the host layer answers the act (`ViewContract.presentationSample`).

- **A view says how it comes and goes.** `.transition(_:)`, on any view, names the effect the view comes from as
  the tree gains it and the one it goes to as the tree drops it: a `TransitionEffect` - `.opacity`,
  `.translation(x:y:)`, `.scale(_:)`, `.outside(_:)` out of sight, combined in the order written - in a
  `Transition`, `init(enter:exit:)` or
  `symmetric(_:)`. The view travels from the effect to how it stands, under its own `.motion(_:)`, else the
  application's, in place of the fade a view joining a standing layout otherwise comes with. It enters as it joins
  what already stands, and with `initialAppearance(true)` as it appears with its page too; given to a view already
  standing, a transition moves nothing. A view the tree drops is the application's no more at once - the views
  around it take its place - and is drawn until it has gone to its exit's effect, two seconds at most, where the
  host keeps a view as it leaves: on every host, in a stack, a grid and a ZStack. A view that comes back under the same `.id(_:)` - a name, a number, a UUID - or as the same item of a
  `ForEach` while it is still leaving goes on from how the leaving one is drawn, at its speed - another view,
  with its own state and handlers. A view holding a web view or a map goes at once on every host: its engine
  would run on for as long as it was drawn.

- **A gesture taken away ends once, as cancelled, the same on every platform.** A press, a pan, a pinch, a value
  under the hand and a view the hand carries each end as `.cancelled` when the platform takes the touch, a scroller
  around the view begins to scroll, or the view stops being a target - disabled, or drawn at no size: no tap, no
  swipe, no throw, no dismissal. It is told once, and nothing more of that touch is heard, though the view be a
  target again before the touch ends. A view's own `.press` effect lets go as the hand takes the layout it stands
  in. A view drawn at no size - its own scale or a holder's nought - is under no hand. In a test,
  `.cancelInteraction` takes a press away; every host's conformance driver takes one away by its toolkit's own
  cancel.

- **A view thrown away.** A drag's `.dismissal(directions:threshold:motion:)` lets the hand throw the view out of
  the room that holds it; `.onDismissed` hears a `Dismissal` - the way it went, the hand's speed - once it is out,
  on any view. A press catches a view on its way out, and a view nobody removes comes back.
- **A view answers the hand itself.** `.interaction(.press(values:_:))` draws a view by the `PresentationOffset`
  its effect answers for a `PressInput` while a press stands on it - moved, turned and scaled about its middle,
  only the `PresentationValues` it names. `.elasticPress()` is the press most views want: the view grown a
  little, pulled toward the finger and stretched the way it is pulled, on a spring of its own. A press is
  watched, never taken.
  `.interaction(.drag(_:begins:))` gives the view to the hand along its `DragAxes` - at once, after a long press,
  or by a first move its one axis leads (`DragStart`) - over what stands beside it, and back onto its place let
  go. Neither moves a state.
- **A layout measures its views.** Each of `context.subviews` answers how large its view is in a room offered:
  `view.sizeThatFits()` the size it takes by itself, `view.sizeThatFits(width: 200)` the size its words
  take wrapped to 200 points, as a `LayoutSize`; `firstBaseline(width:height:)` where its first line rests. A view is found by
  its place or by its item's identity (`context.subviews[id: item.id]`). A layout that measures is worked out again
  when a view of it is sized anew.
- **A motion layout says its own size.** `.measure { context, parameters in ... }` answers the layout's `LayoutSize`
  from the room offered (`context.proposal`) and its views; without it the layout takes the room it is given, as
  before. A row that becomes a column where the room runs out is one layout of the same views, each keeping its
  state and the keyboard.
- **Every layout's children can be bodies.** `.layoutBodies(_:)` on a `VStack`, an `HStack`, a `Grid` or a `ZStack`
  says how each child comes onto a new place - `.onChange(...)` on a spring when the tree changes the
  layout, `.followsLayout(...)` also when the place moves on a frame, `.none` at once - and
  `.layoutBody(_:)` says it for one child, which wins. A layout that says neither moves its children under its
  `.motion(_:)`, as before.
- **An interaction of its own.** `Interaction`, `InteractionInput`, `InteractionUnit` and `InteractionRelease`
  are values: nothing is recognized or timed until a view wearing one stands. A value given no `.range(_:)` has
  no end. `.release(.nearest(_:))` comes onto the nearest rest with no throw, and `.release(.stay)` leaves the
  value where the hand left it.
- **The hand moves a state on any view.** `.interaction(_:)` is every view's: a rectangle moved by
  `.translationX($offset)` and given `.interaction(.value($offset, input:
  .translation(.horizontal)).range(0...240).snaps([120]))` is dragged between three places with no handler and no
  view built, and a button writing `offset` sends it on the same value. A state nothing draws is carried for the
  hand alone. `.containerLength` is the view's own length; `.frontItem` is a motion layout's, and is refused
  elsewhere.
- **A write of the program under the hand.** `Interaction.programWrites(_:)` takes an
  `InteractionProgramWrites`: `.interrupt`, unless said, or `.deferLatest` - the state is going where the program
  sent it at once, the value stays under the hand, and let go it travels where the program sent it last. A write
  of another number of the same state leaves the hand its own either way.
- **Snaps with no range.** `.snaps(.every(1))` on a value given no range is every whole number, worked out and
  never listed, and a list stands as written; only `.endpoints` needs a range.
- **A view's two rectangles.** `.frame(into:stage:)` and `.onFrameChanged(in:stage:)` take a `GeometryStage`:
  `.layout`, unless said, is where the view's layout puts it, and `.presentation` the rectangle around what is
  drawn of it - every step of its way to a new place, and its own `.scale`, `.rotation` and move. One view feeds
  both into two states: `.frame(into: $placed).frame(into: $drawn, stage: .presentation)`.
- **A motion layout follows a journey.** `.following($tilt.journey)` runs the arithmetic on every frame the value
  moves, where it reads `$tilt.journey.sample`; `.following($tilt)` runs it at a write of where the state is going,
  as before.
- **A test winds its window's time by hand.** `TestWindow(clock:)` takes a `TestClock`: the page mounts moving no
  time, `element.send(_:)` does an act and waits for nothing, `window.flush()` runs the work that is ready at the
  present time, and `try await clock.advance(by:)` moves the time on a display frame at a time. A movement travels
  only as far as the test advances the clock, so a test stops half-way, reads, interrupts and goes on, with no
  waiting. `perform(_:)` in such a window fails and names `send(_:)`; an ordinary window works as before, and sends
  and flushes too.
- **A press in phases.** `UserAct` gains `.pressDown(at:)`, `.drag(to:)`, `.lift` and `.cancelInteraction`: a pan at
  the speed the clock gives its moves, its end or its being taken away, and - let go where it went down - a tap or a
  click.
- **What a view presents.** `element.presentation()` answers a `TestPresentation`: the view's opacity, translation,
  scale and rotation where a movement has got them to, whether it takes input and how assistive technology meets it.
  Its `id` may be kept and asked again with `window.presentation(_:)`, and `generation` tells one mounting of a view
  from the next.

### Fixed

- **Return takes the keyboard down on iOS and Android.** A field submitted by a return that says Done, Go or
  Search, or that says nothing of its own, gives up an on-screen keyboard, as `SubmitLabel` now says: on iOS no
  return did, and a page with no scroller left no way to close the keyboard. Next hands it on, as before; Send
  leaves it up for the next message. On Android a text field that names no return offers Done. On iOS a drag of
  a `ScrollView` or an `ItemsView` takes the keyboard down with the finger, the road out of a `TextEditor`.

- **A motion layout that leaves stands its views where its program put them.** As it faded out, or went along
  with a card opening into its detail, every view in it was drawn across the layout's whole room, the last one
  over the rest, until it was gone.

- **A view that joins says where its layout puts it, and nothing before.** A handler of a view's frame heard one
  frame too many on two hosts as the view joined a layout already standing. On UIKit a stepper, a spinner, a date
  picker and a time picker said the size they are made with, at their parent's corner, before the layout placed
  them. On the Web a web view said the box it had before its size was written: the frame's document loads as its
  element is put in the page, and that call from the page ended by itself in the middle of the one laying the page
  out - a call made inside another is now a part of it.

- **A view held by its long press over a motion layout goes with the hand, whichever way.** On Android and the Web
  a held icon dragged along the layout's own way stood still: the layout took the hand from it and turned nothing.
  On iOS and macOS the same rule now decides which gesture begins, so the layout's pan never takes a held view's
  touch.

- **On macOS a press dragged on a view drawn larger or smaller tells how far the hand went.** A pan on a view a
  layout draws at a scale heard the distance divided by it: an app pulled slowly on a home screen flew off the top.
  A view lifted larger by its long press and let go at once landed a place short of the hand.

- **On Android a short, fast throw of a view the hand carries reads its speed.** The speed was read where the finger
  stood in the moving view, so a card thrown up 90 points in 60 ms read as moving down and was never dismissed.

- **On Android a faded layout draws what stands past its edges.** A layout fading out cut the views drawn beyond its
  bounds - tiles switched back mid-way between a grid and a row stood cut flat at its bottom for a few frames.

- **On GTK an app no longer crashes when a gesture's release removes the view it was on.** Pulling an app closed on a
  home screen freed a controller GTK was still dispatching the release to.

- **A program's write ends only the gesture holding what it writes.** A write of a number two fingers held also took
  from the hand the numbers it moved on the same view - a zoom sent while a light table was spread and panned
  stopped the pan.

## 0.8.6 - 2026-11-16

### Breaking changes

- **A build names its host by a package trait, and each head is a package of its own.** `STATEUI_HOST` is gone: a
  head, `Platforms/<Host>`, has a `Package.swift` of its own that builds the application with its host's trait and
  depends on `lib/StateUI.Head` with the same trait, which brings the host. The application's own package is its
  module and its tests, declares a trait per host and defines each host's condition from it; it declares no head and
  depends on no `StateUIHead`. Nothing is inherited from an environment any more - Xcode, SourceKit-LSP and SwiftPM's
  caches see the host as declared - and a head's files need no condition. An application made before moves each
  head's target into its folder's manifest and writes its own as HelloWorld's:

  ```swift
  // Package.swift
  let hosts = ["AppKit", "UIKit", "Android", "WinUI", "GTK", "Web"]
  let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
      + hosts.map { .define($0.uppercased(), .when(traits: [$0])) }
  // traits: Set(hosts.map { Trait(name: $0) }), the module's StateUI dynamic on every platform but WebAssembly

  // Platforms/AppKit/Package.swift
  .package(name: "NotesUI", path: "../..", traits: ["AppKit"]),
  .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["AppKit"]),
  ```

  WebAssembly links no library dynamically, so StateUI and the host layer have a static product beside the dynamic
  one, `StateUIStatic` and `StateUIHostStatic`, which a package built for it takes `.when(platforms: [.wasi])`; an
  application's own library is linked into its head. `stateui build` builds a head by its package, `stateui new` and
  `stateui project library` name the checkout in every manifest of the application, and the VS Code extension indexes
  the application with the chosen host's trait (`swiftPM.traits`, and its condition as a flag, which SourceKit-LSP's
  build system does not yet take from the trait) and the head by its package; it offers releases
  from 0.8.6 on.
- **An application is a folder holding its `stateui.json`.** Beside its `Package.swift`, the file says what the
  application is on every platform - the `identifier` naming it, the `name` shown (its folder's where none is given),
  the `version` shown to its user and its `build` - and neither `stateui` nor the VS Code extension takes a folder
  without one for an application. Every head takes them from there: an Apple bundle's `CFBundleIdentifier`,
  `CFBundleShortVersionString` and `CFBundleVersion` - which were `com.stateui.<name>`, StateUI's release and 1, and
  which an application's own `Info.plist` may no longer say, with `CFBundleDisplayName` and `CFBundleName` from its
  `name` - and an Android head's `applicationId`, `versionName`, `versionCode` and label. `stateui new` writes the
  file: the identifier `--identifier` gives, else `com.example.<name>`, at version 1.0.0, build 1. An application made
  before adds its own file, and its `Platforms/Android/build.gradle.kts` reads it:

  ```json
  { "build": 1, "identifier": "pl.example.notes", "schemaVersion": 1, "version": "1.0.0" }
  ```

  ```kotlin
  applicationId = stated("stateui.identifier")
  versionCode = stated("stateui.versionCode").toInt()
  versionName = stated("stateui.version")
  manifestPlaceholders["stateuiName"] = stated("stateui.name")
  ```

  and its `AndroidManifest.xml` says `android:label="${stateuiName}"`.

- **WinUI, GTK and the Web read what the application is from its `stateui.json`.** The tool lays the file beside a
  WinUI or GTK program and a page's `index.html`, and `app.info` tells its name, identifier, version and build on
  these hosts too. `GTKHost.run(applicationID:)` is `GTKHost.run()` - the desktop knows the application by the file's
  identifier - and `WebHost.run(name:applicationID:)` is `WebHost.run()`; the browser keeps an application's values
  under its identifier, so what a page kept under its name before is not read again.
- **A workspace's file is `stateui-workspace.json`.** `stateui.json` is an application's now: a workspace made before
  renames its file, which keeps what it says.
- **What was chosen stands out of git.** A workspace's application to start leaves `stateui-workspace.json` for its
  `.stateui/workspace-settings.json`, which `stateui settings --startup <application>` writes; a file still saying
  `startup` is refused. Each application keeps its chosen host and each host's device in its `.stateui/settings.json`,
  and `stateui build`, `run` and `package` take them where `--host` or `--device` is left out. `stateui settings` -
  `settings/get` and `settings/set` - shows and changes both. A build's `host` may be left out of `BuildRequest`. The
  VS Code extension chooses through the same files: the window works as the chosen application's host, a device is
  the application's choice by its name, and what `stateui settings` changes shows in the status bar at once.
- **`stateui project library` changes the StateUI a project builds with.** It acts on the project a command reads:
  in an application, the checkout its manifest names - no workspace needed; in a workspace, a checkout or a release
  for every application it lists, as `stateui workspace library` did. `stateui workspace library` and the API's
  `workspace/useLibrary` are gone; `project/useLibrary` takes a `projectUri` and answers a `LibraryChange`.

### Fixed

- The tool: a checkout named by a path that begins as the old one did - `../..` changed to `../../StateUI` - is
  written once in an application's manifest; it was written twice, `../../StateUI/StateUI`.
- The tool: `stateui repo test --plan native --device <device>` gives the device to the suite whose host it is a device
  of - an iPhone to UIKit's, a serial to Android's - and a device of neither is refused; it went to both, so the other
  stood as not run. A suite's own options - `--filter`, `--build-only`, `--architecture`, `--artifact` - are refused
  with `--plan`, which dropped them.
- The tool: a failed operation's last output - the compiler's error - reaches the editor before the operation's end;
  told after it, it was dropped.
- The tool: a launch on a simulator that `simctl` refuses says what `simctl` said and how it ended; it was told as
  one that named no process within a minute, `simctl`'s own words dropped.
- The tool: a build gives SwiftPM five minutes, as any build step, to say where it laid the products, reads the folder
  from SwiftPM's standard output alone, and where SwiftPM names none says what it said and how it ended. Given half a
  minute, a busy machine's answer was lost and a host's suite failed its tests without a word; a warning SwiftPM wrote
  to its errors was taken for the folder.
- VS Code: Run Without Debugging (Ctrl+F5) runs the Debug build with no debugger on every host; it readied one and
  attached it.
- VS Code: no language server's configuration is written while the tool answers no lease of the index; a lease not
  answered was taken for one held.
- VS Code: folders asked for at once share one connection to the tool, and one opens again once it ended; each opened
  its own `stateui serve`, and all but the last were lost. A connection refused at opening ends the process it started.
- The tool: `stateui doctor` asks for no Python 3 for the Web, which nothing uses - the tool serves a page itself; a
  machine without it was told it could not build the Web.
- Web: a debug build's module keeps its DWARF, which the browser's debugger reads. The head's release-only
  `--strip-debug` reached debug builds too - SwiftPM's build system applies a library's linker settings conditioned
  on a configuration in every configuration - so a debugger found no Swift in the page; the tool now links a release
  module without its debugging information itself.
- Web: a bar button whose look follows the pointer and the press takes its click in Safari. The page wrote its words
  and attributes again as the press came and went, its words in a new text node, and WebKit sends no click where the
  node under the pointer was replaced; what already stands is written no more, and new words change the one text node
  in place.
- WinUI: the host and the web view's backend build with Visual Studio 18.12, whose C++ library, MSVC 14.52, refuses
  every Clang below 22 - the Swift toolchain's is 21 - and stopped their relays' first file. Each relay defines
  `_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH`; an application with a relay of its own defines it in that target's
  `cxxSettings` too.
- GTK: a page replaced while the focus stood in it is let go. A link replacing the stack's top page left that page,
  and everything it held, alive for the rest of the run; the focus is taken out of a page before it is replaced away.
- GTK on Wayland: a field that takes the keyboard and goes at once no longer ends the process. GTK 4.22 binds its input
  method as the compositor answers the first field, and kept a field gone before that answer, freed, for the
  compositor's next word to reach; the window now waits for that answer as the first field takes the keyboard.

### Tooling

- A Mac works its GTK and WinUI heads in Parallels guests. `stateui devices --host gtk` (`winui`) lists the Mac's
  Linux (Windows) guests as devices of the kind `guest`, with their state; `stateui guest prepare --device <guest>`
  lays the checkout's stateui in the guest - copied from the folder it shares, built by the guest's Swift - under its
  user's `stateui-guest`; `stateui doctor --host gtk --device <guest>` checks the way to it from the Mac - Parallels'
  `prlctl` (the Pro and Business editions), the guest, Parallels Tools, the project's folders shared, its user's
  desktop session, its stateui - and then what its own stateui finds in it, each finding naming its machine. The tool
  asks the guest's stateui over the protocol an editor speaks, through `prlctl exec`. `stateui build`, `package` and
  `run --host gtk|winui --device <guest>` work there: the guest started or resumed, its stateui laid where it is not
  this release, the project and its checkout copied in - the files git tracks and would track - and
  the request asked of it; a package lands in the Mac's `artifacts`, and Ctrl+C on the Mac stops the application in
  the guest. `application/run` starts a GTK or WinUI head of its own machine too, followed until it ends. The VS Code
  extension offers GTK and WinUI on a Mac, the guest chosen in the status bar (**StateUI: Select Guest**): a launch
  and **StateUI: Package** work there - a Debug launch with no debugger, said - and **StateUI: Check Toolchain**
  checks the guest chosen too. In a checkout, `stateui repo test --suite host:gtk|winui --device <guest>` runs the
  host's own suite in the guest, and **StateUI: Run Tests** there too; a test run (`tests/run`) takes a `filter`.
- The tool decides, and every client shows: `server/info` - and `stateui version` - names the hosts this machine
  builds and where each one's heads run (`hosts`: the machine itself, a device, a browser or a guest); `devices/list`
  names this machine (`machine`) for a host whose heads run on it, and each destination says whether a debugger
  reaches it (`debugger`) and the architectures it runs emulated (`emulated`, x86_64 on an ARM64 Windows); `stateui
  doctor --host <host> --device <guest>` checks this machine and then the guest, in one report. The VS Code extension
  reads all of it from the tool - the hosts it offers, a browser's or a guest's debugger, WinUI's package
  architectures - and keeps no table of its own.
- The tool says how a debugger reaches every application it readies (`DebugDescriptor`): `application/prepare`
  builds and readies a head of this machine - AppKit, WinUI, GTK, a GTK head installed and a copy running stopped -
  for LLDB to start its program; `application/run` with `debugger` hands the way to a simulator's, a device's or an
  Android head's process in its `started` event (`debugger`, in place of `debuggerSocket`), and readies a page for a
  browser a debugger follows, which it then opens in none. `stateui run --debugger` prints the LLDB commands. The VS
  Code extension maps the way to lldb-dap or its JavaScript debugger and builds none itself.
- The VS Code extension offers the WebAssembly DWARF Debugging extension as a Debug launch in one of Chromium's browsers
  is readied, where it is missing, and **StateUI: Check Toolchain** says whether it is installed wherever the machine
  offers the Web: through it a breakpoint on a line of Swift holds in the page, the call stack naming Swift's
  functions; the variables are WebAssembly's, as the browser's debugger reads no Swift types.
- A page is debugged in Safari 27 with LLDB: a Debug run in Safari opens the page there and names LLDB's way to it
  through Safari's WebAssembly debugger (`platform select webinspector-wasm`, the page's process attached), which VS
  Code's lldb-dap takes - Swift's lines and call stack, the variables' Swift types without their values yet. Safari's
  feature flag *Experimental WebAssembly Debugger* turns it on, and the run says so where no page appears; `stateui
  doctor` requires Safari 27 for Debug in Safari, and `stateui run --debugger` prints LLDB's commands for a page too.
- `stateui service --listen <address:port>` serves the tool's protocol over TCP - the one an editor speaks over
  `serve --stdio` - to many clients at once, on any address it is given; its sockets are the tool's own on macOS,
  Linux and Windows. It admits a paired client alone: it shows a pairing code, `stateui remote add <name>
  <address:port> --code <code>` pairs a project with another machine (`stateui remote list`, `remove`, `--project`),
  kept in the project's `.stateui/remotes.json` out of git, and every connection proves its token by the HMAC-SHA256
  of a challenge, the token never sent.
- A project's manifest declares the machines everyone works it on: `remotes` of `stateui-workspace.json`, else of
  `stateui.json` - a name, an address and the identity the machine's service answers for, no secret. `stateui remote
  declare <name>` writes a machine paired there, `stateui remote add <name> --code <code>` pairs a declared one by its
  name, refused where another identity answers, and a declared machine is reached at the address declared.
- A machine paired with a project is a destination of the hosts whose heads run there as its own programs:
  `server/info` tells them at the place `remote` and says the folder another machine's projects are copied into
  (`workFolder`), and `devices/list` lists the machine (`remote`).
- `stateui build`, `run`, `package` and `repo test --suite host:<host>` with a machine paired as the device are that
  machine's work, through its service: the project and its checkout copied there, the request asked of its own
  `stateui` - which is to be this release - a package fetched home, a run's output told as it comes; each machine's
  copies and packages stand in a folder of its own there, `stateui-guest/<identity>`, named by the identity the tool
  makes once in its state folder (`identity.json`), which a service answers for in its challenge, its pairing and
  `stateui service status`, and which every connection checks before it proves its token; a guest paired is
  reached through its service too, else through `prlctl exec`. `stateui doctor --device <machine>` says whether its
  service answers and admits this machine, its release, and what it has of what the host needs. The VS Code
  extension's **StateUI: Select Machine** offers a host's guests and machines paired, and a launch on one runs there.
- `stateui repo conformance run --host <host> --device <machine>` runs a host this machine works on another - GTK and
  WinUI on a Mac - on that machine, the checkout copied there; `--record` fetches the host's
  `lib/StateUI/exports/marks/<host>` home and renders the documents here. The VS Code extension's conformance commands
  run there for such a host.
- A machine paired offers its devices and browsers - a Mac's simulators and iPhones, Android devices: `devices/list`
  asks it through its service, each destination named by its `machine`, and `--machine <name> --device <its device>`
  (`BuildRequest.machine`) builds, packages and runs a head there.
- `stateui repo test --plan portable|native --device <machine>` runs the plan on a guest or a machine paired, the
  checkout copied there - `repository/plan`, the plan's operation, which any client asks.
- `stateui run --host gtk --gdb` (`RunRequest.gdb`) runs the head under gdb through `application/run`, so on another
  machine too - `--device <guest>` - each GTK critical's stack and a crash's told here, the command ending as gdb does.
  `--debugger` means LLDB on every host: a GTK or WinUI head is held by the toolchain's `lldb-dap`, listening on a port
  of the loopback (`DebugDescriptor.adapterPort`), which the editor's debugger connects to. On another machine the
  debugger is relayed through its service - `service/relay`, granted to a paired client for a port a run holds - to a
  port of this machine's loopback, the relay turning the adapter's paths between the two machines; no debugger port
  listens on the network. The VS Code extension's Debug launch on a machine
  paired - a paired guest too - holds the head there and attaches lldb-dap that way. `stateui run` of a GTK or WinUI head takes the protocol's road.
- A folder travels to another machine's tool, and back, through the connection itself - `folder/survey`,
  `files/write`, `file/read`, `files/remove`, in pieces of at most 4 MiB, a file's time kept - over a guest's
  `prlctl exec` as over the service: a guest reads the project and hands a package back through no shared folder;
  only its own stateui is laid from the shared checkout.
- `stateui service install --listen <address:port>` lays the service to start with its user's desktop session - a
  launch agent on macOS, a user unit of the graphical session on Linux, the user's `Run` value with no window on
  Windows - and starts it; `uninstall` takes it away, `status` says where it listens and the code it shows. On Windows
  it opens the service's port in the firewall to the local subnet alone, asking UAC once. `stateui guest pair --device
  <guest>` lays a guest's service and pairs the Mac with it by its address, a Windows guest's firewall opened by the
  Mac with no prompt; `stateui service restart` starts the service again on its program laid anew. A guest's stateui laid by the Mac is
  the `stateui` of the guest's terminals, and its service is started again on it. `stateui remote list` says whether each machine's service answers and admits this one, with its system
  and hosts; `stateui remote probe <address:port>` whether a stateui service answers at a place and is paired here.
- `stateui new --platforms appkit,web,winui` makes an application with those hosts' heads alone; an application's
  hosts are its heads, so one is taken away by removing its `Platforms/<Host>`.
- The operation journal in `.stateui/operations` keeps the newest 50 operations, never one still running; an
  application `stateui new` makes outside a workspace has a `.gitignore` keeping `.stateui/` out of git.
- `stateui run` hands an application it starts on a simulator, a device, Android or a page every `STATEUI_` variable
  of its own environment, `STATEUI_TALLY=1` among them, as a head on the Mac, Linux or Windows has always had.
- A GTK head run with `--gdb` ends as its program does: its exit status, or a crash's signal with every thread's
  stack.

## 0.8.5 - 2026-11-13

### Breaking changes

- **AppKit builds through `stateui`.** `.scripts/AppKit/run-app.sh`, `build-gallery-appkit.sh` and `deploy.sh` are
  gone: `stateui run`, `stateui build` and `stateui package --host appkit` take their place, and every application,
  not only the Gallery, runs as a bundle.
- **UIKit builds through `stateui`.** `.scripts/UIKit/run-app.sh`, `build-app.sh` and `deploy.sh` are gone:
  `stateui run`, `stateui build` and `stateui package --host uikit --device <name or id>` take their place, a
  simulator's build and a device's keeping scratch folders of their own; `.build/uikit/debugger.json` goes, a run
  saying its process instead.
- **Android builds through `stateui`.** `.scripts/Android/run-app.sh`, `deploy.sh` and `devices.sh` are gone:
  `stateui run`, `stateui build`, `stateui package --host android --device <serial or name>` and `stateui devices --host
  android` take their place, an ABI's build keeping a scratch folder of its own and the symbols beside the APK in its
  artifact; `.build/android/debugger.json` goes, a run saying its process and the debugger's socket instead.
- **GTK builds through `stateui`.** `.scripts/GTK/run-app.sh` and `deploy.sh` are gone: `stateui run`, `build`,
  `install` and `package --host gtk` take their place; a build no longer writes the user's desktop entry - `install`
  does, and `run` installs - and `run --debugger` runs the head under gdb with every GTK critical's stack said.
- **WinUI builds through `stateui`.** `.scripts/WinUI/run-app.ps1` and `deploy.ps1` are gone: `stateui run`, `stateui
  build` and `stateui package --host winui [--architecture x86_64]` take their place, a head published in
  `.build/stateui/artifacts` - no longer `.build/winui/<configuration>` and its `.program` file.
- **Web builds through `stateui`.** `.scripts/Web/run-app.sh`, `deploy.sh`, `page.sh`, `serve.py`, `browsers.sh` and
  `size-budgets.sh` are gone: `stateui run`, `stateui build`, `stateui package --host web`, `stateui devices --host
  web` and `stateui repo web-size check` take their place. A page is laid in the build's artifact, no longer
  in `.build/web/site`, and `.build/web/server.json` goes, a run saying the page's address instead; the page is served
  to this machine alone unless `--listen lan` shares it.
- **`resvg` draws every picture.** The AppKit, UIKit and Android heads' pictures and icons are drawn by `resvg` of the
  pinned release, 0.50.0, on every machine - the same pixels wherever a head is built - no longer by AppKit: install it
  (`brew install resvg`, `cargo install resvg --version 0.50.0`, or its release archive), or name it with
  `STATEUI_RESVG`; `stateui doctor` checks it. The asset catalog and `.icns` stay Apple's tools' to write.
  `.scripts/rasterize-images.swift` is gone.
- **The hosts' marks, declarations and API records are recorded by `stateui`.** `test-appkit.sh`, `test-uikit.sh`,
  `test-android.sh`, `test-gtk.sh`, `test-web.sh` and `test-winui.ps1`, their `tools.sh`, `tools.ps1`, `build-swift.sh`
  and `swift-sdk.sh`, `.scripts/API/record.sh` and `record.ps1`, and `.scripts/Marks/revision.sh` are gone:
  `stateui repo conformance run --host <host> --all | --changed | --family <name> --record` writes a host's verdicts
  - with `--all` what it declares too - and renders the documents, `stateui repo api record [--host <host>]` writes
  the API records, and `stateui repo conformance status` says where each family's verdicts stand.
- **`.scripts` is gone.** `.scripts/test-native.sh` is `stateui repo test --plan portable` and `--plan native` - on a
  Mac the native plan tests the Gallery and HelloWorld as AppKit builds too (`apps:appkit`) - and `new-app.sh` and
  `new-app.ps1` are `stateui new <Name> --directory apps`. The VS Code extension knows a checkout by its
  `Package.swift`, `lib/StateUI.Head` and `apps/HelloWorld`, as the tool does.
- **A WinUI backend declares what it lays beside an application.** `lib/Backends/<Element>.WinUI/SelfContained.ps1`
  is gone: a backend lists the files its engine needs in `Packaging/runtime.txt` - a line a file, the NuGet package,
  its path there (`{architecture}` for `arm64` or `x64`) and its path beside the application - and only an application
  that depends on the backend gets them. The web view's backend declares WebView2's component and loader.
- **A project group is a workspace.** The VS Code extension finds applications through `stateui`: in a folder that
  is an application, that one; else the ones the nearest `stateui.json` up lists - and no longer every folder of an
  `apps/`. **StateUI: New Project Group** makes a workspace: `stateui.json`, the StateUI it builds with, and its first
  application beside it (`MyApps/Notes`, naming `../StateUI`), and **StateUI: Deploy** lays it in the workspace's
  `artifacts/`. A group made before lists its applications in a `stateui.json` at its root:

  ```json
  { "schemaVersion": 1, "library": { "path": "StateUI" }, "projects": ["apps/Notes"] }
  ```

  `library.path` is the StateUI its applications build with, from the group's folder - `StateUI` for a release
  cloned into it.

### New

- **`stateui`, StateUI's developer tool, begins.** `tools/StateUI.CLI` builds the `stateui` program on macOS, Linux
  and Windows. `stateui version` says its release, the API it speaks and the machine it runs on - in words, or for a
  program with `--format json` or `--format jsonl`. `stateui doctor` says what each host needs of this machine and
  what to install. `stateui new` makes an application - HelloWorld renamed - wherever it is asked to;
  `stateui project describe` reads the applications of a folder. A workspace is a `stateui.json`, found upward from
  where the tool runs, naming its applications and the StateUI they build with: `stateui workspace create` makes one
  from a checkout or a release, `stateui workspace library` points every application at another, and
  `stateui releases list` lists the releases. `stateui serve --stdio` answers an editor's JSON-RPC over standard input
  and output - the same answers, and the making as operations with events and a cancel. It builds, runs and tests no
  application yet: until it does, `.scripts` build and run each host as before.
- **`stateui build`, `run` and `package` make AppKit applications.** Every application is a bundle - its name,
  identifier `com.stateui.<name>` and icon - with its own `Platforms/AppKit/Info.plist` keys laid over the host's;
  a failed build never runs or packages an older one; one application builds at a time on a machine. The Gallery's
  name, links and location purpose stand in its own `Info.plist`.
- **`stateui build` and `package` make UIKit applications** for the simulator or device `--device` names - the
  booted simulator, else an iPhone, where none is named. A simulator's bundle is signed ad hoc; a device's with the
  development profile that provisions it, found before the build. A simulator's build and a device's keep scratch
  folders of their own.
- **`stateui build` and `package` make Android applications** for the ABI asked for, else the device's named, else
  `arm64-v8a` - the APK with its native libraries and their symbols beside it in the artifact, its pictures and its
  launcher icon drawn for it; an ABI's build keeps a scratch folder of its own.
- **`stateui build`, `install` and `run` make GTK applications** on Linux: the program, its libraries and its
  pictures published as the build's artifact; `stateui install --artifact` writes the desktop entry and icon for the
  user - no longer a build's side effect - and `run` builds, installs, stops a copy still running and runs it.
- **`stateui build` and `package --host web`** build a Web head's module with the Swift SDK for WebAssembly of the
  compiler's release and lay its page beside it - the same page the scripts laid.
- **`stateui run --host web`** serves a Web head's page from its build on this machine alone - `--listen lan` shares it
  with the network - on port 8460, else a free one where another program holds it, and opens it in the system's
  browser, every `STATEUI_` switch a parameter of its address; the page's server is the tool's own, on SwiftNIO.
- **`stateui build`, `run` and `package --host winui`** make WinUI heads on Windows, for the machine's own
  architecture or, with `--architecture`, the other - on ARM64 x86_64 too, run by Windows' emulation: the pinned
  NuGet packages fetched and checked against nuget.org's catalog, the C++/WinRT projection made where a pin changed,
  the Windows App SDK laid beside the head with a manifest registering its classes and `resources.pri`, another
  architecture's Swift runtime unpacked from the Swift installer's merge module; a package also carries the Swift and
  C++ runtimes, so it runs where nothing is installed. A running copy is stopped before its build.
- **`stateui run --host uikit`** installs and starts a UIKit head on its simulator or device and follows its output;
  `--debugger` starts it held until a debugger attaches, saying its process. `--host android` does so on a device or
  emulator - a virtual device named but not running is booted - every `STATEUI_` switch handed to the application,
  its log followed; `--debugger` readies the NDK's `lldb-server` in its sandbox and says its socket. Ctrl+C, or an editor's cancel of
  `application/run`, ends the application and every process the launch started.
- **`stateui devices --host uikit`** lists the iPhones and iPads paired with the Mac, then the simulators, the newest
  iOS first - each with what names it, its system, and whether it is booted or how it is reached; `--host android`
  the attached devices and running emulators with their Android version and ABI, then the virtual devices not running;
  `--host web` the browsers installed, the system's own marked, each with its program - on Linux the desktop entries
  shown on the desktop running.
- **The VS Code extension works through `stateui`.** It finds the applications, checks the toolchain, makes a
  project group and a new application - **StateUI: New Application**, beside a workspace's applications - and checks
  their names as they are typed, all by the tool; the `stateui.cliPath` setting names it where it is not on the
  search path. The making shows in a notification that cancels it. Every host's Debug, Release, Deploy - WinUI's for
  either architecture - and own suite in Run Tests go through the tool, as do the UIKit and Android device lists and
  the browsers; a UIKit or Android head's output and a page's server are in **StateUI Run**, its notification stops
  it, the end of a debug session ends it, and a second launch in its place replaces it. **Conformance - Rebuild all**
  and **Rebuild changed** have the tool record the chosen host's families - the Web's and Android's stale ones too.

### Tooling

- The release's version stands in the library's `ApplicationInfo.libraryVersion`; the editor extension's
  `package.json`, the tool's release, the Android heads and the bundles are its copies, which `ReleaseTests` holds.
- Swift 6.4.2 is the release StateUI builds with: the workflows' images and installers, the Swift SDKs for Android
  and WebAssembly and the handbook name it, and `ToolchainTests` holds one patch release everywhere.
- `stateui index describe [--host <host>]` (`index/describe`) says what a language server indexes a host's code with -
  its scratch folder, and the triple and SDK where its heads run elsewhere, or why it falls back to this machine - and
  `stateui index clean` (`index/clean`) takes every index's scratch folder away; the VS Code extension takes both from
  the tool instead of reading the Swift SDKs and Xcode itself.
- `stateui repo conformance status [--host <host>]` says, family by family, whether each host's recorded verdicts
  stand at the revision `revisions.txt` gives - read by the library's own reader through the conformance package's
  helper `stateui-conformance-metadata`.
- `stateui repo conformance run --host <host> (--changed | --family <name> | --all) [--record]` runs a host's
  families whole through its suite - a run of no test fails - holding the verdicts and the control dictionary to the
  marks, or with `--record` writing the verdicts and rendering the dictionary and the platform contract, each a phase
  of its own; on Android the stale families and each file's revision come from the conformance package's helper.
- `stateui repo api check | record [--host <host>]` holds the public API to `lib/StateUI/exports/api` or writes it:
  the library's surfaces, or with `--host` the host's facade, backends and testing module after its suite.
- `stateui repo docs check | update` holds the control dictionary and the platform contract to the marks or renders
  them; `stateui repo samples check | update` holds the Gallery's and the handbook's listings to their code, the
  review standing, or writes them once the notes were read.
- `stateui repo test --plan portable | native [--suite <id>]` runs the owner packages' suites in order, each apart -
  portable: the library, the host layer, the conformance runner, application testing, the Gallery, HelloWorld and the
  tool; native: this machine's host suites, one with no device listed as not run - a failure never stopping the rest.
- `stateui repo test --suite host:winui` runs the WinUI host's suite on Windows - the foundation's Windows tests, the
  host's tests each in a process of its own with the test runner made self-contained, both API records - and the
  conformance families only where `--filter` names them (`WinUIConformanceTests`, or one of its tests).
- `stateui repo test --suite host:web` runs the Web host's suite - the facade's API record, the host's tests in Node, the
  conformance families and the host's browser tests headless in Chrome or Chromium - and `stateui repo web-size check` holds each
  release module within its budget; `web.yml` runs both. `--suite host:gtk` runs the GTK host's - the foundation's Linux
  tests, the host's, every verdict held, both API records - and `gtk.yml` runs it.
- `stateui repo test --suite host:android --device <device>` runs the Android host's suite - every test listed, the test
  APK on the device with its screen kept on, `android.txt`, every family's verdicts and the facade's API record held;
  `--build-only --architecture x86_64` builds the test APK alone with its identity and `--artifact <folder>` runs it
  elsewhere, refusing one of another ABI or commit - `android.yml` builds on macOS and runs on Linux so.
- `stateui repo test --suite host:uikit --device <simulator>` runs the UIKit host's suite - its test application on the
  simulator, its accessibility on, every verdict held, then the facade's and `StateUITesting`'s API records for the
  simulator - and `uikit.yml` runs it; the test application's identifier stands in its own `Platforms/UIKit/Info.plist`.
- `stateui repo test --suite host:appkit` runs the AppKit host's suite - its tests, every conformance verdict held, then
  its API records, each a phase of the result - and the AppKit workflow runs it.
- `stateui test list [--host <host>]` (`tests/discover`) lists a folder's suites for a host, in the order they are
  best run, and `stateui test run --suite <suite> [--host <host>] [--device <device>]` (`tests/run`) runs one - a
  package's by `swift test`, a host's as `stateui repo test` does. The VS Code extension's suites stand in the Testing
  view, found and run by the tool, and **StateUI: Run Tests** runs the ones picked there too, their output in Test
  Results.
- `stateui repo integration package --editor vscode` (`repository/integrationPackage`) packages the checkout's VS Code
  extension into `artifacts/stateui-<version>.vsix`, and `install` (`repository/integrationInstall`) has VS Code's
  `code` install it and finds it listed at that version; **StateUI: Reinstall VS Code Extension** goes through both,
  and **Conformance - Rebuild all** and **Rebuild changed** through `repository/conformance`, their phases named at
  the end. **StateUI: Deploy** is titled **StateUI: Package**, as `stateui package` does the work; its command,
  `stateui.deploy`, stays. A `swift test` a suite runs that ran no test fails, filtered or not.
- One package is indexed as one host at a time: `index/acquire` holds a window's packages as its host for the
  connection's life, and answers the package and host where another window holds one as another host. The VS Code
  extension takes the lease before it writes a package's `.sourcekit-lsp/config.json` - a host another window holds is
  refused, the one before kept, and a window opening on such a package works as that host; `index/clean` leaves a
  package another window holds, saying its host. `STATEUI_STATE` names the tool's state folder - its build permit and
  index leases - which the extension's suite gives its own. The extension declares no `stateui` task type any more: it
  made its own tasks with it, and no task of a `tasks.json` ever ran by it. The extension runs the tool from the user's
  home, so on Windows a folder it holds a connection for can be removed or renamed.
- `stateui repo distribution package [--output <folder>]` builds the tool for release - the Swift runtime linked in on
  Linux and Windows - and archives it for this system and architecture with its license, NOTICE and the notices of the
  packages built into it, its SHA-256 beside it; then reads the archive back: what it holds, the libraries its program
  loads, and the program run with no Swift on the search path. The tool's workflow keeps one per system from every run.
- The `stateui` tool has a workflow of its own (`cli.yml`): its suites on macOS, Linux and Windows, then the editor
  extension's client of it against a real `stateui serve --stdio`.
- `stateui package` lays a package only in a folder that stands empty or that a package was laid in before - its
  `.stateui-package` says so - and never in one holding the application, its project or its checkout; the folder is
  checked before the build.

## 0.8.4 - 2026-11-10

### Breaking changes

- **A split view stands at a window's or a sheet's root.** A `SplitView` is the root of a window or of a sheet; on a
  stack's page, in a tab or in another split view's detail it is left out, and said so as a complaint. It has no
  title or icon of its own: `.pageTitle(_:)` and `.pageIcon(_:)` written on a split view, or on a view whose body is
  one, are said and left out, where a stack takes them and its pages keep their own. Host authors:
  `PageElementContract.linkOpened` is `OpenedLinkElementContract.linkOpened`, which a page and a split view wear.

### Fixed

- State: a report through a conversion asks its sources, as every road a value comes in by does - a value a source
  refuses, such as a window's value another window holds, lands nowhere and the control goes back to it; a report
  into two sources refusing together lands whole or not at all; a refusal two links up a chain lands on no link; and
  a report that does not land leaves every journey whole and publishes nothing it took back. Two views named alike
  under two parents keep a conversion each, and an environment value stands where it is placed. A host event passes
  the gate, and an engine runs at the priority, the last render wrote; a reading booked for its window's end goes
  with its element.

- Numbers: a number past what a toolkit counts no longer ends the process - a tab chosen past `Int`'s reach on GTK,
  iOS and Windows, a window asked a size or a place past what the Mac and Windows count, and on GTK a canvas's words
  or a text editor wider than the toolkit measures; on Windows such a window no longer falls to its least size.
  A spring of any response and damping - in a motion or a layout's body - stays a number and lands by the longest
  a spring animates, however far it goes and however fast it sets out; an arc of any radii draws numbers, the long
  way round a far-radii arc its ellipse; a row of dots holds any position, a held card stands over any rank, and a
  run let go far past its axis approaches its target in numbers. A cadence held back past twenty-four days holds on
  a 32-bit `Int`, and on the Web a wait that long is asked for in parts; on the Web a day of the first century
  reads its own time zone's offset. A path ending on a bare command is refused whole.
- Pages and menus: a popover larger than the screen stands within it on the Mac; a context menu open as its view goes
  closes with it on Android and the Web. A split view's sidebar out of sight reaches no shortcut. On the Web a menu
  open under a bar goes with what it stands for - its item, its page, a page joining only the Edit menu. On the Mac a
  disabled split button opens no menu, and a menu on the bar at the page's foot opens - a held one keeping its
  click - as on the window's bar; on iOS a disabled split button's arrow opens no menu and is heard dimmed, and what
  comes after a share sheet stands. On Android a sheet follows its window across 600 points; on Windows a choice of
  actions lets go of its dialog. A window's act asks over the window its page stands in.
- Input: on Windows a press whose view went mid-press no longer keeps the mouse from every other view, and a view
  whose drag is offered again hears each drop once; on the Web a view let go of while pressed leaves nothing
  listening on the page, and a view that stops hearing a drag gives the page its touch and its selection back.
  A view fading out answers no press on every host, and a disabled view offers no pull to refresh; on Android a view
  scaled to nothing takes no touch. On Android, GTK and Windows a pan says where it is in the view's own points. On
  the Mac a drag lets go of a target that leaves and finds one that came under it; on iOS a pinch or a rotation the
  system takes away ends cancelled. A selection reads back in characters, and a prompt's bound counts whole
  characters on the Mac and GTK. On the Web a late paste lands in no other field, and a field that left is held by
  no Edit menu.
- Text: on the Web a text's words are selected only where the application says so; on Windows a text editor that
  does not grow stands a whole line tall at every scale, with no scroll bar over its one line. A run given no space
  between its letters or no lines stands so in a label that gives them; on the Web a text's lines reach its runs on
  every frame, and a run takes no line it does not say. Kept words and a window's values read back whole whatever
  follows an escape - a combining mark, a joiner. A POSIX suffix alone is no language tag.
- Controls: on the Web a button given the ordinary role (`.normal`) no longer ends the application; a disabled picker
  offered as segments or radio buttons keeps the values it offers later disabled, and a picture changed to one the
  application does not have takes no room. On Android a read-only password keeps its weight, a bar given no
  foreground takes the theme's again, and radio buttons and segments keep the look they are given; on GTK a stepper
  follows a state's journey; on Windows an icon keeps its words for assistive technology as it changes.
- Layout: on the Web a list turned into a row keeps each item scrolled away at the width it took, a view freed of
  its area in a layered stack fills the room again, and a list that becomes the page's scroller as a view beside it
  goes keeps its last items clear of the bar at the foot. The bars over and under a page no longer listen again to a
  scroller each time it is the page's again. On Windows at a scale of 125% a list scrolled to an item as it is made
  stands it there, and a list at its end stays there as a bar beside it grows: a cell no longer changes its size as
  its entry comes, on Windows, GTK and Android alike, and a Windows list is no longer measured before it stands
  anywhere. On Windows at 125% a layout no longer runs for ever and ends the application - wrapped words given
  their own width back keep their line - and a layout WinUI gives up on is said as a complaint while the
  application goes on. A child stating no width is measured at the width it is placed at, and a list showing no
  item reaches no end. On iOS a page stands clear of the keyboard, and on the Web a phone's keyboard stands in the
  safe area; on the Web a view in a layered stack stands in its area as in any slot, and a child filling its slot
  stops at its most.
- Drawing: a gradient's stops stand at their own offsets whatever order they are written in, on every platform; on
  Windows a path's curve after a close begins a figure of its own. A pushed page's gradient is drawn across the whole
  page on the Mac and iOS; on the Web a blur goes with the look that said it.
- Accessibility: on iOS, under VoiceOver, a color picker and a switch say what the application says of them - name,
  kind, value, whether VoiceOver meets them - where UIKit's own words stood; on the Web words made at run time and
  told to the screen reader are said as asked, a list the user chooses in names its items options, and a shortcut on
  the plus key is named as assistive technology reads it. On Windows assistive technology choosing a segment or a tab
  of a row that has left no longer stops the application answering.
- Hosts: on GTK a popover waiting for its hidden anchor, the frame clock and a press hold what they use; Windows keeps
  no record of what an application told the screen reader or launched, and a password field swapped in lets the
  control before it go.
- Testing: a test window acts only as its user can - a slider's thumb stops at its ends, a value that is no number
  slides nothing, and a switch's or a field's act is no label's.
- Pictures: on the Mac and iOS a picture larger than the whole budget of pictures kept no longer pushes every other
  one out, and what is kept follows that budget alone until the system says memory runs short.
- Gallery: on the Web the Map sample makes Google's map once and hands it on, as Google asks maps to be reused, so
  shown again it leaves no map behind.

### Tooling

- The examples in the libraries' documentation comments are held to the library as it stands
  (`DocCommentExamplesTests`).
- A host's driver opens a view's context menu as the user asks for it and reads the menu shown (`UserAct.openMenu`,
  `HostDriver.shownMenu(over:)`), and the UIKit suite runs as VoiceOver does, UIKit's accessibility answering.
- Every host's suite writes every case of every closed vocabulary to every element wearing it and holds the host to
  taking each (`ClosedVocabularies`); Android walks it in parts a phone takes.

## 0.8.3 - 2026-11-09

### Breaking changes

- **A page's title is `.pageTitle(_:)`.** `.title(_:)` written on the view a page shows is `.pageTitle(_:)`, as
  `.pageIcon(_:)` and `.pageBackground(_:)` are: `SettingsPage().pageTitle("Settings")`. A map marker keeps its
  `.title(_:)`.
- **A page says no subtitle.** The line under a page's title is no longer offered: `View.subtitle(_:)` and
  `PageContract.subtitle` are gone, and a page says what it needs in its title or in its content. A map marker keeps
  its `subtitle`.
- **A sheet stands over the window's overlays.** Overlays declared on a window's page stand over every page it shows
  and under its sheets, on every platform; overlays declared on a sheet's page stand over that sheet, which on iOS,
  GTK and the Web they did not. An overlay meant to cover a sheet is declared on the sheet's page.

### New

- **A branch is written in its localization's language.** A `Localization` given with `.environment(_:)` says the
  language it speaks on its branch: a screen reader reads the words there in it and the platform sets them by its
  rules - every view on iOS, Windows and the Web, a text's words on the Mac, Android and GTK. The Web page says the
  browser's language until the application says its own. A host reads it as `LanguageElementContract.language`.
- What a host writes for the user itself - a split button's arrow, a map pin's details button, a save named nothing -
  speaks the user's language.

### Fixed

- Numbers: a number that is none - NaN or infinite - is no value to a view, and a number past what a toolkit counts
  no longer ends the process: a range's ends, a line limit, a prompt's bound, a grid's tracks, a day outside the
  years 1 to 9999, a font weight, a wheel, a hand, a map region off the globe, a stepped number on the Web, and sizes
  and spacing on GTK and WinUI.
- Pages and sheets: a sheet stays as the window is arranged anew; a sheet shown again shows its page on GTK and WinUI;
  the way back is named by the page beneath it; a page saying no title stays named on GTK; each group behind a bar's
  More is a section of its menu; a page's scroller keeps clear of the system bars as its axes change.
- A view whose root may change: a key reaches what it holds, the chrome reads its bars and tabs, a list item offers
  its swipe actions, and a sheet shows the arrangement it holds.
- Input: on Android a view with no hold or menu takes no long press; the keypad's Enter presses Return on Android and
  GTK; on the Web and WinUI a field turns into its case what is typed however the words come - a paste, an input
  method; a button whose role is taken away wears plain words again.
- State and time: a scene value holding a map keyed by a key type comes back as it went; a ticker ticks no further
  than its limit; a state's move arrives even when the last control carrying it leaves before the move begins; a new
  application starts without the theme and accent of the one before; the Apple hosts read the time on the Gregorian
  calendar whatever calendar the user reads; reading the time throws, rather than ending the process, where a host
  answers no number.
- Drawing, web views and maps: an arc's flags written together are read; a web view keeps the user's page as its
  host is told the whole tree again; a script answering NaN or a date no longer ends the application.
- Hosts: a picture keeps its size as Android's display density changes, and a window made again at the new density
  stands alone in its root; GTK paints a journey's style where it lands rather than adding to its style sheet every
  frame.

### Tooling

- CONTRIBUTING says how comments and design notes are written: under a quarter of a file's lines, with a reason, a
  trap or a rule in `docs/design` behind a `Design:` reference.
- The Gallery's window overlay sample opens a sheet with a notice of its own.

## 0.8.2 - 2026-11-08

### Breaking changes

- **Apple's systems from 26.4.** StateUI runs on iOS, iPadOS, Mac Catalyst and macOS 26.4 or newer: an application's
  manifest says `.iOS("26.4")`, `.macCatalyst("26.4")` and `.macOS("26.4")`. The Swift runtime of 26.0 to 26.2 stops
  the process where one isolated deinit runs inside another.
- **A control takes its purpose value once, in its initializer.** A text's words, a toggle's words and state, a
  slider's or a stepper's value, a picker's date or time, a line's ends, a canvas's drawing and a web view's address
  are given where the control is made; the modifiers that set them again, and a style's setters of them, are no
  longer offered.
- **Every kind is named a kind.** `MapType` is `MapKind`, `MarkerType` is `MarkerKind`, `WindowType` is `WindowKind`
  and `WebNavigationType` is `WebNavigationKind`; `Map.type`, `Marker.type` and a web navigation's `type` are `kind`.
- **Dates and times are read by a format.** `DateStyle` is `DateFormat`, and a time picker's `.format(_:)` takes a
  `TimeFormat` - `.short` unless said. A date picker's `minimumDate` and `maximumDate` are `minimum` and `maximum`.
- **A page's icon is `pageIcon`.** `.icon(_:)` on a view that stands as a page is `.pageIcon(_:)`; a button's
  `icon` is its own picture.
- **A drop is heard as it happens.** `.onDragOver`, `.onDragLeave` and `.onDrop` are `.onDragEntered`,
  `.onDragExited` and `.onDropped`.
- **A view's presence to accessibility is one setting.** `.isAccessibilityHidden(_:)` and
  `.hidesChildrenFromAccessibility(_:)` are `.accessibilityPresence(_:)`: `.element`, `.hidden` or
  `.hiddenWithContents`.
- **The debug inspector says so.** `InspectorButton` is `DebugInspectorButton`, `Inspector.Place` is
  `DebugInspector.Place` and `ToolbarButton.inspector` is `.debugInspector`; a window's inspector is
  `window.debugInspector`, the place it shows in or nil, where `openInspector()`, `closeInspector()`,
  `toggleInspector()` and `isInspectorOpen` stood.
- **An event is written one way.** A policy is always `policy:`, after the event's own arguments, and every event is
  heard plainly, with a policy or through a gate. `Picker.onSelectedIndexChanged` is `.onSelectionChanged`. A swipe
  hears a `SwipeDirections` set and reports the one direction it took.
- **Motion says what moves.** A motion layout's `.motion(_:)` for its parameters is `.parameterMotion(_:)`;
  `.followsLayout(response:damping:)` is `.layoutBody(.followsLayout(response:damping:))`. `LayoutInput`'s
  `pointsPerUnit:` is `lengthPerUnit:`. `Motion.custom`, `LayoutInput.Travel` and `MotionLanes` are gone.
- **A clock reads in seconds.** `EngineCycle.now`, `.elapsed` and `.mostElapsed` are `nowSeconds`, `elapsedSeconds`
  and `mostElapsedSeconds`. `Ticker.isRepeating` is gone: a delay is a ticker with `limit: 1`, and `$ticker.interval`
  and `$ticker.limit` are bindings.
- **A fact says what is; a request may be nil.** `application.info.versionString` and `buildString` are `version`
  and `build`, `device.info.versionString` is `platformVersion`. `LocaleChoice` and `ColorScheme.system` are gone: a
  locale choice and `application.colorScheme` are nil to follow the system. `LocaleTag.direction` and
  `LocaleInfo.layoutDirection` are `writingDirection`, a `WritingDirection`.
- **The platform's own choice reads automatic.** `GridLength.auto`, `GridTracks.auto`, `InputPurpose.default`,
  `SubmitLabel.default` and `ToolbarStyle.system` are `.automatic`; `TextCase.default` is `.none`.
- **Drawing speaks a transform's words.** `Draw.saveState()`, `.restoreState()`, `.translateBy` and `.scaleBy` are
  `saveGraphics()`, `restoreGraphics()`, `translate` and `scale`, with `scaleX` and `scaleY`.
- **Aims say where.** `Aim.scrollTo` is `scroll(to:anchor:)` and `Aim.moveToRegion` is `show(_:)`.
- **A color is a background.** Every background takes a color or a brush; `Brush.solidColor` is gone.
- **The application's surface names no host value.** Values only a host reads - a selection's mode, a corner's
  radii, a web view's source, a kept value's kind - leave what an application writes; every view slot is a builder,
  and every carried property takes a state.
- **Host authors.** An element wears tiers - `RangeElement`, `PopupElement`, `PressElement`, `ToggleElement`,
  `SubmitElement` and the others - and a member's key names its contract (`Text.maximumLines`). A state crosses to a
  control by its `StatePassage`. A head imports StateUI by name and starts its host by the host's name; Android's
  `Java.call` is generic over the answer it reads. The host layer fills in a range's unsaid ends, and each host's
  module stands recorded in `lib/StateUI/exports/api/`.

### New

- `.accessibilityPresence(_:)`, `SwipeDirections`, `WritingDirection`, `Menu.joins(_:)` to place a menu in the
  platform's, `ButtonRole.normal`, and the window's and session's own settings as bindings (`window.$title`,
  `$width`, `$height`, `application.$colorScheme`, `localization.$language`).

### Fixed

- Identity: no key holds a NUL, a value stands in one place under one provider, a rebuilt element's key stands once
  on its walk, and a host's tokens stand apart from an author's ids.
- Lists: a list shows the header it was last given, an item's value stands once, the end is told again as items come
  or go, and a collection's handlers run in the order written.
- Handlers: each composed handler has a gate of its own, a handler no longer written ends its runs, a run superseded
  in its first step is cancelled, and an aimed act begins on the control standing then.
- Text and locale: a language tag is read as BCP 47 writes it, every host tells the user's languages in order, a
  year or a number of any size round-trips through its text, and typed words are counted as they stand.
- Input: what began on a view ends as it is disabled, a gesture taken away stays away to its end, and on the Mac
  input meets a view where it is drawn and a flattened view takes none.
- Hosts: the keyboard is found in a sheet over a stack, a hidden element says nothing of its own, a drawing's pixels
  keep no view that left, an arc of any angle is drawn at once, a web view reloads its current source, and on WinUI
  a list's rows and a popover draw no line along their top.

### Tooling

- The test window acts as its user can and waits for the work an act began; a closed test window leaves no work
  behind.
- The VS Code extension, the scripts and the manifests name one floor, which `ToolchainTests` holds.

## 0.8.1 - 2026-11-02

### Breaking changes

- **The clock is the application's.** `ClockTime.now()` is `application.clock.now()`, the day
  `application.clock.today()`, and `TimeZoneInfo.utcOffset(of:on:)` is `application.clock.utcOffset(of:on:)`, its zone
  a `TimeZoneName`. The user's zone is `locale.timeZone`, a `TimeZoneName?`, nil until the host has said;
  `TimeZoneInfo` is gone. Host authors: `ApplicationContract.currentTimeZone` is gone, and `currentTime` answers year,
  month, day, hour, minute, second and millisecond; `ActToolkit.localTime()` answers a `LocalTime`.
- **An application registers itself.** Each head names its application with `NotesApp.register()` - the type is
  public, with a `public init()` the protocol now asks for; `registerApplication()` is gone. An act of the
  application's is `application.call(_:_:)`, awaited, or `application.tell(_:_:)`, not awaited; `stateUICall` and
  `stateUISend` are gone. `stateUIVersion()` is `application.info.libraryVersion`, and `stateUIPlatform()` is
  `device.info.platform` with `device.info.architecture`.
- **Every session stands in one phase.** `SessionPhase` - `.active`, `.inactive`, `.background` - is the
  application's, a scene's and a window's; `ApplicationPhase`, `ScenePhase` and `WindowPhase` are gone. A window's
  `.created`, `.activated`, `.deactivated`, `.stopped`, `.resumed` and `.destroying` read as `.inactive`, `.active`,
  `.inactive` and `.background`: save on `.background`. Host authors: `WindowContract.resumed` is gone.
- **A tap is a tap.** `Map.onMapClicked { }` is `Map.onLocationTapped { location in }`;
  `MotionLayout.onItemTapped { item in }` is `onItemActivated { id in }`, and `onItemDragged` and `onItemDismissed`
  hand the item's identity as a list's and a gallery's events do - `ItemDrag<ID>`'s `id` and `over`, its `speed` now
  `velocity`. Host authors: `MapContract.mapClicked` is `locationTapped`.
- **A gesture tells points.** `PanUpdate`'s `totalX` and `totalY`, `velocityX` and `velocityY` are `total` and
  `velocity`, each a `Point`, and `at` says where the press is now; `PinchUpdate.scaleOrigin` is `pivot`. A canvas
  hears a press as every view does: `Canvas.onPressed`, `.onDragged` and `.onReleased` are gone - `.onPointerPressed`,
  `.onPanUpdated`'s `at` and `.onPointerReleased` tell it, in the canvas's own points. Host authors:
  `CanvasContract.pressed`, `.dragged` and `.released` are gone; `ViewContract.panUpdated` carries where the press
  is, and `HeardInput.drag` takes `from:`, where the press began.
- **A conversion is written with its way back, in the source's type.** `$x.convert { … }.convertBack { … }` is
  `$x.convert { … } back: { … }`, or `convert(_:back:)`; `back` is `(Out) -> Value`, so a way back answering another
  type no longer compiles, and a way back that comes and goes is one call, `back: editing ? { … } : nil`.
  `.multi($a, $b).convert { … }.convertBack { … }` is `.multi($a, $b).convert(_:back:)`.
- **A scroller names its axes as a set.** `.orientation(.horizontal)` is `.axes(.horizontal)`, `.both` is `.all`
  and `.neither` is `[]` (`ScrollAxes`); `LayoutInput.Orientation` is `Orientation`. Host authors:
  `ScrollViewContract.orientation` is `axes`, its value bits.
- **One word names an address.** `WebView(_ address:)`, `.source(_ address:)` and `.source(html:baseAddress:)`, a
  navigation's `address`, `Link(_:address:)`, `share(address:)` and `share(text:address:)`. Host authors:
  `LinkContract.destination` is `address`, `WebViewSource.url` is `.address`, and `ApplicationContract.launchLink` is
  `launchAddress`.
- **A library error names its reason as a case:** `StateUIError` is `.notPerformed(act:reason:)`,
  `.unreadableAnswer(act:answered:declared:)`, `.aimOnNoView`, `.aimOnTwoViews`, `.noItem` or
  `.writesWhileBuilding`, and its `description` says the words; `StateUIError.message` and `StateUIError(message:)`
  are gone.
- **What the host has not said is nil.** `device.battery.chargeLevel` - also where no battery stands - and
  `device.display.width`, `height`, `density` and `refreshRate` are optional: no `-1` or `0` stands for a fact.
- **The user's language is a tag.** `locale.language` is a `LocaleTag?` - `locale.language?.region` is the region,
  `.identifier` the whole tag; `LocaleInfo.region` and `LocaleInfo.name` are gone.
- A list's parts are sections: `ItemsView(groups:)` is `ItemsView(sections:)`, and `scrollTo(_:inGroup:)` is
  `scrollTo(_:inSection:)`.
- `.bottomBar(edge:)` is `.bottomBar(scrollEdge:)`. Host authors: `BottomBarContract.edge` is `scrollEdge`.
- An event's handler takes no label: `accessibilityAction("Clear") { }`, `.onKeyPressed([.escape]) { }` - a list of
  keys - and `.onVisualStateChanged([.pressed]) { }`, a list of states; none hears every state.
- `.eased(length, curve)` is `.eased(length, curve: curve)`; `.followsLayout(.spring(response:damping:))` is
  `.followsLayout(response:damping:)`, on a view and on `LayoutBody`; `clipboard.text()` and `write(text:)` are
  `read()` and `write(_:)`; `Asks` is `Cadence`; `GalleryArrangement.default` is `.wheel`; `confirm`'s `accept:` and
  every question's `message:` may be left out. `State.get()` is gone - read `wrappedValue`.
- A marker's `.label(_:)` is `.title(_:)`, and a map's `.mapType(_:)` is `.type(_:)`, as a marker's is. Host authors:
  `MarkerContract.label` is `title`, and `MapContract.mapType` is `type`.
- A line is drawn between two points, `Line(from: Point(0, 0), to: Point(240, 0))`: `.x1`, `.y1`, `.x2` and `.y2`
  are `.from(_:)` and `.to(_:)`, each a `Point` or its state. Host authors: `LineContract.x1` to `y2` are `from` and
  `to`.
- An area is a rectangle: `.area(.absolute(Rect(16, 16, 120, 40)))`, `.proportional(Rect(0.5, 0, 0.5, 1))`.
- `Color(red:green:blue:alpha:)` is `Color(red:green:blue:opacity:)`, its opacity from 0 to 1 as everywhere else.
- `ProgressBar($done)` and `Spinner($loading)` take a state, as `Slider($v)` does.
- `.draggable(text:canDrag:onDragStarting:)` is `.dragText(_:)`, `.isDraggable(_:)` and `.onDragStarting { }`. Host
  authors: `ViewContract.canDrag` is `isDraggable`.
- An initializer names what its builder builds - `Group(content:)`, `GeometryReader(content:)`,
  `Canvas(drawing:)`, `StyleSheet(styles:)`, `ToolbarGroup(items:)`; a trailing closure reads as before.
- On Android `clipboard.read()` throws where the window is not in focus - the platform hands it nothing - in place
  of answering nil.
- Extension authors: `StyleBag` is `Styling`, and `StyleBase` and `StyleState` are `StyleScope.Whole` and
  `StyleScope.VisualState` - `extension Styling: MyControlProperties where Target == MyControl {}`. `StyleTarget`
  requires `static var nodeType: NodeType` in place of `init()`: an application's own control writes
  `extension RatingBar: StyleTarget { public static var nodeType: NodeType { RatingBarContract.nodeType } }`.
  `PersistentValue.init?(persisted:)` is `init?(persistentValue:)` - a kept value converts as `carried` and
  `init?(carried:)`, `propValue` and `init?(propValue:)` do.

### New

- [Extending StateUI](docs/interface/extending.md) adds an element, a value and the application's own acts and
  events - the second public surface, which the library's own controls are written with; the handbook names every
  public type.
- `ItemsView` and `MotionLayout` are style targets: `Style<ItemsView<String>>()`.
- A question's own buttons and the Mac's menu bar speak the user's language where the application names no words.
- [StateUI for VS Code](docs/editors/VSCode/README.md) is the extension's handbook page, and the extension carries
  it as its readme.

### Fixed

- A chain of conversions follows its first source, a way back no longer written goes, and a conversion nobody read
  lets its source go.
- Two items of an `ItemsView` that describe alike are two items, each keeping its identity as the order changes;
  only the same value twice is said.
- An id stays with the view it is written on, a list's included, whether its lifetime is written before it or
  after.
- A `TextField` or `SearchField` nothing sizes is at least twenty digits wide, its placeholder too, on every host.
- GTK, WinUI and the Web read the time zone again as the application comes back to the front, and WinUI the
  languages.
- A cell no grid has - a row or a column before the first, a span of none, an index past the grid - stands in the
  nearest one there is, said once.
- A task cancelled while it waits for a movement's `arrived()` stops waiting alone; the others hear the end.
- A motion layout hands no host a number that is not finite; a read through a part of an element gone answers the
  element as it last stood.
- A window for a value never stands without one; a link stands at its words' size.
- Pictures cost less memory on Apple's platforms: macOS keeps no bitmap of every size an SVG or a PDF was drawn at
  (the Gallery's footprint after its heaviest samples: 475 MB -> 178 MB), pictures nothing shows are kept within one
  budget of forty million pixels on macOS and iOS, and a picture still shown on iOS is not decoded again after
  memory pressure.
- A WinUI picture opens drawn once, at the size it shows at; a Web page's bar at its foot leaves with its page, and
  the Web relay answers every request once.

### Tooling

- The VS Code extension stands in `editors/VSCode`, `editors/` holding each editor's extension: it is built from a
  checkout by `cd editors/VSCode`, `npm ci` and `npm run package`. An extension installed before this release looks
  for its sources in `lib/StateUI.VSCode`, so it is built and installed once by hand. It restarts the Swift language
  server once more where the Swift extension's restart is refused while the server loads its packages - the first
  activation in a fresh clone failed so.
- The public API stands recorded in two files, `lib/StateUI/exports/api/StateUI.txt` - what an application writes -
  and `StateUI.extending.txt`, what an extension writes.
- A conformance case that pans, pinches or turns two fingers reads the gesture's speed off a still clock, the same on
  every machine; CI runs every Web conformance family.
- CONTRIBUTING says where a feature's pull request is finished: on its own branch where it allows edits by
  maintainers, else on a `feature/<issue>-<short-name>` branch.

## 0.8.0 - 2026-10-31

### Breaking changes

- **A state is lent whole, or its value is handed with an event.** Every member that takes a state takes a
  `Binding<Value>` made from a `@State`: `$name`, or `contact.$name` where a class declares `@State var name`.
  `$state.member` and `$state[i]` are a `StatePart`, which reads, writes and posts but which no member takes, and
  `Binding(get:set:)` is gone. A value that crosses to the host as it is - words, a switch, a number, a date, a
  time, a color - may instead be given as a plain value, the user's change heard in its event:
  `TextField(chore.title).onTextChanged { … }`, `CheckBox(todo.done).onToggled { … }`. A choice the library
  translates - a picker's item, a list's selection, a tab, a stack's pages, a sheet - takes the state alone. Move
  over: make the field a control edits a `@State` of a class, or hand its value and write the change back in the
  event. `@Environment` has no projected value - a provided object's field is `model.$field` - and
  `ApplicationSession.colorScheme` and `.accentColor` are states (`Picker(themes, selection:
  application.$colorScheme)`).
- **A split view shows its sidebar by a modifier.** `SplitView($showsSidebar, sidebar: …, detail: …)` is
  `SplitView(sidebar: …, detail: …).showsSidebar($showsSidebar)`; `flyoutBackground` is
  `sidebarOverlayBackground`.
- **A tab view is typed by its tab** (`TabView<Tab>`), and its `.selection(_:)` takes a state of that type.
- **A window kind names the value it opens for.** `WindowType<Value>` is declared in an extension -
  `extension WindowType where Value == Note { static let note = WindowType("note") }` - and
  `WindowGroup(.note, for: Note.self) { $note in … }` is `WindowGroup(.note) { $note in … }`.
- **A handler's policy stands alone.** `.onClicked(gate: .ignoreWhileRunning) { … }` is
  `.onClicked(.ignoreWhileRunning) { … }`; after an event's own arguments it is `policy:`
  (`.onTapped(count: 2, policy: .waitForPrevious)`); `.none` is `.runConcurrently`; and `gate:` takes only a shared
  `Gate(.ignoreWhileRunning)`, what was `Gatekeeper`.
- **The layout worked out from parameters is `MotionLayout`.** Move over by renaming:

  | Before | Now |
  |---|---|
  | `LayoutEngine` | `MotionLayout` |
  | `LayoutPhase` | `LayoutParameters` |
  | the generic parameter `Phase` | `Parameters` |
  | `LayoutPlaces`, `LayoutPlaces.limits` | `AxisValues`, `AxisValues.endpoints` |
  | the axis's `wraps:` | `periodic:` |
  | `LayoutInput.Axis` | `LayoutInput.Orientation` |
  | `ItemDragStart.across`, `.held` | `.perpendicular`, `.longPress` |

  A throw goes on by one law for the whole layout: `.throwMotion(_:)` replaces the `throwing:` argument of every
  `LayoutInput` (`.magnification(throwing:)` is gone), and a `GalleryView`'s `.throwing(_:)` is `.throwMotion(_:)`.
  A gallery's `onItemTapped { item in }` is `onItemActivated { id in }`, handed the card's identity.
- **A motion is compared, never read apart.** `Motion.law`, `.curve`, `.factor`, `.isInherited`, `.isCustom`,
  `.length` and `Motion.Law` are gone (`motion == .none`). A law given to `move(to:_:)` is that move's alone: a plain
  assignment after it travels on the value's own law. `Sync`, the `sync:` of `engine(following:)` and
  `engine(tracking:)`, and `EngineCycle.sync` are gone - an engine runs on the display's frame.
- **Several sources convert through `multi` alone.** `$a.convert(with: $b) { … }` is `.multi($a, $b).convert { … }`,
  and journeys alike.
- **Controls named for what they show.** `Spacer` is `Space` - it alone grows along a stack - and `Fill` takes the
  room it is offered; `ActivityIndicator` is `Spinner`; `PositionIndicator` is `PositionDots`, with `.dotColor`,
  `.currentDotColor`, `.dotSize`, `.dotShape` and `DotShape`; `Divider` is `Separator`. `RadioButton` and
  `groupName` are gone: a choice among few is `Picker(...).presentation(.radio)`, and `CheckBox` and `Switch` say
  their words with `.text(_:)`.
- **A side follows the direction.** `Insets`, `.margin` and `.padding` take `start:` and `end:` where they took
  `left:` and `right:`; `IconPosition.leading` and `.trailing` are `.start` and `.end`.
- **A layout names the edges it runs under.** `.avoidsSafeArea(...)` and `SafeArea` are gone:
  `.ignoresSafeArea(.top)` (`SafeAreaEdges`) runs a layout under the bars and the system's edges it names, and
  keeps it clear of the rest.
- **A toolbar's items are typed.** `ToolbarItem` is what every bar item is: `ToolbarButton`, `ToolbarToggle`,
  `ToolbarLabel` and `ToolbarGroup`. `.toolbar(.trailing, order: 1) { ToolbarItem("Save") }` is
  `.toolbar { ToolbarButton("Save") }`; an item says where it stands with `.placement(.sidebar, at: .end, order: 1)`,
  and `ToolbarSide` and `ToolbarItemPlacement` are gone. A page's `barTitle`, `barSubtitle` and `barIcon` are gone -
  a page names itself with `.title(_:)` and `.subtitle(_:)` - and `barBackgroundColor` is `barBackground`, a color
  or a material.
- **A checked menu entry is a `MenuToggle`**: `MenuItem("Wrap").isOn($wraps)` is `MenuToggle("Wrap", isOn: $wraps)`.
  `.isDestructive(true)` on a menu item or a toolbar button is `.role(.destructive)`. `Button(icon:)` is
  `Button().icon(_:)`, and a button's menu names its kind, `.menu(.split) { … }`. A toolbar button holds a menu as
  a button does, `.showsMenuArrow(_:)` included.
- **A sheet is presented by a view.** `ModalStack` is gone: `.sheet(isPresented: $shown) { … }` and
  `.sheet(item: $item) { item in … }` present a page the state asks for, and the user's dismissal writes `false` or
  `nil`.
- **The window asks; the application acts.** `Dialogs.alert`, `.confirm`, `.chooseAction`, `.prompt`, `.openFile`,
  `.openFiles` and `.saveFile`, `OnScreenKeyboard.hide()` and `Inspector.open/close/toggle/isOpen(in:)` are the
  window's (`@Environment(\.window)`: `window.confirm(...)`, `window.hideOnScreenKeyboard()`,
  `window.openInspector()`) and stand over that window. `Links.launch` and `ScreenReader.announce` are
  `application.launch` and `application.announce`. A choice of actions answers the value chosen:
  `window.chooseAction("Share via", among: Share.allCases, caption: …, destructive: .delete) -> Share?`, `nil` for its
  cancel; `confirm`'s `cancel:` may be left out, and `alert`'s button is `accept:`.
- **A kept key is typed by its value.** `PersistentKey("name", of: T.self)` is `PersistentKey<T>("name")`, declared as
  a static of `extension PersistentKey where Value == T`, and a state of another type does not compile; `SceneKey`
  alike, its value any `Codable`, kept as JSON text - a value an earlier version kept reads as none once.
  `application.persistentKeys` is gone.
- **Names say what a thing is.** `AppInfo` is `ApplicationInfo`; `device.info.deviceType` is
  `device.info.isVirtual: Bool?`; `device.honours(_:)` is `device.honors(_:)`; a catalog's languages are an
  `enum AppLanguage: LocaleTag, CaseIterable`, its associated type `CatalogLanguage`;
  `.automationExcludedWithChildren(_:)` is `.hidesChildrenFromAccessibility(_:)`.
- **Values are typed.** `Color("#512BD4")` is `Color(hex: 0x512BD4)`, `Color("#80FF0000")` is
  `Color(hex: 0xFF0000, opacity: 0.5)`, and a color from data is `Color(parsing:)`, `nil` for what is no color.
  `Rectangle(.red)` is `Rectangle().fill(.red)`, `Ellipse` and `Capsule` alike; `Image(light:dark:)` is
  `Image(ImageSource(light:dark:))`. `Map(latitude:longitude:radiusMeters:)` is
  `Map(region: MapRegion(center: Location(...), radiusMeters:))`, `Marker("Name").location(latitude:longitude:)` is
  `Marker(at: Location(...)).label("Name")`, and an aim moves a map with `moveToRegion(_:)`.
  `DatePicker.format("D")` is `.format(.long)` (`DateStyle`).
- **One road for each thing.** A scroller's offset is read with `.scrollOffset($offset)`; its `scrollXChanged` and
  `scrollYChanged` events are gone. An array of views is no longer a container's content: write the statements, or a
  `ForEach`. `onKeyPressed`'s handler takes a `KeyPress` (`press.key`, `press.modifiers`). `currentThreadNumber()`
  is gone - ask `MainActor.preconditionIsolated`.
- **A head starts the application in Swift.** `@_cdecl("stateui_app_register") public func stateui_app_register()`
  is `public func registerApplication()`, and `exit(StateUIGTK.run(...))` and `exit(StateUIWinUI.run())` are
  `StateUIGTK.run(...)` and `StateUIWinUI.run()`, which never return.
- **For host and backend authors (`@_spi(Host)`):** `Renderer` is the host's alone - an application tells every
  change by writing a state. `Prop("…")`, `Event("…")` and `Act("…")` are the host's; a member is reached through
  its contract. The motion layout is `MotionLayoutContract`, node type `"MotionLayout"`, its members `parameters`,
  `translationOrientation`, `translationUpdated`, `wheelStepped`, `itemDragUpdated` and `pinchRotationUpdated`;
  `ViewContract.layoutBody` is new. `ButtonContract.showsMenuArrow` is `ButtonMenuElementContract.showsMenuArrow`,
  which a toolbar button wears too. A registered control's `applies([a, b])` is `applies(a, b)`,
  `children(_:members:)` is `children(_:properties:events:)`, and an element reads a state handed to it when it is
  described. `CoreLink.readsKept { name, kind in … }` replaces `persistentKeys` and `restorePersistent`. The tier
  `TextStyleElement` is `TextColorElement`; `HostDeviceInfo` takes `isVirtual:`. A host's motion laws take and give
  speeds per second.

### New

- A two-way control - a field, a switch, a check box, a slider, a stepper, a date or time picker, a color picker -
  takes its value with an event of the user's change: `onTextChanged`, `onToggled`, `onValueChanged`,
  `onDateChanged`, `onTimeChanged`, `onColorChanged`. A picker tells the index chosen (`onSelectedIndexChanged`), a list its selection
  (`onSelectionChanged`).
- `.popover(isPresented:)` and `.popover(item:)` show the platform's popover by a view, a sheet on a phone. A sheet
  stands as a card on a wide screen, as large as its page asks, and its stack offers a close button
  (`.showsCloseButton(_:)`).
- A page stands a bar at its foot (`.bottomBar { … }`) and a toolbar there (`.toolbar(.bottom) { … }`); a page runs
  under its bars where it says so (`.ignoresSafeArea`). A bar says how rows show at its edge (`.barScrollEdge`), how
  its buttons stand (`.toolbarStyle`, `.toolbarSpacing`) and the color of their words (`.barForegroundColor`); its
  background may be a material. A split view's bar stands in two parts, and `.showsSidebarToggle(false)` hides its
  toggle.
- `Link` opens its address; `.onLinkOpened` hears the links of a view's window, a link of the application's own
  scheme included. `.onHeld` hears a press held on any view. `ColorPicker` opens the platform's own picker.
  `ToolbarToggle` is a setting on the bar, a toolbar button holds a menu (`.menu(_:_:)`), and a button's words may
  stand out of sight and still name it (`.showsText(false)`).
- `application.clipboard` writes and reads text; `window.share(text:link:)` offers the platform's share sheet;
  `application.send(HTTPRequest(...))` sends an HTTP request on every host.
- A scroller or a list is pulled to refresh: `.isRefreshing($refreshing)`, `.onRefreshRequested`,
  `.isRefreshEnabled`. A list item's `.contextMenu` is also its swipe actions on UIKit.
- `.accessibilityRole` and `.accessibilityValue` say what a view made of parts is and holds;
  `.accessibilityAction(_:perform:)` and `.onAccessibilityAdjusted` take a screen reader's actions and steps;
  `device.accessibility` reads less motion, more contrast, a running screen reader and the scale of words.
- `InputPurpose.username`, `.newPassword` and `.oneTimeCode` let the platform fill a sign-in in. Tab, Space, Home,
  End, Page Up and Page Down are keys. On Windows, GNOME and the Web an Edit menu (`.id(StandardMenu.edit)`) holds
  the platform's undo, clipboard and selection entries, as on the Mac and the iPad.
- `StateUITesting` drives an application's own pages in its tests as a user does, on every host's toolkit; the
  starter's test clicks its button.
- `DispatchQueue.main.async` runs on the UI thread on Android, Windows and Linux too.
- `Space`, `Fill`, and a figure filled with a material (`.fill(_:)` takes a `Material`). `Group` and `AnyView` hold a view with no
  element of their own.
- Words of other sizes rest on one baseline (`Alignment.firstBaseline`), a row can wrap onto further lines
  (`HStack { … }.wraps(true)`, `.rowSpacing`, `.lineAlignment`), a row short of room takes it from its words, and
  `.monospacedDigits` draws every digit at one width.
- An application gives its own accent (`application.accentColor`).
- A motion layout may mirror right to left (`.mirrorsRightToLeft(true)`); its views move as bodies
  (`.dynamics(_:)`, `.layoutBody(_:)`, `.followsLayout(_:)`), it tells once it rests (`.onSettled`), and an axis of
  keyframes alone needs no input. A gallery's cards may follow their places (`.itemBody(_:)`).
- `Motion.glide(longest:)` is a public motion law, setting out at its value's speed; `journey.reach(_:)` says where a
  motion would bring a value. Every gesture tells how fast it goes (`PanUpdate.velocityX`, `.velocityY`,
  `PinchUpdate.velocity`, `.onRotationUpdated`), and a dragged item knows what it is over.
- `.onHostEvent(event) { … }` hears a host event while its view stands, and a field takes an outline of its own
  (`.stroke`, `.shape`, `.lineWidth`).
- An application's own control raises the events of the tiers it wears (`reports.raise`).

### Fixed

- A tapped view presses as a button on every host, and a single tap is pressed as a button is; a press that traveled
  is no tap, a touch catching a moving or springing list presses no row, and a held finger's menu stays as it lifts.
- A placed opacity no longer wakes UIKit's focus system: with a hardware keyboard, a motion layout and the Home
  screen no longer jump once a second on the iPad.
- A drawn picture under a moving transform stands as pixels of the size it is shown at on AppKit, so a thrown or
  zoomed picture no longer stutters, and a box that did not change draws nothing anew.
- A tabbed view's tabs come back after a tab that is a stack, stand in the middle of their bar, and its bar moves at
  once on GTK.
- A traveling layout lays out at its destination, a button's words stand where it travels to, and a field keeps the
  keyboard as its row moves.
- A closed window's views are let go on every host; a UIKit bar button no longer outlives its element.
- On Android pages no longer slide through each other on a push, a list cuts its cells at its edges and reports where
  it stands, a view is never a pixel short, the window draws edge to edge, and a theme holds before Android 12.
- A grid draws its children in their order, a grid child spanning tracks asks its room of them, and a child's new
  words arrange its layout again.
- A UIKit list chooses many with taps; a GTK sheet fits its window; a WinUI bar's buttons stand as a toolbar's.

### Faster

- A ticker's tick rebuilds only the views that read its values, and sheets taken together go in one render.
- A motion layout moving alone arranges no child.

### Tooling

- The public API stands recorded in `lib/StateUI/exports/api/StateUI.txt`, held by the suite; every interface
  example in the handbook compiles, and a Gallery sample's listed code is the code that runs.
- An element a host keeps after it left is counted, and a closed window's views are proven let go.

## 0.7.1 - 2026-10-20

### Breaking changes

- **An identity is compared as the value it is.** `.id(_:)` and `ForEach`'s `id:` match an element by its value,
  not by its description: two values that describe themselves alike - two instances of one class - are two
  elements, and a route or a tab need not describe itself apart from the others. `Node.id` can no longer be set;
  a view takes its identity with `.id(_:)`.
- **For host and backend authors (`@_spi(Host)`):** AppKit and UIKit share one web view, one map and the
  system's facts from `StateUIApple` (`lib/StateUI/StateUI.Apple`). What two hosts decided alike is the host
  layer's, and each host asks it: a scroller's echo, a navigation path change, a run of taps, a hand over a
  layout, a slider's and a stepper's step, a list's estimate and its scroll to an item, a window's dialogs, the
  focus, a frame reader's following (`FrameFollowers.follow(_:of:reads:)`). A collection that learns its cells'
  nearness once a frame tells the cells together (`ItemsCells.hold(_:endingShowing:)`).

### New

- A registered control takes properties together: `applies([...]) { view, values in ... }` hands a view every
  property it names whenever one of them changes, each as its contract's type and whether it changed
  (`ControlValues`) - a web view its agent before its page.
- A member the running host does not realize is said once in Debug, with the reason its register gives:
  "Switch.tint is never realized on this host: AppKit draws it in the accent color the user chooses".
- A host writes its lines, and every complaint the application routes nowhere, where its platform's developers
  read: Apple's system log, WinUI's debugger output, GLib's log, logcat, the browser's console.

### Fixed

- Words held to some lines end with an ellipsis on every host.
- A navigation path change moves alike on every host: a push brings its last page in however many came, a pop
  moves back once, a replacement and reduced motion move nothing. On UIKit two pages no longer slide in at once.
- A page hears it goes when the tree closes its window, and when the user pops it, on every host.
- A question or a file dialog over a window the tree closes is answered as dismissed, and the next one asks.
- A text field's bound counts characters on every host, a question's field included; WinUI, Android and the Web
  counted UTF-16 units.
- A slider's keyboard step and a stepper's step follow one arithmetic on every host, and a fractional step lands
  on its decimals: 0.2 and a step of 0.1 make 0.3. AppKit's arrow keys moved a twentieth and Page Up to the end;
  Android's slider stepped a twentieth; UIKit's progress view took a value that is not a number.
- A label's and a field's start follows the layout's direction on AppKit and UIKit, not the script of their words.
- A vector picture stretched to its room is drawn at the room's own pixels on GTK and WinUI - on GTK it was
  covered and squeezed.
- Android and WinUI count a run of taps with the platform's own interval and distance.
- A scroll to an item glides there unless the user asks for less motion, on every host.
- On Android and WinUI a layout the toolkit narrows is placed before it is drawn, not a frame behind its width.
- A chosen item's band is the accent at a fifth on every host, and a map's search result is purple on the Web
  too.

### Faster

- A body is built only for what it read: a page whose body ends on a view with its own state is no longer built
  for that state. In the host layer's benchmark, scrolling 1000 rows builds some 1200 bodies, against 5500.
- A render that makes no element spells no identity as text.
- On the Web a change inside a child arranges none of its ancestors, and a list takes the cells the browser saw
  coming and going in one frame together, with one render. A fling of 20 000 points a second in Chrome keeps every
  frame on time, where the rows in view stood empty until the list stopped; a list's page opens in some 1.9 s in
  WebKit with no JIT, against 3.8 s, and with the JIT in some 160 ms, against 530. Measured on an M1 Max MacBook
  Pro.

### Tooling

- The host layer's benchmarks gate four gestures' work by counts in every run; a walk opens every Gallery sample
  and checks nothing it made stays alive; the Web modules hold their size budgets.

## 0.7.0 - 2026-10-19

### Breaking changes

- **Motion lengths are durations.** `.eased(400, .cubicOut)` is `.eased(.milliseconds(400), .cubicOut)`, and
  `.spring(response: 320)` is `.spring(response: .milliseconds(320))`.
- **A gate stands only where a handler awaits.** A handler with no `await` takes no `gate:` -
  `.onClicked { count += 1 }`; one that awaits names what a second event does while it runs -
  `.onClicked(gate: .ignoreWhileRunning) { try await save() }`.
- **A layout engine's axis is one declaration.** `.input(_:)`, `.snapTargets(_:)` and `.wraps` are gone:
  `.axis(input: .scroll(.horizontal), range: 0...2, snaps: .every(1))`, with `keyframes:` and `wraps:`
  where the axis has them.
- **`move(to:_:)` takes a law, never an optional one.** `$x.journey.move(to: 0)` moves under the value's own law
  and `$x.journey.move(to: 0, .none)` under no motion - which an optional law read as "none given", and animated.
- **`convertBack` hears the user's changes alone.** A value the application writes goes forward as written:
  `volume = 0.123` through a slider converting by hundredths stays 0.123 instead of coming back as 0.12.
- **A layout engine with no motion of its own moves under the application's** (`application.motion`), as every
  value a host carries does, rather than under `.standard`.
- **A GTK or a WinUI head exits with the status its host's run returns**: `exit(StateUIGTK.run(...))`, as the
  templates write it.
- **For host and backend authors (`@_spi(Host)`):** a host's register is written with the contracts' members -
  `.complete(SwitchContract.isOn)`, `.notPlanned(VisualElementContract.background, on: SliderContract.self,
  reason: ...)` - and names elements by their contracts (`byApplication: [MapContract.self]`), as does
  `HostRuntime.start(unrealized:)`; a misspelled name no longer compiles.

### New

- The layout engine: keyframes on an axis; a pan in every direction; two fingers move an axis by spreading and
  turning; a press dragged with ⌥ or Alt is two mirrored fingers; a wheel turned with Control is a pinch; the hand
  carries the view in front; a view can be taken by the hand. `GalleryView` stands its cards as a deck too.
- Every value modifier has its binding twin beside it.
- A split view tells whether its sidebar lies over the page.
- `StateUIFoundation`: the platform's C library behind one import (`exp`, `sin`), the same on every platform.
- `STATEUI_PROBE=1` times a runtime's stages, once a second; on the Web also what the page spends.

### Fixed

- Some 140 defects a module-by-module audit found, each with the test that would have caught it, in the core,
  the host layer, every host, the conformance runner and the tools. Among them: a carried view keeps its body's
  handlers; a state with no number no longer holds the frame clock awake; a replaced element keeps its engines;
  Android's acts outlive the activity they began in; GTK lets go of a page the stack takes away; the Web never
  runs a `javascript:` address; on UIKit a sheet and a question in one turn no longer lock the window.
- On an iPad a page beside a sliding sidebar narrows with it frame by frame, its layout placed in the frame that
  measured it; what a layout pass reports moves no animation on, on every host.
- On UIKit a scroller tied to `.scrollOffset($)` stretches past its edge as the user pulls it.
- On an iPhone a page turned to landscape and back hears its new room with the display already turned.
- A list scrolled to an item stands it where the anchor says once the rows around it are measured, on UIKit,
  AppKit, GTK and the Web - on an iPad it stood a point short; the user moving the list lets it go.
- A change that moves a list's rows - an item put first, one taken out - builds the items it brings into view in
  the same render, so the platform's collection measures them as it animates the change: on an iPhone the rows no
  longer jump above where they stood, and on AppKit they no longer settle a few points off once the animation
  ends. AppKit's list keeps its own header and footer through the animation.
- Rendering on the Web is several times cheaper. Measured in WebKit on an M1 Max MacBook Pro: with no JIT, as
  Safari runs WebAssembly on an iPad, a home screen's render at a new icon's place takes some 47 ms, against some
  213 ms, and a list of 1000 rows scrolls at some 41 frames a second, against 27. With the JIT both already kept 60
  frames a second; the same render takes some 4-5 ms, against 8-9, and the list's longest frame some 19 ms, against
  30-37.

### Conformance

- A wait that runs out fails its case, a case proves its own family's contract alone, and a case whose driver
  cannot read what it needs says so: some marks fell, to tell the truth.
- A wait - a session's, a driver's, a host test's - stops as what it waits for holds, rather than asking again to
  its bound.
