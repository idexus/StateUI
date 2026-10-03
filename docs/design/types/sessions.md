# Sessions

A session is one opening of something an application declares, and the
runtime values that opening holds. Each is in the environment of everything
under it, so a view acts on the one it is in - from a handler, an engine or a
task alike - and says which by the session it holds.

## One opening of something declared

```text
  ApplicationSession   the application, from its start to the end of its process
       |
       +-- SceneSession     a scene, from its first window opening to its last closing
              |
              +-- WindowSession    a window, from created to destroying
```

A page has no session: what it is, the view it shows says by modifier
([What a view says of its page](../views/pages.md#what-a-view-says-of-its-page)).

Every property is a `@State`, so a view that reads one builds again when it
is written, and what a session is told stands until it is told otherwise.
An optional property is nil until written, which leaves the host's own
default standing.

## Told not derived

A window's title is not worked out from the window's state on every build: it
is what the window was told, and it changes when something says so, which is
exactly a `@State` a handler writes. So what reads it builds again when its
session is written, by the rule every state follows, and is asked nothing on
a build caused by anything else.

## Values are told, structure is declared

A session holds values - a phase, a title, a size - and acts. What has a
body of its own - a view, an element with a handler - is declared in the tree
instead, where the state it follows lives: a page's actions with
`.toolbar { }`, the view in its title's place with `.titleView { }`. Built
with the body declaring it, it follows that state with nothing written by
hand, and it lives exactly as long as the element declaring it, so a page
that goes takes its declarations with it and nothing needs restoring.

## Values written into a session

A value written into a session is put on the node as the window builds, and a colour or a picture with a half for each theme is picked
there, so it is right in both themes whenever it was written.

## Collections hang as one node

A page's menus hang off the page as one node holding the collection,
`MenuBar`, and each toolbar group off the element declaring it as one
`ToolbarItemGroup` node, rather than as one node each. The host has a list to keep
in step, and a list needs a parent of its own to be matched against; a swipe
view's actions hang the same way.

## Scenes and windows are read not held

`ApplicationSession.scenes` and `SceneSession.windows` are made as they are
read, from what is open: nothing in a session holds a scene or a window, each
scene holds its own session, and a window's session knows its scene without
keeping it. A session held after its scene ended answers that it has, through
the application's list of scenes, whoever keeps the scene's record alive.

A view outside every scene or window reads a standard session that does
nothing: a scene always in front that opens nothing, a window that closes
nothing. Every scene and window offers its own, nearer.

## Kept keys are declared

`persistentKeys` lists every key the application keeps between launches,
written in the application's `init`. Reading a `@State` is synchronous, so a
kept value must be in memory before the first view is built, and a store is
read key by key, each with the kind of value it holds. The host therefore
asks for the keys as the application registers, reads exactly those, and
hands back what it found before the first render.

A key left off the list is never read. State declared with it still saves,
because a write knows its own key, so its value appears one launch late: the
symptom is a setting that lags one run behind. The list is the one thing
that cannot be worked out from the views, because the views that would name
the keys do not exist yet when the store is read.

## Styles and motion stay in the core

`ApplicationSession.styles` and `.motion` are never sent to a host. A style
is resolved in the core into the controls it applies to, a colour pair in it
picked for the theme as each control builds, so a sheet written once serves
both themes, and a sheet written again is the next render's. What reaches
the host of a motion is the resolved law, beside each property that
animates.

## Window geometry is a request

A window's position and size are requests to a host whose windows move and
resize. Each axis is independent: writing the width does not restore an old
height. An axis left nil stays under native window management, including the
platform's restoration and the user's resizing, and a host that shows its
windows full screen may keep the values without presenting them.
