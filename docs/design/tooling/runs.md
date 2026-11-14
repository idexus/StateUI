# Runs

`stateui run` (`application/run`) builds an application, starts it on its
destination and follows it until it ends. An AppKit head runs as the
program its build names, in the foreground of the terminal. A UIKit head is
installed on its simulator or device and started there.

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

## On a simulator

The simulator is booted where it is not (`simctl bootstatus -b`) and the
Simulator brought to it; the bundle is installed, and `simctl launch
--terminate-running-process` starts the application - held with
`--wait-for-debugger` - its two streams written to `stdout.log` and
`stderr.log` in the operation's journal folder. `simctl launch` returns
once the application started, saying its process, which is one of this
Mac's: the run reads both files as they grow and ends when that process
ends. Stopping it is `simctl terminate`. No `simctl` process stays behind
the run: a `simctl launch` following the console outlives the debug session
it served and holds the next launch for a debugger.

## On a device

The bundle is installed with `devicectl device install app`, and `devicectl
device process launch --console --terminate-existing` - with
`--start-stopped` for a debugger - starts it and follows its console until
it ends. In console mode `devicectl` does not say the process, so once it
says the application launched, the run finds it among the device's
processes (`devicectl device info processes`) by its program,
`<Product>.app/<Product>`. Stopping the run ends the application by that
process (`devicectl device process terminate --kill`), then `devicectl`.
A debugger reaches the process through the device: `device select <id>`,
`device process attach --pid <process>`, its symbols read from the bundle
the build published.
