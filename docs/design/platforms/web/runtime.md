# The Web runtime

The Web host is the runtime every host shares ([the runtime](../../host/runtime.md))
in a browser's page: the application, StateUI and the host are one WebAssembly
module, Swift compiled with the Swift SDK for WebAssembly, and a small
JavaScript relay beneath it calls the DOM. The host layer supplies the mounted
tree, the patch intake, the pump, the animator, the state channels and the
display cycle; the Web half supplies what only the page can - the display
frames, the DOM elements, the browser's layout, and the window.

## The Web runtime

`WebRenderer` holds the host layer's runtime (`HostRuntime`), which holds the
elements every runtime holds alike: the core link, the intake, the mounted
tree whose native halves are `WebElement`s, the pump, the animator and what
follows it, and the display cycle on the page's frame clock. It is the
runtime's `HostPresenter` - after a render it shows the window,
and after a frame's walk it says the page may have moved. An act the host does not perform yet
fails at once, so a handler awaiting it goes on.

## Starting

The page loads the module and calls its `_start`, which runs the head's
`main`: it names the application and calls `StateUIWeb.run(name:)`. The host
claims the page's one thread as the UI thread, hands the relay the two
functions the page calls it through, and starts in the order every host keeps
([starting](../../host/runtime.md#starting)): it tells the core what it
realizes and what the page stands on, hands it the values kept in the
browser's storage, brings back the scenes kept when the page was left
(`SceneKeeper`) - else connects the window launch opens - and runs the first
turn; then `main` returns. The module lives on with the page; from then on
the browser calls it, as the user acts and as the display draws.

While the module loads, the page shows the application's name in its
middle, a ring turning and a bar of how much of the module has come, read
as its bytes arrive against the length the server says. A server sending it
compressed says the compressed length, so the bar then shows no share until
the module is in. Full, it stays full while the browser compiles the module -
a bar that went back would read as loading undone. The first turn done, the
page fades it away.

## The relay

JavaScript/stateui-web.js loads the module and hands it two sets of functions:
the relay's, which the C header `CStateUIWeb.h` declares as the module's
imports, and the system interface, WASI, which a Swift program asks of its
machine. The relay keeps every DOM element Swift makes under a number, and
words cross as UTF-8 and their length in bytes. It decides nothing of
StateUI's: it makes, places and changes elements as Swift says, calls Swift
back when one hears an event, and keeps the keyboard's way through a strip of
tabs and a menu, and a field's focus under a pressed button, as the page's
own.

The page calls Swift through function pointers. The host hands the relay two
`@convention(c)` closures - one for a listener's number, one for a display
frame - and each arrives as its index in the module's function table, which
the page calls; the module exports no function of its own beside `_start`.
The table is exported only when the head links with `--export-table`, which
`StateUIHead` passes for a Web head.

Every call from the page ends with a turn: a listener's handler, or a display
frame, may leave jobs a resumed handler queued, a render a write asks for, or
acts. Then the host asks the core when the page is to call again
(`nextWake`) and hands the relay one timer for it, `wake_after`, which
replaces the one asked for before: at once where work is left, or when a
sleep comes due. One thread runs everything, and the browser's event loop is
its loop ([WebAssembly](../../core/concurrency.md#webassembly)).

Words read back - a field's value - are read in two steps: the relay encodes
them and answers their length, and Swift hands it a buffer of that length to
copy them into.

The relay answers WASI for a page that has no files: standard output and
error go to the console a line at a time, the clocks are the page's, random
bytes are the browser's, and the environment is the page address's `STATEUI_`
parameters - `?STATEUI_TALLY=1` - so the diagnostics a host reads from its
environment are read here as everywhere.

## The stack

A Web head links with an 8 MB stack, the main thread's on macOS and Linux,
placed first in memory with the data after it. WebAssembly's stack lies in
the module's linear memory, and the linker's default, 64 KB, is less than a
debug build's render needs: past its end it overwrites what lies beyond, and
the program fails later somewhere else - in the allocator, or at an
`unreachable`. Placed first, a stack that runs out leaves memory at once, and
the program stops where it overflowed.

## The environment

The page tells the core it stands in a browser, and on what: where its user
points by touch (`pointer: coarse`), a phone or a tablet by the screen's
smallest width, as the host layer decides it for every touch screen
(`FormFactor.touchScreen`); else a desktop. It tells too whether the user's
system is dark or light, and the accent the browser draws its own controls
in - the system's `AccentColor` where the browser knows one, else its own
blue; a change of the appearance renders the application again in the other,
the accent read again with it.

## One frame

`WebFrameClock` asks for the browser's display frames with
`requestAnimationFrame`, one at a time, while something holds it: each frame
runs the display cycle at the frame's time, and asks for the next while still
held. Its time is the page's monotonic clock in milliseconds.

## Acts

The acts every host performs are the host layer's (`HostActPerformer`); the
page answers what it is asked through `WebActToolkit`. The time of day is the
browser's `Date`, the local zone its `Intl` zone, and a zone's offset from UTC
the one the browser writes for it at noon on the day asked - a zone it does
not know has none, and the act fails. A word for a screen reader goes to one
polite live region of the page's, emptied first so the same words are told
again. The on-screen keyboard goes down with the focus of the field holding
it. The focus goes to an element's view, or the first in it that takes it.

A kept value stands in the browser's storage for the page's site, under the
application's name, in the host layer's text (`KeptValuesText`): read before
the first render, written whole as one changes. Where the browser keeps
nothing - a private window, storage turned off - the value lives as long as
the page. A scene's kept values stand beside them in the host layer's text of
the scenes (`SceneKeeper`, `KeptScenes`), written as they change and as the
scenes do: the page's next start brings its scene back with them, where
another host's next launch would.

A question for the user is the browser's modal dialog
([pages](pages.md#questions-for-the-user)), held by the acts' part of the
page until the user answers it: the host layer shows one at a time. An ItemsView's scroll to an item is
its own ([items](items.md#scrolling-to-an-item)).

## Files

A file dialog is the browser's own, waiting its turn among the questions
([files](../../host/runtime.md#files)). One that opens is a file input of
every kind's extensions, clicked while the user's press lets the page ask -
its `change` answers the files, its `cancel` none. A save takes its
contents first: where the browser has a save dialog (`showSaveFilePicker`)
it offers each kind under its caption with the act's name, writes the
contents where the user said and answers the file - none where they
cancelled; elsewhere the browser downloads the file under the act's name,
which no dialog answers, and the act answers the file at once. A chosen
file is kept by the relay under a number of its own - a `File`, or the
handle of the one saved - which is its address; the page holds it while it
runs, and reads it as the browser hands it.

A file or an address is launched in a window of the browser's own, opened at
once while the user's press lets the page open one - a file's sent there as
it is read; each answers whether the browser opened it, and an address with
no scheme opens nothing. On a page a test drives (`stateui.holdsFiles`) the
relay shows no dialog and opens no window: it holds the dialog for the test
to answer from its own files, by name, and records what it would open.

## Motion

A property travels on the page where its view presents it: the host layer's
surface (`TransitionSurface`) names what, element type by element type, and
each frame's value is written as the element's style like any other. A
window's place and size arrive at once - the browser keeps its window. Where
the user asks for less motion (`prefers-reduced-motion`), everything arrives
at once, as on every host.

## The window

The browser's window is one window: the first window element the tree holds is
shown in the page's whole room, a grid of one cell that the page's arrangement
fills, and the page the user sees names the browser's tab.

The window's phases are the page's, told to the host layer's lifecycle
(`ApplicationLifecycle`) as the browser tells them: the window is put away
while the page's tab hides - it stops, and resumes as the tab shows - and it
is in front while the page holds the keyboard; the browser leaving the page
ends it. The page tells what it stands as once as it starts, in a task of its
own, so the window hears it was made before it hears it is in front.

## The conformance run

The conformance suite runs in a browser, headless: its cases need the
browser's own layout, focus, dialogs and input, which the host's own tests in
Node have none of; the host's tests that run a host run in the browser too. The suite's program is a WebAssembly module of its own,
started by the same relay with its `suspends`: its `main` runs through
`WebAssembly.promising`, and the driver's imports that wait - a frame of the
page's, a question to the controller beside the browser - are
`WebAssembly.Suspending`, so a case written as one synchronous run sets itself
aside while the browser goes on, its events reaching Swift as they do on any
page. The controller drives the browser over its DevTools pipe: the user's
input is the browser's own - the mouse, the keys, typed words - and it reads
and writes the repository's files, the verdicts among them, which the page
cannot reach. A file dialog is the relay's, held on the test's page and
answered from the test's own files, what the page would launch is the relay's
record, a drag between views is the DOM's drag events the driver dispatches,
and a window's phases are the notices the driver gives - a member proven
through them is the host's own, ✓, whatever element the act is done on.

XCTest's own loop runs on Swift's cooperative executor and awaits MainActor
between its tests. Once a host runs, MainActor's executor is the UI thread's,
which only an entry of the page drains, so a task of the suite's own drains
it from the cooperative executor and lets the page go on a frame where nothing
waited; without it the cooperative executor finds nothing left to run after
the first test and ends the program.

A case's host is the page's one runtime, made anew in place of the one before
it, its frames at the case's test clock where it gives one: a clock wound by
hand takes no frame of the browser's.
