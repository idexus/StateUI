# Every host from one Mac

A Mac builds and runs four of StateUI's hosts itself - AppKit, UIKit, Android
and the Web. GTK is built on Linux and WinUI on Windows, and a Mac reaches
both through virtual machines of its own: a Linux guest and a Windows guest
of Parallels Desktop. The application stays on the Mac, in one project; the
`stateui` tool copies it into the guest, has the guest's own `stateui` build
it there, and starts the head on the guest's desktop, where its window opens.

## What the Mac needs

- **Parallels Desktop**, its Pro or Business edition: their command-line tool,
  `prlctl`, is how the `stateui` tool reaches a guest.
- **A Linux guest** for GTK and **a Windows 11 guest** for WinUI, of the Mac's
  own architecture - on Apple silicon, ARM64 - each with Parallels Tools
  installed, which Parallels offers when the guest first starts.
- **The StateUI checkout shared with each guest.** In the guest's
  configuration, *Options ▸ Sharing* shares the Mac's folders with it - the
  home folder, every disk, or folders chosen. The guest's own `stateui` is laid
  from the checkout there; the application itself travels to the guest through
  the tool's connection.
- **The guest's user logged in to its desktop.** Parallels runs a program in a
  guest only as a user who is, and a head's window opens on that desktop; an
  automatic login keeps it so after a restart.
- **Inside each guest, what its host needs**: [GTK host](hosts/gtk.md#requirements)
  in the Linux guest, [WinUI host](hosts/winui.md#requirements) in the Windows
  guest - Swift 6.4 first among them.

## Checking a guest

The guests stand as devices of their hosts:

```bash
stateui devices --host gtk
stateui devices --host winui
```

Each is listed by its name, its system and its state - running, suspended or
stopped. The doctor checks the Mac, then the way to a guest and what stands
in it, and changes nothing:

```bash
stateui doctor --host gtk --device Ubuntu
```

It checks Parallels' `prlctl`, the guest and its system, Parallels Tools, the
StateUI checkout shared with it, its user's desktop session, the guest's own
`stateui`, and then what that `stateui` finds inside: Swift, GTK, a desktop
session - each finding under the guest's name. The guest's `stateui` is laid
by the first build that needs it; to lay it at once:

```bash
stateui guest prepare --device Ubuntu
```

It copies the checkout's `tools/StateUI.CLI` into the guest, builds it with
the guest's Swift and lays the program under its user's home, in
`stateui-guest/bin`.

## Making an application

An application is made on the Mac, as on any machine - every host's head
with it:

```bash
stateui new Notes --directory apps
```

Nothing of it is made in the guest. Its project and checkout stay where they
are on the Mac, and each build in a guest copies them there first: the files
git tracks and would track, so an ignored file never reaches the guest, under
`stateui-guest` beside each other as they stand on the Mac.

## Running and packaging in a guest

A guest is the device of a GTK or WinUI run:

```bash
stateui run --project apps/Notes --host gtk --device Ubuntu
```

The guest is started or resumed where it does not run, the project copied,
and the head built and started in it; what the application prints follows in
the terminal, and Ctrl+C stops it in the guest. Chosen once, the host and the
guest are what a run takes when it names none:

```bash
stateui settings --project apps/Notes --host winui --device "Windows 11"
stateui run --project apps/Notes
```

A package is built in the guest and fetched to the Mac, into the project's
`artifacts/<application>/<platform>`:

```bash
stateui package --project apps/Notes --host winui --device "Windows 11"
```

## In VS Code

On a Mac, **StateUI: Select Host** offers GTK and WinUI beside the Mac's own
hosts, and while one of them is chosen the status bar shows the guest it is
built in - click it, or run **StateUI: Select Guest**
([The guest](editors/VSCode/README.md#the-guest)). **StateUI: Release** and
**StateUI: Debug** build and start the head in the guest, **StateUI Run**
follows it, and its notification stops it; **StateUI: Package** lays it in the
project's `artifacts`; **StateUI: Check Toolchain** checks the guest chosen
too. The editor works as the host chosen, so the application's code under
`#if GTK` or `#if WINUI` resolves on the Mac.

## A host's suite in a guest

In a StateUI checkout, the GTK and WinUI hosts' own suites run in a guest the
same way - the checkout copied, the suite run by the guest's `stateui`, every
verdict held to the marks recorded:

```bash
stateui repo test --suite host:gtk --device Ubuntu --filter GTKConformanceTests
```

**StateUI: Run Tests** in VS Code runs it in the guest chosen.

## What stays in the guest

The debugger does not reach a guest: **StateUI: Debug** runs the debug build
there without one, and says so. A host's conformance marks are recorded on
its own system - in the guest, from a checkout of its own. How the tool
reaches a guest, lays its `stateui` and copies a project:
[Guests](design/tooling/guests.md).
