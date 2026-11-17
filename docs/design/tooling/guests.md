# Guests

A guest is a virtual machine of this Mac: a Linux one is where a GTK head is
built and run from the Mac, a Windows one a WinUI head. Parallels Desktop
keeps them, and its command-line tool, `prlctl` - in the Pro and Business
editions - is how the tool reaches them.

## Listing them

`stateui devices --host gtk` (`winui`) on a Mac lists the guests of that
host's system as destinations of the kind `guest`, from `prlctl list --all
--info --json` (`ParallelsGuests`): each named as Parallels names it, its
system as Parallels' word for it (`ubuntu`, `win-11`), its architecture, and
its state (`running`, `suspended`, `stopped`) where a device says how it is
reached. Its identifier is Parallels' own, which no rename changes. A system
is read from that word: `win…` is Windows, a distribution's name is Linux,
anything else serves no host. Where Parallels is not installed, or its
edition has no `prlctl`, the list is empty.

What a guest shares of the Mac is read with it: each enabled shared folder by
name and the Mac's path it shares, and whether it shares every disk - the
folders the application and its checkout are reached through in the guest.
Whether Parallels Tools stand in it is read too, as `prlctl exec` and the
shared folders need them.

## The guest's own tool

The Mac's tool asks a guest's own `stateui` rather than driving its compiler:
a build of each platform is one implementation, the guest's. It starts the
guest's `stateui serve --stdio` through `prlctl exec <guest> --current-user`,
which carries standard input and output both ways on Linux and Windows, and
speaks the protocol an editor speaks ([The protocol](protocol.md)), one
connection a call (`ServedTool`): `initialize` offering this tool's API
versions, `initialized`, the method, then `shutdown`, `exit` and the end of
the guest's input. A query answers its result. An operation is followed by
its events - its progress and its programs' output told as the Mac's own,
cut into lines per stream - to its terminal state, and read whole with
`operation/get`: its result returned, its failure thrown as the guest's tool
said it, a refusal (`-32010`) as the error it carries. Cancelled on the Mac,
the operation is cancelled in the guest (`operation/cancel`); a connection
whose input ends cancels the guest's operations itself. No command line
carries quotes, which `prlctl exec` hands a guest's shell unreliably.

## Reaching a guest

The tool reaches a guest by its identifier, which no rename changes, through
`prlctl exec <guest> --current-user`: as its user, who must be logged in to
its desktop - Parallels runs nothing as a user who is not (`Unable to
authenticate the user`), and a head's window opens in that session. A job
Parallels loses before running anything (`PrlJob_GetResult`,
`PrlJob_GetRetCode`) is asked again, up to five times. On Windows a program
is named by its whole path, which `where.exe` gives: `prlctl exec` searches
no user's path there. A Linux guest's program runs with what its user's
login shell and desktop set and `prlctl exec` does not: the login shell's
search path - where swiftly puts Swift - and the session's display, bus,
runtime folder and session type, read from `systemctl --user
show-environment`.

What the tool lays in a guest stands under its user's home, `stateui-guest`
(`GuestPlaces`). A folder of the Mac is reached in the guest through the
nearest shared folder holding it - `/media/psf/<name>/…` on Linux,
`\\Mac\<name>\…` on Windows - else through every disk where the guest
shares them all, `AllFiles`.

## Laying the guest's tool

`stateui guest prepare --device <guest>` lays the stateui of the checkout the
project builds with in the guest (`GuestPreparation`), each step a program of
the guest's system: the checkout's `tools/StateUI.CLI` copied from the shared
folder into `stateui-guest/tool` - `rsync` on Linux, `robocopy` on Windows,
`.build` and `.swiftpm` left out - built for release by the guest's Swift, and
its program laid in `stateui-guest/bin` (on Windows with the libraries beside
it). The Mac's tool works with the guest's at the same API version.

A guest's stateui is laid again by the next work that needs it wherever it
does not answer, answers as another release, lacks a method the work asks, or
was laid from other sources than the checkout's `tools/StateUI.CLI` now
holds: the Mac remembers, guest by guest (`guests/<id>.tool` in the tool's
state folder), a fingerprint of every file's path and bytes there but what a
build makes. A tool of the same release built before a change would read a
field it does not know as nothing.

## The doctor of a guest

`stateui doctor --host gtk --device <guest>` (`toolchain/check` given a
`device`) checks a guest instead of the Mac, and changes nothing - it neither
starts the guest nor lays anything in it (`GuestDoctor`). It checks the way
to the guest from the Mac first: Parallels' `prlctl`, the guest by its name
and of the host's system, Parallels Tools in it, and each folder of the
project - its applications and their checkout - shared with it. Then, where
the guest runs: its user's desktop session, and its own stateui at the same
API version. Last it asks that stateui for its own findings - Swift, GTK's or
the Windows SDK's, a desktop session - in the same report. Every finding but
`prlctl`'s names the guest as its machine; a guest that does not run says so,
and what stands inside it waits until it runs.

## The copy in the guest

The application's project and the checkout it builds with are copied into
the guest before the guest builds, each under `stateui-guest` at its place
from the folder they share on the Mac - a project beside its checkout stays
beside it, so the manifests' paths between them hold; a project inside its
checkout is copied with it. The guest's stateui copies (`folder/mirror`,
`FolderMirror`) from the shared folder to its own disk: the files git tracks
and would track - `git ls-files --cached --others --exclude-standard`, so an
ignored file, a key among them, never reaches the guest - or every file where
no git work tree stands; a file copied where its size or time differs, the
source's time kept on it, one the source lost removed. What a machine makes
where it builds and indexes - `.build`, `.projection`, `.stateui`,
`.sourcekit-lsp`, `.swiftpm`, `.gradle`, `.vs`, `.git`, `node_modules` - is
neither copied nor removed, and a link is not followed.

## A head worked in a guest

`stateui build`, `package` and `run` of a GTK or WinUI head with a guest as
its device - on the command line or chosen in `stateui settings` - are the
guest's own stateui's work (`GuestWork`): the guest started (`prlctl start`)
or resumed (`prlctl resume`) where it does not run, its user's desktop
session waited for; its stateui laid again where it is not this checkout's
([Laying the guest's tool](#laying-the-guests-tool)); the project and its
checkout copied; then the request asked of it with the guest's path of the
application. A build answers the guest's artifact, its device the guest. A
package is laid in the Mac's output folder - the request's, else the
project's `artifacts/<Name>/<Host>` - which the guest writes through the
folder it shares, and answers the Mac's paths. A run is the guest's
`application/run`, its application's output told on the Mac as it comes;
cancelled on the Mac - Ctrl+C - the guest's operation is cancelled and its
end waited for, up to twenty seconds, before the connection closes, so the
application stops with it: a served tool torn down first would leave it
running.

## A host's suite in a guest

On a Mac, the GTK and WinUI hosts' own suites run in a guest the same way:
`stateui repo test --suite host:gtk` (`host:winui`) names its guest with
`--device` - refused without one - and the host's suite `tests/discover`
lists there runs on a device, the guest, as Android's runs on its phone. The
guest is reached and the checkout copied as for a head; then the guest's
stateui is asked for its own discovery of the host's suite in its copy, and
to run it (`tests/run`, its `filter` carried), every phase as the guest says
it. Its marks are held to the Mac's, never recorded there.

