# Scenes

Which scenes are open is the library's to hold, never the author's: the
platform makes them - at launch, for a new window, when the system restores the
application's windows - and `ApplicationSession.openScene()` asks for one more.
`Scenes` (Core/Scenes.swift) keeps them as state the root of the tree reads.

## The scene tree

```text
  Application
    Scene "1"            one per open scene, in the order they opened
      Window "main"      its main window, always first
      Window "fonts 1"   a window of a group: the kind, and a number of its own
    Scene "2"
      Window "main"
```

The application is the root and its scenes an arranged list: one for most
applications, one per session for a desktop one. The host opens and closes
platform windows to match, so a scene that leaves the list is a scene that
closes.

A scene's number is the library's - "1", "2", in the order they opened - and
never the platform's, which keeps the wire the same bytes on every run. The
platform's own identity for a scene, the one the system restores it by, stays
on the host, which keeps the two paired.

The list of scenes is a `@State` the root reads, so a scene opening or closing
builds the application again and nothing in the scenes that stay. Each scene's
record holds the windows it has open beside its main one as a `@State` its own
node reads, so opening a window in one scene builds nothing of another.

Each open scene is a `SceneElement`, a composed view whose type is the
application's scene type, so each scene has `@State` of its own, paired across
renders under its number. The application is asked for a scene value once per
scene: a scene's boxes belong to its value, and two scenes built from one value
would share every storage the first adopted.

## Sessions

Each scene has a `SceneSession` in the environment of everything under it, and
each window a `WindowSession`, held by its scene's record for as long as the
window is open, so what a window was told about itself outlives the renders that
describe it. The main window's session lives as long as the scene.

## Opening windows

A scene declares its window groups, and each build records their shapes: the
type of value a group opens one window per, and how to read that value back from
text. Opening a window checks the kind is declared and the value's type matches.
Whether a window may open beside another is the platform's: a desktop and an
iPad do, a phone does not, and a host that has not said - a test - does.

A window of a group has a number of its own in its scene, in the order windows
opened there, which keeps it the same window when the value it stands for
changes. Its kind, its value's text, whether it hides while another scene is in
front and whether it floats are written on every build, either way, so none of
them is ever cleared off a window it was on - those members have no host
default (contracts.md).

## What the platform keeps

For each scene the host writes down which windows it had open - each window's
kind and its value as text - and the values of the scene's `@State(sceneKey:)`.
What comes back at launch is what the system restores; nothing of the library's
decides it.

A window the system restored comes back only where the scene still declares its
kind and the text still reads as its value; anywhere else it closes again. "No"
is an answer too: the host holds the window until the render after the report
says whether the scene took it, so that render is asked for either way.

A window's value is any `Codable` the author chose, and the platform keeps text,
so `ValueText` writes a value as JSON and reads it back - by hand, with no
Foundation, and with an object's members in the order the value encoded them, so
one value is one text on every run.

## Scene keys

A scene record keeps the storage for each of its keys - one key, one piece of
state, in a scene as in the application - what the platform kept for them, and
the keys written since the host last took them. A scene key's write lands from
under its state's lock, from whichever thread wrote it, so the record holds its
own lock around those three tables. What the platform kept lands before the
scene's first build. The waiting values go out as one act per key per take, scene
by scene in the order they opened (state.md).

## Connecting and ending

The platform hands over windows nobody here asked for: the first at launch, one
for a new window, a scene the system restored. The first scene, made when the
application registered, waits for the platform's first window; any later window
is a new scene. Either way what the platform kept for the scene is restored
before it builds, and a render is asked for, since the host renders into the
window it is holding as soon as the call returns.

A scene ends when its main window goes - the user closed it, or the session's
`close()` asked - and every window beside it closes with it, along with an
inspector docked there.
