# Inspector

The inspector shows what every render costs and what it builds, inside the
application it measures. The record is `Inspection.swift`'s;
the views here show it.

## What it shows

An application offers the inspector in one line: `ToolbarItem.inspector(window)`
in a page's toolbar items, `InspectorButton()` anywhere a view goes, or, for a
scene that may show it in a window of its own,
`Window(.debugInspector) { DebugInspector() }`.

Each render is listed as it happens: what caused it, which road it took, how
long describing it took in Swift and applying it took in the host, in
microseconds, and how many composed views it built and carried. A chosen
render shows its tree - every composed view it reached, built with the reason
it could not be carried, carried whole, or walked past on the way to one below
it - with each one's time, its own and with what is under it. Its Complaints,
one action away, list what the library said (core/diagnostics.md), newest
first: a complaint comes on any thread, and tells the inspectors on theirs,
as a landed render does.

```text
  InspectorModel (one, shared)       places, folded, paused, revision, selected, complaints shown
        │ revision moves at most once per pace
        ▼
  Node.overlay(inspector:of:) ──▶ InspectorPanel   docked in the window whose ⓘ was pressed
  DebugInspector ──page──▶ InspectorPage                        in a window of its own
        │
        ▼
  InspectorView: head (actions) · summary line · list of renders · chosen render's tree
                 · or the complaints said
```

## Each scene has its own

Every scene has its own inspector, showing the renders that reached that scene:
the ⓘ is handed its window, whose scene's inspector it opens. It opens along
the bottom of the window its ⓘ is in, folded to one line - the last render
that reached the scene -
leaving the page all but uncovered while it is watched, with two buttons at the
end of the line to open it out and to close it. Opened out, it docks down the
side on a desktop or a tablet, or shows in the scene's `DebugInspector` window
where the scene declares one and the platform opens windows: a window of the
scene like any other, closed with it, hidden with it where its `Window` says so,
and restored with it.

## Where it docks

A docked inspector is the overlay of the window its ⓘ was pressed in: where
it docks - its place and that window - is a value of the scene
(`dockedInspector`), written whenever it docks, moves or leaves; every window
of the scene reads it, so they build again then, and the one it docks in lays
the panel after every overlay a page declares - over all of them. The ⓘ of
another window of the scene moves it there, open; pressed where it stands, it
closes it. Where the window it docks in closes, it stands in the scene's
first. The
panel is a layout that takes no touches of its own, laid over the whole
window: a touch anywhere the panel is not goes through to the page under it,
so the application can be used while it is watched. A panel at the side starts under
the page's bar, keeping the page's own buttons - its ⓘ among them - in reach. The buttons at the end of the bottom line are
drawn rather than typed, because a font without the glyph draws an empty box.

## Its own cost

The inspector is a tree like any other, described by this library and applied
by the host, so it is careful about its own cost. Its views are muted in the
record, and a render its own state caused is not kept: every state it has lives
in one model, whose storages the record knows as the inspector's own, so a
pass whose causes are all among them is the inspector drawing itself. It is
built again at most once per `Inspector.pace` milliseconds however fast the
application renders. Nothing is recorded while every inspector is closed or
paused, so an application that offers one costs nothing until somebody looks.
