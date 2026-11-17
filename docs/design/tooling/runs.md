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
`<package>/stateui-debugger.sock`, which the `started` event names beside the
process; the build's result names the symbols (`symbols/<abi>`). A debugger
then selects the `remote-android` platform, connects to that socket and
attaches to the process. The run's stop is `am force-stop`, then the server
ended and the log's follower; the application ending by itself ends the run.
A cancelled run decides it was stopped by its cancel, not by asking the
device, whose own answer the cancel cuts short.

## On the Web

The page is served (web-heads.md) and opened in the browser the run names
- the system's own where none is named, none for `none` - what the run
hands the application each a parameter of the page's address,
`?STATEUI_TALLY=1`. The `started` event
names that address. The run lasts until it is stopped, which closes the
server; the browser and its tab are the user's.

