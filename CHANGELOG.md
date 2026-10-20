# Changelog

What each release changes for an application and for a host, newest first. A breaking change says how to move
over. StateUI is before 1.0: a release may break what the one before it promised, and says so here.

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
  "Switch.tint is never realized on this host: AppKit draws it in the accent colour the user chooses".
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
  `.axis(\.self, input: .scroll(.horizontal), range: 0...2, snaps: .every(1))`, with `keyframes:` and `wraps:`
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
  `HostRuntime.start(unrealized:)`; a misspelt name no longer compiles.

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
