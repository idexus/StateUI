# Projects

`stateui project describe` and `project/describe` say what a project holds:
its applications, the hosts each has a head for, its products and tests, and
the StateUI checkout each builds with. Every operation that builds, runs or
tests reads a project the same way.

## A project read

A command's target is the nearest application up from the folder it is run in:
a folder holding its `stateui.json` beside its `Package.swift`. Its hosts are
its heads - a `main.swift` in `Platforms/<Host>`, or Android's Gradle build in
`Platforms/Android`. A library's manifest or a host's test package holds no
`stateui.json`, so it is no target. Outside any application, the target is the
workspace - the nearest `stateui-workspace.json` up - with every application it
lists.

An application's name is its folder's, which its products and heads are named
after; its id is its folder's path from the project's root, `.` for the root
itself, the same on every machine.

Each application's package is read by SwiftPM - `swift package describe` - all
of them at once: its products, its test targets, and its dependencies, where
the checkout it builds with stands. Nothing reads a manifest's text, so a
manifest written in any way SwiftPM accepts is read as SwiftPM reads it.

Paths come out as absolute file URIs, a folder's with no slash after its name.
A folder is climbed one parent at a time, each parent a strict ancestor - at a
root, or a Windows drive's, the climb ends.

## An application's file

`stateui.json` says what an application is on every platform, and makes its
folder an application:

```text
{
  "build" : 1,
  "identifier" : "pl.example.notes",
  "name" : "Notes",
  "schemaVersion" : 1,
  "version" : "1.0.0"
}
```

`identifier` names the application to every platform, `name` is the one shown
to its user - its folder's where the file gives none - `version` is the one
shown to its user, and `build` grows with every release of it. Each is one
every platform takes, checked as the file is read: the identifier two or more
parts joined by dots, each a letter, then letters and digits - Apple's bundle
identifiers take no `_`, Android's application ids no `-`; the version one to
three numbers joined by dots; the build a whole number from 1 to
2 100 000 000, Android's largest version code; a name not empty. The file is read whole, as the
workspace's is: a field missing, one the tool does not read, or another
`schemaVersion` is refused by its place. The tool writes it the same every
time - keys sorted, a line break at its end. An application in no workspace
may declare the machines it is worked on (`remotes`, [Machines a project
declares](service.md#machines-a-project-declares)).

The file stands beside the manifest, not in it: SwiftPM's description of a
package has no field for an application's identity, and nothing reads a
manifest's text.

## A head carries what the application is

An Apple bundle and an APK carry what the application is in the platform's own
record - `Info.plist`, the manifest - which the tool writes from its
`stateui.json`, and which the host reads back as it starts. WinUI's program,
standing in no package, GTK's, and a Web page keep none, so their head carries
the file itself: the tool lays it beside the program, or the page's
`index.html`, the name in it written - the folder's where the file gives none -
so a head never decides one. The host reads it as it starts, and what it
reports as the application's comes from there.

## A workspace

A workspace is a folder with a `stateui-workspace.json`: several applications,
in whatever folders they stand, and the StateUI checkout they build with.

```text
{
  "library" : { "path" : "StateUI" },
  "projects" : [ "apps/Notes", "clients/Mac" ],
  "schemaVersion" : 1
}
```

`projects` lists the applications - paths from the file, each a folder holding
its `stateui.json` or refused - and nothing beneath the folder belongs to it
otherwise. `library` is the checkout new applications build with. The file is
read whole: a field the tool does not read, or another `schemaVersion`, is
refused by its place. The tool writes it the same every time - keys and
projects sorted, a line break at its end - so `stateui new` adds a project
without rewriting the rest. An application inside a workspace stands in it.
`remotes` declares the machines the workspace's applications are worked on
([Machines a project declares](service.md#machines-a-project-declares)); an
application of a workspace declaring its own is refused.
The repository is a workspace of Gallery and HelloWorld.

The file is JSON: a user's static configuration that the tool reads and also
writes. A Swift description would be a program to compile and run before the
tool could read it, and one the tool could not safely rewrite.

## What was chosen

What one person chose on one machine stands apart from what the project is,
out of git, in the `.stateui/` the tool keeps its own state in beside its
journal (`.gitignore` leaves it out):

```text
<workspace>/.stateui/workspace-settings.json   { "schemaVersion" : 1, "startup" : "apps/Notes" }
<application>/.stateui/settings.json           { "devices" : { "uikit" : "iPhone 18 Pro" }, "host" : "uikit", "schemaVersion" : 1 }
```

The workspace's says the application a build, a run or a package takes where
none is named and the workspace lists several - one it lists, else refused -
which a project's description says as `startupUri`. The application's says
the host it is built for where none is named, and each host's device - a
simulator or device, an emulator, a browser - where none is named for it. No
file is nothing chosen: one application is itself, several are asked for by
name, and a build naming no host and finding none chosen is refused, saying
how to choose. Two names, because an application standing at its workspace's
root shares its `.stateui/`. Both are read as the project's files are - whole,
a device for no host refused - and written the same every time.

`stateui settings` (`settings/get`, `settings/set`) shows them and chooses: an
application to start, one its workspace lists; a host, one the application has
a head for; a device for a host - `settings/set` takes them by host, each
other host's kept, and `--device` is the host named's, else the chosen one's.
A device stands by its name, as a person reads and types it and the tool
takes it as it takes an id. The editor chooses through the same, works as the
chosen application's host, and reads them again as they change, so what a
terminal's `stateui run` takes is what the editor shows; a window holding no
application keeps its host and devices as its own.

## SwiftPM reads a package without a host

An application's own package declares no head: it is the application's
module and tests, with a trait per host, and each head is a package of its
own, `Platforms/<Host>`, which enables its host's trait on it. So a
description of the application is the same whatever is built, and the hosts
an application has are its heads' packages.

## A checkout

A StateUI checkout is a folder holding the library's `Package.swift`, its
heads' package (`lib/StateUI.Head`) and the starter (`apps/HelloWorld`) - a
clone of the repository or of a release. The checkout an application builds
with is the dependency SwiftPM resolves to one.

Its release is the library's own, `ApplicationInfo.libraryVersion`, the
release's one home. Where the checkout is a Git working tree, Git says the
commit it stands at and whether tracked files differ from it.

## A new application

`stateui new <Name>` makes HelloWorld of a checkout under another name, in the
working directory or the one named: every file of HelloWorld's but the hidden
- what its builds and editors left - copied, `HelloWorld` renamed in every
file's name and text, `helloworld` in lower case. Its `stateui.json` is its
own: the identifier `--identifier` gives - `com.example.<name>` where none is
given - at version 1.0.0, build 1; never HelloWorld's, which is StateUI's
release. Its heads are HelloWorld's, or those of the hosts `--platforms`
names alone (`appkit,web,winui`): an application's hosts are its heads, so
one meant for some platforms holds no head for another. The name is letters and digits starting with a letter - a Swift
module, a process and a folder all take it - and not the library's own. A
folder already holding files, or an identifier some platform refuses, is
refused and nothing is made.

The application is written beside its place, in a hidden folder, and moved
into it whole: a refusal or a failure leaves nothing behind. Its manifest names
the checkout by the path from the application, written from both folders' real
paths, as SwiftPM resolves them - `../..` in a checkout's own `apps/`, so moving
a whole workspace keeps every path. The checkout is the one named, else the
workspace's `library`, else the checkout the folder stands in; the workspace
lists the new application.

On macOS `URL.resolvingSymlinksInPath` leaves `/private` off a temporary
folder's path while SwiftPM keeps it, so a path from it would climb one folder
short; real paths come from `realpath` (`RealPath`). On Windows a checkout on
another drive than the application has no path from it: the manifest names it
whole, `D:/a/StateUI`.

## A new workspace

`stateui workspace create <name>` makes a workspace's folder - its name
letters, digits, dots, hyphens and underscores, as every build tool takes a
path - with its `stateui-workspace.json`, a `.gitignore` for what builds and
tools write, and the library: a checkout on this machine, named by the path
from the workspace, or a release cloned into the workspace's `StateUI/`, which
Git then leaves out. Like an application, it is written beside its place and
moved into it whole. A first application made with it is listed at once.

## A library changed

An application decides the StateUI it builds with in its own manifest - the
`.package(name: "StateUIRoot", path: ...)` line and the packages under it -
and the tool reads it from there, so an application needs no workspace.
`stateui project library` (`project/useLibrary`) makes another StateUI the
library of its target, as every command reads one: in an application, a
checkout its manifest names from then on, by the path from it; in a
workspace, a checkout or a release cloned into its `StateUI/`, which each
listed application's manifest names, then the workspace's file. A release is a
workspace's alone - its clone serves every application listed - so an
application asking for one is refused. Every manifest is read before any is
written; one naming its checkout in another form is refused by its file, and
nothing changes. A release replaces the workspace's clone only where the clone
holds no changes of its own.

The paths stay in each manifest because SwiftPM caches a manifest by its own
text: a manifest reading a path from another file would go on resolving the
checkout it read before. The workspace file declares the library its new
applications take; the tool writes the manifests from it.

## A name checked

`name/check` answers, before anything is made, whether a name can name an
application or a workspace in a folder: by its rule first - the one each maker
refuses by - then by the folder it would take, refused where it holds files or
is a file, taken where it is empty or absent. An editor asks it as a name is
typed, so each rule stands once, in the tool; the makers refuse the same way
when the folder changed in between.

## A release

A release is a tag of three numbers on StateUI's repository - `stateui releases
list` reads them with `git ls-remote`, newest first - cloned at its tag with its
tree alone. The tool builds with 0.5.0 and newer: the first release whose
checkout holds the library's heads and HelloWorld. An older one is refused
before anything is cloned. A release is cloned, not named by URL, since SwiftPM
cannot depend on a package in a subfolder of a remote repository, as a head's
host and the testing package stand.
