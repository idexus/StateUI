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

