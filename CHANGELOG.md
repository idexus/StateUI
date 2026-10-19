# Changelog

What each release changes for an application and for a host, newest first. A breaking change says how to move
over. StateUI is before 1.0: a release may break what the one before it promised, and says so here.

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
- Rendering is several times cheaper without a JIT: a home screen's render at a new icon's place takes some 45 ms
  in Safari with no JIT, against some 210 ms, and a list of 1000 rows scrolls at 41-43 frames a second, against
  26-27.

### Conformance

- A wait that runs out fails its case, a case proves its own family's contract alone, and a case whose driver
  cannot read what it needs says so: some marks fell, to tell the truth.
