# Projects

`stateui project describe` and `project/describe` say what a project holds:
its applications, the hosts each has a head for, its products and tests, and
the StateUI checkout each builds with. Every operation that builds, runs or
tests reads a project the same way.

## A project read

A project is the nearest folder, from the one named up, that is an
application or keeps applications in `apps/`: a StateUI checkout, a group of
applications beside their checkout, or one application alone. Inside an
application's folder the project is that application.

An application is a folder holding a `Package.swift` and at least one head: a
`main.swift` in `Platforms/<Host>`, or Android's Gradle build in
`Platforms/Android`. Its name is its folder's, which its products and heads
are named after; its id is its folder's path from the project's root, `.` for
the root itself, the same on every machine.

Each application's package is read by SwiftPM - `swift package describe` - all
of them at once: its products, its test targets, and its dependencies, where
the checkout it builds with stands. Nothing reads a manifest's text, so a
manifest written in any way SwiftPM accepts is read as SwiftPM reads it.

Paths come out as absolute file URIs, a folder's with no slash after its name.

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
