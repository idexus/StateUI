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
suite runs this way (`appkit.yml`); every other host's moves with its row.
