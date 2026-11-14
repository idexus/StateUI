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
application, so it waits for the machine's one application build. AppKit's,
UIKit's, Android's, GTK's and the Web's suites run this way (`appkit.yml`,
`uikit.yml`, `android.yml`, `gtk.yml`, `web.yml`); WinUI's moves with its
row.

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

## The Android host's suite

A view exists only in an application's process, so Android's tests are a
test APK, `lib/StateUI/StateUI.Android/Tests`, run by its instrumentation.
Before anything is built, every `func test` must stand in its file's
`allTests` and every case in the runner's list: one no list names would
never run, and the suite refuses to start. `--suite host:android` builds the
test APK for the device's ABI - an Android head (android-heads.md) - installs
it on the device or emulator `--device` names (a virtual device not running
booted first), clears the verdicts an earlier run left, keeps the screen on
for the run - a phone whose screen goes off freezes the tests - and puts the
setting back after, as it was. The device's log says each test as it ends;
`am instrument` says `Executed N tests, with M failures`, which decides the
tests' phase, and a failure is followed by what the system did to the tests'
window. `--filter` is handed to the runner and stops the run there: a part
of the suite proves only part of what the host declares; a filter that
matched no test fails, as it does on UIKit - a run of none proves nothing. Unfiltered, what
the host declares (`files/android.txt`) and every family's verdicts
(`files/marks/android`) are taken off the device and held to
`lib/StateUI/exports/android.txt` and `exports/marks/android` - verdict by
verdict, whatever revision each stood at - and the facade the build made is
held to its API record for the ABI's triple and the Swift SDK.

The pictures are drawn on a Mac, while a Linux machine runs emulators well:
`--build-only --architecture x86_64` builds the test APK alone into a folder
with its identity (`suite.json`: the suite, the architecture, the checkout's
commit, the Swift SDK) and says the folder; `--artifact <folder>` runs that
APK instead of building one, and refuses it where it was built for another
suite or ABI, or from another commit than the checkout's.

## The WinUI host's suite

`--suite host:winui` runs on Windows. The projection is made first where a
pin changed ([WinUI heads](winui-heads.md#the-projection)). Unfiltered, the
foundation's own tests run first - the branches no other machine runs; then
`lib/StateUI/StateUI.WinUI/Testing` is built, its test runner made
self-contained as an application is - the Windows App SDK's runtime, a
manifest naming its classes, `resources.pri`, what the backends among the
package's dependencies declare - and its tests run, every test in a process
of its own: WinUI keeps the GDI objects of every window a test closes, and a
process holds only so many. The conformance families - some fifteen minutes
- run only where `--filter` names them (`WinUIConformanceTests`, or one of
its tests); then `StateUIWinUI` and `StateUIWebViewWinUI` are held to their
API records, their C modules found by their module maps.

## The GTK host's suite

`--suite host:gtk` runs on Linux, on the display the session gives it, as a
user who chose the accent (`ADW_DEBUG_ACCENT_COLOR=blue`, as GNOME's from 47
on), so every machine meets one desktop. Unfiltered, the foundation's own
tests run first - the C library's Glibc branches, which no other machine
runs; then the host's `Testing` package, every conformance family held to
its marks; then `StateUIGTK` and `StateUIWebViewGTK`, as that build made
them, held to their API records, their C modules found by their module maps
and `pkg-config --cflags libadwaita-1 libsoup-3.0 webkitgtk-6.0`.

## The Web host's suite

`--suite host:web` builds `lib/StateUI/StateUI.Web/Testing` for WebAssembly
with the Swift SDK of the compiler's release - the tests' archive made anew,
since it only gains members and one of a source since gone would link twice
- and holds the facade to its API record for `wasm32-unknown-wasip1`. The
host's own tests run in Node over a page with just enough of a DOM, through
the host's relay; the conformance families and the host's tests that run a
host - their classes listed in `WebSuite`, each needing a browser's layout,
focus, dialogs and input - run headless in Google Chrome or Chromium (or the
browser `STATEUI_BROWSER` names), each in a program of its own. `--filter`
names a class, a class's test, or a conformance family, which then runs
where it belongs.

## The Web modules' sizes

`--suite sizes:web` builds each application's Web head for release and
holds its module, gzipped at level 9 - what a page downloads - within the
application's budget (`WebSizes`): past it fails; a twentieth or more under
it is said, for the budget to come down with it. A budget is raised only in
the change that grows the module, with the reason.

## A family's revision

The revision a family's verdicts on a host stand at, and whether its recorded
files stand there, has one reader: the library's `HostVerdict` (its
`revision(of:on:in:)` and `standing(of:family:on:in:)`, over
`lib/StateUI/StateUI.Conformance/revisions.txt`). The tool links no StateUI
runtime, so it asks the conformance package's helper,
`stateui-conformance-metadata --repository <checkout> --host <host> --format
json`, built with SwiftPM: every family of `Families`, the revision it is to
stand at, the files recorded for it - `<Family>.txt`, else its parts
`<Family>-1.txt` on - with the revision each names, and whether they are
fresh, stale, missing or unreadable (`ConformanceMetadata`). `stateui repo
conformance status [--host <host>]` says it, family by family. Which family
a host realizes is its register's to say, never a revision's.

## A conformance run

`stateui repo conformance run --host <host>` runs a host's conformance
families whole - exactly one of `--changed`, the families whose verdicts
stand at another revision or at none; `--family <name>`, one option a family;
`--all` - through the host's suite, a test and every part of each family
(`ConformanceRun`). A filter that runs no test fails: a run of none proves
nothing. The verdicts are held to `lib/StateUI/exports/marks/<host>`, and the
control dictionary and the platform contract to them (`ControlDictionaryTests`);
`--record` writes the verdicts instead - `STATEUI_UPDATE_EXPORTS=1` handed to
the host's driver, the UIKit test application included - and renders the
documents (`STATEUI_UPDATE_DOCS=1`), each a phase of its own. An API record is
never written by a conformance run: its phases hold.

A driver that reads the repository tells the stale families itself
(`STATEUI_STALE_ONLY=1`). Android's device reads none: the tool names the
stale families from the helper ([A family's revision](#a-familys-revision)),
and writes each verdict file it takes off the device under the revision the
helper gives its family. On UIKit and Android a family's name selects the
tests whose names hold it, so `Button` takes `ButtonMenu` along: a family
more, whole, never one less.

## The API records

`stateui repo api check` holds the library's public surfaces - what an
application writes and what an extension writes - to
`lib/StateUI/exports/api` through the root package's `APISurfaceTests`;
`stateui repo api record` writes them (`STATEUI_UPDATE_EXPORTS=1`). With
`--host <host>` the host's suite runs - its build is what the records are
read from - and its API phase alone records: the facade's, its backends' and
`StateUITesting`'s. A suite's tests and a conformance run never write an API
record: the variables that record are taken from an API phase unless it is
asked to.

## The handbook's own outputs

Some of the handbook is written by the repository's own tests, and the tool
runs them, never a second writer (`Handbook`). `stateui repo docs check`
holds `docs/controls` and `docs/platform-contract.md` to the marks
(`ControlDictionaryTests`); `update` renders them (`STATEUI_UPDATE_DOCS=1`) -
a conformance run's last phase is the same. `stateui repo samples check`
holds the Gallery's listings and the handbook's to the code they are cut from,
every sample's review to its sources and every listing to compiling
(`SampleListingsTests`, `SampleReviewTests`, `SampleCodeTests`); `update`
writes the listings and records the review (`STATEUI_UPDATE_SAMPLES=1`) - the
act that says each changed sample's notes and its listings' comments were
read against the change, which the tool does not do for the reader.

