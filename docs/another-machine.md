# Working on another machine

A head is built and run on the machine whose host it is, and that need not be
the machine the project is on: a Linux machine runs a WinUI head on a Windows
PC of the network, a Windows machine an AppKit head on a Mac. The other machine
runs the `stateui` service; the project, paired with it once, copies itself
there, has that machine's own `stateui` build the head, starts it on its
desktop and fetches a package home - every request going through the tool's
connection.

## The other machine

The machine the head runs on needs what its host needs - [AppKit](hosts/appkit.md#requirements),
[WinUI](hosts/winui.md#requirements), [GTK](hosts/gtk.md#requirements) - its
user logged in to its desktop, and `stateui` of the same release as the
project's machine. Its service is laid to start with that user's session:

```bash
stateui service install --listen 0.0.0.0:7979
stateui service status
```

`status` says where it listens and the pairing code it shows: six digits,
good for ten minutes and one machine. On Windows `install` opens the port in
the firewall to the local subnet alone, which UAC asks once.

## Pairing the project

In the project, pair it with that machine by the code it shows, under a name
of your choice:

```bash
stateui remote add office 192.168.1.20:7979 --code 482913
stateui remote list
```

The machine is kept in the project's `.stateui/remotes.json` - its
workspace's, else its application's - out of git and readable by you alone;
`stateui remote remove office` forgets it. A Mac pairs with its own guest by
its name alone: `stateui guest pair --device "Windows 11"` ([Every host from
one Mac](every-host-from-a-mac.md)).

## For everyone on the project

A machine the whole team works on is declared in the project's manifest -
its workspace's `stateui-workspace.json`, else its `stateui.json` - by its
name, address and the identity its service answers for, which `stateui
service status` shows. No secret stands in it:

```bash
stateui remote declare office
```

Each clone then sees it in `stateui remote list`, and everyone pairs once by
its name alone, with the code it shows; a service answering for another
identity at that address is refused:

```bash
stateui remote add office --code 482913
```

## Running there

A machine paired is a device of the hosts it runs as its own program:
`stateui devices --host winui` lists it, `stateui version` names the host at
`remote` where this machine builds none of it, and it is named as any device:

```bash
stateui doctor --host winui --device office
stateui run --project apps/Notes --host winui --device office
stateui package --project apps/Notes --host winui --device office
```

`doctor` says whether its service answers, its `stateui`'s release, and what
that machine has of what the host needs. A run's output comes back as it is
written, and Ctrl+C stops the head there; a package is laid in the project's
`artifacts`. In VS Code the machine is chosen with **StateUI: Select Machine**
([The machine](editors/VSCode/README.md#the-machine)), and **StateUI: Debug**
holds the head there for `lldb-dap`, a breakpoint of this machine's sources
stopping it. From the terminal, `--debugger` says the LLDB commands:

```bash
stateui run --project apps/Notes --host gtk --device ubuntu-box --debugger
```

The debugger's bytes travel through the machine's service alone; no port of
its opens to the network.

## A device of another machine

A machine paired offers its devices too - a Mac its iPhones, iPads and
simulators, any machine its Android devices and browsers. `stateui devices`
lists them, each `on` its machine, and `--machine` names the machine whose
device `--device` names:

```bash
stateui devices --host uikit
stateui run --project apps/Notes --host uikit --machine studio --device "iPhone 18 Pro"
```

The machine builds the head and starts it on its device; the output comes
here. VS Code offers this machine's own devices; another machine's is run
from the terminal.

How a service admits a machine, carries a folder and is started with its
user's session: [The tool's service](design/tooling/service.md).
