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
`%LOCALAPPDATA%\stateui` on Windows, or the folder `STATEUI_STATE` names -
shared by every `stateui` of every checkout. `flock` holds it on macOS and Linux, `LockFileEx` on Windows; the
system lets go of it when the holding process ends however it ends, so a crash
leaves no lock behind. A waiter tries again every quarter second, is told who
holds it as the holder wrote in `build.owner` beside it, and can be cancelled
while it waits.

## An application build

`stateui build` (`application/build`) reads the project, picks the
application - the one named, else the only one - and refuses before anything
runs what cannot be: a host whose row has not moved to the tool, an
application with no head for it, one naming no checkout. It resolves the
build's context, waits for the machine's permit, journals the operation, and
runs `swift build --product <Name><Host>` in the head's own package,
`Platforms/<Host>` - which enables the host's trait on the application - with
the target's triple and SDK: an AppKit head's only for an
architecture not the machine's own, a UIKit head's always - the simulator's
or the device's the build is for (destinations.md) - and an Android head's
Swift SDK and triple, built by the swift.org compiler of the SDK's release
(android-heads.md). A device's signing is
found before the compile, so a device no profile provisions is refused in a
second, not after the build; every
line SwiftPM writes goes to the journal and, as the operation's output, to
the client. A failed compile publishes nothing and says SwiftPM's last
lines. Then it asks SwiftPM where it laid the product (`--show-bin-path`),
assembles the host's artifact in staging and publishes it whole
(apple-bundles.md). `stateui package` (`application/package`) builds for
release unless told otherwise and lays the bundle, made anew, in its
`--output`, else `<workspace>/artifacts/<Name>/<Host>`; a UIKit package is
for the device or simulator `--device` names. A result names the bundle, the
program it starts by, and for a UIKit head the destination it was built for. `stateui run` builds,
then runs the program in the foreground, sharing the terminal, until it ends
or Ctrl+C stops it with everything it started; standard output keeps the
result alone, the build's words going to standard error. The run ends with
the program's status - one a signal ended as 128 and the signal, as a shell
says it - so a crash is never a success.

## A package

A package is laid, made anew, in a folder that stands empty or where a
package was laid before - the `.stateui-package` it holds names the head
laid there. A folder holding anything else is refused (`ALREADY_EXISTS`),
and so is the application's folder, its project's or its checkout's, or a
folder holding one of them (`INVALID_CONFIGURATION`): what stood there stays.
The folder is judged before the build, so a refused package costs no
build and leaves no half-laid folder, and again as the package is laid: what
came to stand in it while the build ran stays, and the package is refused.
Only a package's own folder is taken away; an empty one is kept and filled
(`PackageOutput`).

## The operation journal

A connection keeps its operations in memory; what stays is the project's
journal (`OperationJournal`): `<root>/.stateui/operations/<id>/` - the root a
workspace's folder, else the application's - with `operation.json` (schema
version 1: the operation, its kind, what was asked, its state, when it started
and ended, the failure) written as it opens and again as it ends, through a
file written beside and moved into place, and `output.log`, what its programs
said. `.stateui/` stands in every workspace's `.gitignore`, and an
application's standing alone. The journal keeps the newest 50: as one opens,
the records beyond them - by when they opened, then by id - go, but one still
running, or a folder whose record is not written yet, which another process
may be opening.

## An artifact published whole

What a build makes is an artifact (`ArtifactStore`): assembled in
`<application>/.build/stateui/staging/<operation>/`, then given its
`artifact.json` - schema version 1: its identifier `<host>-<context
key>-<configuration>`, the operation that made it, when, the application,
the host, configuration and architecture, the product, the programs it
starts by and how it is signed - and moved into
`.build/stateui/artifacts/<identifier>/` in place of the last, which waits
aside until the new one stands. A failed operation drops its staging and
never touches the last artifact, so nothing ever runs or packages what an
earlier build left after a later one failed. On Windows a folder's move is
asked again, every quarter second for up to 30 s, where the system refuses
it: a scanner reading a program just written holds it for a moment, and the
move is refused for as long.
