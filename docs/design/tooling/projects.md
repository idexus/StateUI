# Projects

`stateui project describe` and `project/describe` say what a project holds:
its applications, the hosts each has a head for, its products and tests, and
the StateUI checkout each builds with. Every operation that builds, runs or
tests reads a project the same way.

## A project read

A command's target is the nearest application up from the folder it is run in:
a folder holding a `Package.swift` and at least one head - a `main.swift` in
`Platforms/<Host>`, or Android's Gradle build in `Platforms/Android`. A
library's manifest or a host's test package is no target, though it has a
`Package.swift`. Outside any application, the target is the workspace - the
nearest `stateui-workspace.json` up - with every application it lists.

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

## A workspace

A workspace is a folder with a `stateui-workspace.json`: several applications,
in whatever folders they stand, and the StateUI checkout they build with.

```text
{
  "library" : { "path" : "StateUI" },
  "projects" : [ "apps/Notes", "clients/Mac" ],
  "schemaVersion" : 1,
  "startup" : "apps/Notes"
}
```

`projects` lists the applications - paths from the file, each read as an
application or refused - and nothing beneath the folder belongs to it
otherwise. `library` is the checkout new applications build with; `startup`
the application a build, a run or a package takes where none is named and
the workspace holds several - one `projects` lists, another refused - which
a project's description says as `startupUri`. The file is read whole: a
field the tool does not read, or another `schemaVersion`, is refused by its
place. The tool writes it the same every time - keys and projects sorted, a
line break at its end - so `stateui new` adds a project without rewriting the
rest. An application inside a workspace stands in it: its settings reach the
application too. The repository is a workspace of Gallery and HelloWorld.

The file is JSON: a user's static configuration that the tool reads and also
writes. A Swift description would be a program to compile and run before the
tool could read it, and one the tool could not safely rewrite.

## SwiftPM reads a package without a host

An application's manifest chooses its head by `STATEUI_HOST`: with
`appkit`, its package has an AppKit executable and depends on the host. A
description is of the application, not of one host's build, so SwiftPM reads
it with `STATEUI_HOST` taken out of its environment. A host a terminal set for
another purpose - or an editor's leftover - changes no description; the hosts
an application has come from its heads.

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
file's name and text, `helloworld` (the application identifier) in lower case.
The name is letters and digits starting with a letter - a Swift module, a
process and a folder all take it - and not the library's own. A folder already
holding files is refused and left as it was.

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

`stateui workspace library` makes another checkout or release the library: each
listed application's manifest names it by the path from the application - the
`.package(name: "StateUIRoot", path: ...)` line and the packages under it -
then the file does. Every manifest is read before any is written; one naming
its checkout in another form is refused by its file, and nothing changes. A
release replaces the workspace's clone only where the clone holds no changes of
its own.

The paths stay in each manifest because SwiftPM caches a manifest by its own
text: a manifest reading `stateui-workspace.json` would go on resolving the
checkout it read before. The workspace file declares the library; the tool
writes the manifests from it.

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
