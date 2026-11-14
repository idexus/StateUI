# Tests

A folder's tests are found and run by the tool (`tests/discover`,
`tests/run`; `stateui test list` and `stateui test run`), as one host or as
plain Swift; an editor shows what it found and runs what is picked through it.

## What a folder holds

`TestDiscovery` takes, in the order they are best run:

- the folder's own package, then the packages in `lib/` and `lib/StateUI/`,
  each with the `Testing` package standing inside it, then the folder's
  applications - each that is a Swift package with a test target;
- a package a host owns - its folder name ends with the host's name,
  `StateUI.AppKit`, `WebView.GTK`, or it is the `Testing` package of one -
  only for that host, and as that host's suite;
- for AppKit an application builds as an AppKit head; for every other host an
  application runs as plain Swift, its own head running only on its platform;
- for Android and UIKit, last, the host's suite that runs on a device -
  `lib/StateUI/StateUI.Android/Tests` on the device chosen,
  `lib/StateUI/StateUI.UIKit/Tests` on the simulator chosen.

A suite is named by its package's path from the folder, the folder's own name
for its root, and says whether it runs on a device (`onDevice`), so a client
asks for one only when such a suite runs.

## How one runs

`TestRunner` runs a package's tests with `swift test`, every `STATEUI_`
switch that records something taken away; an application built as an AppKit
head with `STATEUI_HOST=appkit` and its own scratch folder, `.build/appkit`,
so its plain build stays. A host's suite runs as `stateui repo test --suite
host:<host>` does, in the checkout the folder belongs to. The result is the
suite's phases, each passed or not, and the run's output its events.

The editor's Testing view holds each suite as an item, found again when the
host or the folders change; a run goes through the suites one after another
and does not stop at a failure - the point of running them all is to see all
of them.
