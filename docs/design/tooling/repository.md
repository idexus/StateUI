# The repository's own work

`stateui repo` works on a StateUI checkout itself - the one holding the
working directory - through the packages and tests that own each rule; it
reimplements none of them.

## A host's suite

`stateui repo test --suite host:<host>` runs a host's own suite as the host's
CI runs it: `swift test` of the host's package - its tests, and every
conformance family held to the marks recorded for it - then the host's
facade and `StateUITesting` held to their API records by the core's
`APISurfaceTests`, each told its module and the folder the host's build laid
the modules in. Each is a phase of the result, so tests that pass beside an
API that differs read as what they are, and the command fails if any phase
did. Nothing is written: `STATEUI_UPDATE_EXPORTS`, `STATEUI_UPDATE_DOCS`,
`STATEUI_STALE_ONLY` and `STATEUI_FILTER` are taken out of what the suite
inherits - recording marks and exports is a request of its own (the
migration's M11), never a variable left in a shell. The suite builds a test
application, so it waits for the machine's one application build. AppKit's
and UIKit's suites run this way (`appkit.yml`, `uikit.yml`); every other
host's moves with its row.

## The UIKit host's suite

A view stands in a window scene only in an application's process, so
UIKit's tests are an application of their own,
`lib/StateUI/StateUI.UIKit/Tests`, its identifier in its own
`Platforms/UIKit/Info.plist`. `--suite host:uikit` runs it on the simulator
`--device` names - the booted one, else an iPhone; a device is refused. The
simulator's application accessibility is turned on first, so UIKit's
accessibility answers for its controls as for a VoiceOver user, whatever ran
before. The application is built for the simulator's triple and SDK against
the simulator platform's own XCTest, read where it stands, bundled and
signed as any UIKit head (apple-bundles.md), and started as a run starts one
(runs.md) - `--filter` handed to it as `STATEUI_FILTER` - its output followed
until it ends with `Executed N tests, with M failures`, which decides the
tests' phase. Then `StateUIUIKit` and `StateUITesting`, as that build made
them, are held to their API records for the simulator's triple and SDK.
