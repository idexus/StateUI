# Runs

`stateui run` (`application/run`) builds an application, starts it on its
destination and follows it until it ends. An AppKit head runs as the
program its build names, in the foreground of the terminal. A UIKit head is
installed on its simulator or device and started there, an Android head on
its device or emulator.

## The run is the session

A run is one operation from its build to its application's end: its output
events carry, after the build's lines, every line the application writes;
its `started` event says what started - the build, with its bundle and
destination, the application's process, and whether it waits, stopped, for
a debugger (`--debugger`, a debug build's only). A debugger attaches by
that event while the operation goes on. The operation ends when the
application ends, its result the launch and the exit status where the
platform says one - a simulator or a device does not, so it is absent.
Cancelling the operation - Ctrl+C in the terminal, a client's
`operation/cancel`, the client's connection closing - ends the application
and every process its launch started, and only then ends the operation.
Nothing a run started outlives it.

## What a run hands the application

A program of this machine - an AppKit, GTK or WinUI head - runs in the
tool's own environment. An application the run starts elsewhere - on a
simulator, a device, Android or a page - is handed each `STATEUI_` variable
of it, so a switch such as `STATEUI_TALLY=1` reaches the application on every
host
(`HandedEnvironment`). Each launch takes what is handed as it takes its
destination, so none can start an application without it, and gives it in
its platform's form, in the variables' order: a simulator's as `simctl`'s
`SIMCTL_CHILD_<name>`, a device's as `devicectl`'s
`--environment-variables`, Android's as extras, a page's as parameters of
its address.

## A desktop head

A desktop head - AppKit's, GTK's or WinUI's - run by `application/run` - on
its own machine, or on one another machine asks ([Work on another machine](service.md#work-on-another-machine))
- is started from the program its build names and followed until it ends, its
output told as it comes (`DesktopLaunch`); a GTK head is installed first and
a copy of it running stopped, as a GTK application is one instance. Cancelled,
the program is stopped with everything it started. A GTK head asked with
`gdb` runs under gdb ([Running](gtk-heads.md#running)), on whichever machine
runs it. A desktop head asked with `debugger` is held by the toolchain's
`lldb-dap` - found beside `swift` - listening on a free port of the loopback
(`--connection listen://127.0.0.1:<port>`), and `started` names the way once
the adapter says it listens (`Listening for:`) - told sooner, a debugger
connecting at once would find the port closed: the
editor's debugger connects to that adapter (`adapterPort`), which starts the
program as asked (`DebugDescriptors.adapter`); the port is held for a relay
while the run lasts ([A debugger relayed](service.md#a-debugger-relayed)). The terminal's
`stateui run` of a GTK or WinUI head takes this road too, ending as the head
ends, and so does one of an AppKit head on a Mac paired; an AppKit head of
this Mac the terminal runs itself, in the foreground, its program's input and
output the terminal's.

## On a simulator

The simulator is booted where it is not (`simctl bootstatus -b`) and the
Simulator brought to it; the bundle is installed, and `simctl launch
--terminate-running-process` starts the application - held with
`--wait-for-debugger` - what the run hands it in its environment, its two
streams written to `stdout.log` and `stderr.log` in the operation's journal
folder. `simctl launch` returns once the application started, saying its
process, which is one of this Mac's: the run reads both files as they grow and ends when that process
ends. Stopping it is `simctl terminate`. No `simctl` process stays behind
the run: a `simctl launch` following the console outlives the debug session
it served and holds the next launch for a debugger.

## On a device

The bundle is installed with `devicectl device install app`, and `devicectl
device process launch --console --terminate-existing` - with
`--start-stopped` for a debugger - starts it, what the run hands it in its
environment, and follows its console until it ends. In console mode `devicectl` does not say the process, so once it
says the application launched, the run finds it among the device's
processes (`devicectl device info processes`) by its program,
`<Product>.app/<Product>`. Stopping the run ends the application by that
process (`devicectl device process terminate --kill`), then `devicectl`.
A debugger reaches the process through the device: `device select <id>`,
`device process attach --pid <process>`, its symbols read from the bundle
the build published.

## On Android

The device or emulator is chosen before the build (destinations.md) - a
virtual device not running booted first - so the APK is built for its ABI.
`adb install -r` installs it, `am force-stop` ends a copy still running, and
`am start -W` starts the activity the APK's launcher opens, what the run
hands it as extras (`-e`). Its process comes
from `pidof`; its log, `logcat --pid` in the brief format, is the run's output
while the process stands. With `--debugger` the NDK's `lldb-server` for the
device's ABI is pushed, copied by `run-as` into the application's own folder
- a debug build allows it - renamed into place over one an earlier run left,
and started there listening on the abstract socket
`<package>/stateui-debugger.sock`; the build's result names the symbols
(`symbols/<abi>`), and the `started` event says how LLDB reaches the process
through that socket ([How a debugger reaches it](#how-a-debugger-reaches-it)). The run's stop is `am force-stop`, then the server
ended and the log's follower; the application ending by itself ends the run.
A cancelled run decides it was stopped by its cancel, not by asking the
device, whose own answer the cancel cuts short.

## On the Web

The page is served (web-heads.md) and opened in the browser the run names
- the system's own where none is named, none for `none` - what the run
hands the application each a parameter of the page's address,
`?STATEUI_TALLY=1`. The `started` event
names that address. Readied for a debugger, in a browser of Chromium's, the
page is opened by none, and the `started` event says how the browser's
debugger starts it there. In Safari the run opens it, at an address of its
own - `STATEUI_RUN`, the run's second, so Safari loads it anew rather than
bringing forward an earlier run's tab - and waits up to 30 s for the page
among those Safari's WebAssembly debugger offers: new since it opened, named
by the address's host (another site's tab, opened meanwhile, is not it).
LLDB lists them (`platform select webinspector-wasm`, `platform process
list`); a page appears only with Safari's feature flag *Experimental
WebAssembly Debugger* on, so none appearing, the run says to turn it on and
ends. The `started` event then names LLDB's way to it. The run lasts until it
is stopped, which closes the server; the browser and its tab are the user's.

## How a debugger reaches it

The tool says how a debugger reaches every application it readies
(`DebugDescriptor`, `DebugDescriptors`), and an editor only maps that to its
own debugger - VS Code's lldb-dap and JavaScript debugger, Xcode's scheme -
so none decides the way itself, and each gets the same one.

- **A program of this machine** - AppKit, WinUI, GTK - is readied by
  `application/prepare`: built, a GTK head installed and a copy of it running
  stopped; LLDB starts its program (`launch`) in the project's folder. A
  debugger that starts its program is its parent, which is what Ubuntu's
  ptrace scope permits.
- **A simulator's process** is one of this Mac's: LLDB attaches to it by its
  number, and kills it as the session ends.
- **A device's process** is reached through the device - `device select
  <id>`, `device process attach --pid <process>` - its symbols read from the
  bundle built (and its `Frameworks`) rather than copied back.
- **An Android head** is reached through the `lldb-server` in its sandbox:
  LLDB selects `remote-android`, connects to the socket on the device the
  address names, whichever others are attached, reads the libraries
  unstripped from the build's symbols, and attaches. It passes SIGSEGV and
  SIGBUS to the runtime, which raises them on purpose - its null and suspend
  checks - and follows no code the runtime's JIT compiles: announced method
  by method, each stopping the whole application, it froze the UI thread for
  seconds over USB.
- **A page** in a browser of Chromium's is started by the browser's
  debugger: the browser's program on the page's address, its sources read
  from the page's folder. Swift's lines come from the module's DWARF, which a
  debug build keeps ([The build](web-heads.md#the-build)) and VS Code's
  JavaScript debugger reads through WebAssembly DWARF Debugging, which the
  extension offers; that reader knows no Swift types, so the variables are
  WebAssembly's.
- **A page in Safari** is reached by LLDB through Safari's WebAssembly
  debugger: `platform select webinspector-wasm`, then `process attach --pid`
  the page's WebContent process, the session's end leaving the page. LLDB
  reads the module's DWARF from the page - attaching takes some 9 s for the
  Gallery's 56 MB - stops on lines of Swift and walks Swift's call stack into
  the library. Xcode's LLDB names each variable's Swift type but reads no
  WebAssembly local's value (`DW_OP_WASM_location`); the swift.org
  toolchain's reads the locals but makes its Swift types for the Mac, not
  for WebAssembly, so it resolves none.

The terminal's `stateui run --debugger` prints the LLDB commands that reach
the application as it starts.

