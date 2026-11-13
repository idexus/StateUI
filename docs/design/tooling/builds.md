# Builds

How the tool builds an application: what one build is, where it writes, how
builds on one machine wait for each other, and what the tool keeps of each
operation.

## A build's context

A build is an application's product for a host and an architecture, compiled
by one compiler against one platform SDK and one StateUI checkout
(`BuildContext`). Its SwiftPM scratch folder is
`<application>/.build/<host>/<architecture>-<key>`, the key twelve hex digits
of FNV-1a over the compiler's own name of itself (`swift --version`'s first
line), the SDK and the checkout's real path. The same build writes the same
folder on every run and machine; another compiler, SDK, checkout or
architecture writes another, so a new toolchain never meets modules an older
one compiled. The configuration is not in the key: SwiftPM keeps debug and
release apart inside one scratch folder, and a folder each would compile every
dependency twice. Source contents and the checkout's revision are not in it
either - a commit to the library keeps the incremental build. A result names
the paths its build wrote; no client spells them.

## One application build at a time

Two application builds at once rewrite the same Swift object folders and can
run stale output, so a machine builds one application at a time
(`BuildPermit`): a lock the system holds on `build.lock` in the user's state
folder - `~/Library/Application Support/stateui` on macOS,
`$XDG_STATE_HOME/stateui` (else `~/.local/state/stateui`) on Linux,
`%LOCALAPPDATA%\stateui` on Windows - shared by every `stateui` of every
checkout. `flock` holds it on macOS and Linux, `LockFileEx` on Windows; the
system lets go of it when the holding process ends however it ends, so a crash
leaves no lock behind. A waiter tries again every quarter second, is told who
holds it as the holder wrote in `build.owner` beside it, and can be cancelled
while it waits.

## The operation journal

A connection keeps its operations in memory; what stays is the project's
journal (`OperationJournal`): `<root>/.stateui/operations/<id>/` - the root a
workspace's folder, else the application's - with `operation.json` (schema
version 1: the operation, its kind, what was asked, its state, when it started
and ended, the failure) written as it opens and again as it ends, through a
file written beside and moved into place, and `output.log`, what its programs
said. `.stateui/` stands in every workspace's `.gitignore`.
