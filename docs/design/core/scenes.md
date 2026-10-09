# Scenes

An application's body declares its scenes, each standing at most once: it opens
with its first window and ends with its last. Which scenes stand and which
windows each has open is the library's to hold, never the author's: launch, the
platform and `ApplicationSession.openWindow` open windows, and the user and a
session close them. `OpenScenes` (OpenScenes.swift) keeps the scenes standing as
state the root of the tree reads.

## The scene tree

```text
  Application
    Scene "1"            one per scene standing, in the order they opened
      Window "window 1"  a window of the group with no name: "window", and its number
      Window "fonts 2"   a window of a kind: the kind, and its number
    Scene "2"
      Window "about 1"
```

The application is the root and its scenes an arranged list. The host opens
and closes platform windows to match, so a window that leaves the tree is a
window that closes.

A scene's number is the library's - "1", "2", in the order they opened - and
never the platform's, which keeps the patch the same on every run. A window's
key is its kind and a number of its own in its scene, in the order its windows
opened, which keeps it the same window when the value it stands for changes.

The list of scenes is a `@State` the root reads, so a scene opening or ending
builds the application again and nothing in the scenes that stay. Each scene's
record holds its windows as a `@State` its own node reads, so opening a window
in one scene builds nothing of another - and nothing of the windows standing
in it: a window's placeholder is carried while what it was given is the same.

Each scene standing is a `SceneElement`, a composed view whose type is the
scene's own, so its `@State` is paired across renders under its number and
shared by every window of it.

## A scene stands once

A scene stands at most once: a window of it opens in it where it stands, and
opens it where it does not. Every window of a scene shares the scene's state;
what belongs to one window is the `@State` of the view it shows. A scene ends
when its last window goes - the user closed it, a session closed it, or the
scene's session closed them all - and its state goes with it: the next window of
it opens a fresh scene.

What each scene declares is read from the application's body in a read scope
of its own whose reads are dropped, so a write to a scene's state builds that
scene, never the application's root. What a scene declares is therefore fixed:
what a window shows may change, which windows a scene declares may not.

A window of a kind belongs to the scene declaring that kind; one kind is
declared by one scene, and the group with no name by one scene of the
application. Where several declare one, the first does.

## Launch and New

Launch opens one window: of the `WindowGroup` with no name, in the scene
declaring it - else the first window of no value the first scene declares. The
application is made at its first need, so the scene launch opens is settled
then, before anything reads it. *File ▸ New Window* and `openWindow()` open one
more window of that group.

## Opening windows

`ApplicationSession.openWindow` opens a window by its kind, in the scene that
declares it: a `Window(.kind)` once, a window of a `WindowGroup(.kind, for:)`
once a value, and one more window of a `WindowGroup` each time it is asked.
Opening checks the kind is declared and the value's type matches. Whether a
window may open beside another is the platform's: a desktop and an iPad do, a
phone does not, and a host that has not said - a test - does.

A window's kind, its value's text, whether it hides while another scene is in
front and whether it floats are written on every build, either way, so none of
them is ever cleared off a window it was on - those members have no host
default (contracts.md). A window of the group with no name carries no kind.

## What the platform hands over

A window the platform made comes through one entry,
`HostBoundary.connectWindow`:

- the platform's first window is the one launch opened;
- a new window of no kind is one more of the group with no name;
- a window the platform kept comes as the kind and the value's text it carried,
  with its scene's kept values, and opens in the scene declaring that kind,
  which opens with it where it does not stand.

A kept window of another kind coming first takes the place of the window
launch opens: what the platform kept is what stands. A kind no scene declares,
or a text that no longer reads as the group's value, is refused, and the host
closes the window; the window launch opens waits on for the platform's next. What the platform kept for a scene lands only where the
scene opens with that window, before its first build; a scene standing already
keeps its own.

## What the platform keeps

For each window the host writes down its kind and its value as text, and with
it the values of its scene's `@State(sceneKey:)`. What comes back at launch is
what the system restores; nothing of the library's decides it.

A window's value is any `Codable` the author chose, and the platform keeps text,
so `ValueText` writes a value as JSON and reads it back - by hand, with no
Foundation, and with an object's members by their keys, so one value is one text
on every run: a dictionary hands its members over in its hash's order.

## Sessions

Each scene has a `SceneSession` in the environment of everything under it, and
each window a `WindowSession`, held by its scene's record for as long as the
window is open, so what a window was told about itself outlives the renders that
describe it.

## Scene keys

A scene record keeps the storage for each of its keys - one key, one piece of
state, in a scene as in the application - what the platform kept for them, and
the keys written since the host last took them. A scene key's write lands on
the UI thread, as every state's does, so the three tables need no lock. What
the platform kept lands before the
scene's first build. The waiting values go out as one act per key per take, scene
by scene in the order they opened (state.md).
