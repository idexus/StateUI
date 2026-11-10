# Design notes

The reasons behind StateUI's code. A comment in the code says what a
declaration is in a line or three; the reason it is shaped so, the trap it
avoids and the rule it keeps are here, in the present tense.

## The golden rule

Comments stay under a quarter of every source file's lines; everything else
is a design note. The `///` documentation of a public declaration - what an
editor shows the developer on `.` - is not counted: it gives enough to choose
and use the declaration, and leaves how it works inside to these notes.

Where the code wants its reason, one line points here:

```text
/// Design: docs/design/<area>/<note>.md#<section>
```

The section is the heading's anchor: lowercase, letters and digits kept, each
run of spaces or hyphens one hyphen. `DesignNotesTests` checks that every
reference resolves, and holds the golden rule for every directory that meets
it.

## The examples of a doc comment

An example in `///` documentation is code indented four spaces after a blank
`///` line, as Markdown reads it; a line indented so right after words goes
on with them. It names the library as it stands, which the Gallery's suite
holds (`DocCommentExamplesTests`) in two ways.

An example of a library the suite's build holds - StateUI, StateUITesting -
is compiled: a function's body, or a file where it declares an extension or
a type a file holds. It leans on what its page declares - a state, a page,
the application's window kinds and keys - so it is compiled beside a prelude
of those, declared as an application declares them (`DocCommentPrelude`), and
fails only on what says the library changed: a member gone or out of reach,
an argument it no longer takes or now needs, a call nothing matches. Every
other error is the example's context, and a stale name behind a receiver
nothing declares goes unseen; a name an example leans on that the prelude
does not hold, and that fails as a change would, goes into the prelude.

An example the suite cannot compile is held to the library's recorded
surface (`lib/StateUI/exports/api`): a fragment - modifiers starting with `.`,
with no view before them - calls only modifiers some type declares, with
labels one of them takes; an example of a host's facade or a backend, whose
module this build does not hold, calls each type its surface declares only
by members recorded there, its arguments' labels filling one of them - a
parameter left out where it has a default, a pack or a variadic filled by
any number, the first trailing closure by any label.

## The notes

- [Architecture](architecture.md): the packages, one change end to end, and
  the threads, drawn.
- [Glossary](glossary.md): StateUI's words and the common term for each.
- [`core/`](core/README.md): the core drawn - a state write to a patch, the
  display cycle, the UI thread and the typed boundary - and the reasons of each part.
- [`views/`](views/README.md): how an application's views become the
  described tree - composition, builders, modifiers, bindings, pages, styles.
- [`types/`](types/README.md): the values an application passes and how
  each reaches a host.
- [`contracts/`](contracts/README.md): how an element contract declares a
  node type, its tiers and its members, and who reads it.
- `host/`: the runtime every host shares - [the runtime](host/runtime.md),
  [the mounted tree](host/tree.md), [pages](host/pages.md), [layout](host/layout.md),
  [motion](host/motion.md), [patches](host/patches.md), [items](host/items.md),
  [maps](host/maps.md), [the web view](host/web.md), and
  [conformance](host/conformance.md), the suite every host runs.
- `platforms/`: each platform's half of its runtime, one folder a platform.
  `platforms/appkit/`: [input](platforms/appkit/input.md),
  [views](platforms/appkit/views.md), [items](platforms/appkit/items.md),
  [registrations](platforms/appkit/registrations.md),
  [runtime](platforms/appkit/runtime.md), [conformance](platforms/appkit/conformance.md).
  `platforms/uikit/`: [the runtime](platforms/uikit/runtime.md),
  [controls](platforms/uikit/controls.md), [drawing](platforms/uikit/drawing.md),
  [input](platforms/uikit/input.md), [items](platforms/uikit/items.md),
  [layout](platforms/uikit/layout.md), [motion](platforms/uikit/motion.md),
  [pages](platforms/uikit/pages.md), [conformance](platforms/uikit/conformance.md).
  `platforms/android/`: [the runtime](platforms/android/runtime.md),
  [JNI](platforms/android/jni.md), [layout](platforms/android/layout.md),
  [controls](platforms/android/controls.md), [items](platforms/android/items.md),
  [menus](platforms/android/menus.md), [motion](platforms/android/motion.md),
  [drawing](platforms/android/drawing.md), [pages](platforms/android/pages.md),
  [conformance](platforms/android/conformance.md).
  `platforms/winui/`: [the relay](platforms/winui/relay.md),
  [the runtime](platforms/winui/runtime.md), [controls](platforms/winui/controls.md),
  [drawing](platforms/winui/drawing.md), [input](platforms/winui/input.md),
  [interop](platforms/winui/interop.md), [items](platforms/winui/items.md),
  [layout](platforms/winui/layout.md), [motion](platforms/winui/motion.md),
  [pages](platforms/winui/pages.md), [conformance](platforms/winui/conformance.md).
  `platforms/gtk/`: [the C API](platforms/gtk/c-api.md), [the runtime](platforms/gtk/runtime.md),
  [controls](platforms/gtk/controls.md), [drawing](platforms/gtk/drawing.md),
  [input](platforms/gtk/input.md), [interop](platforms/gtk/interop.md),
  [items](platforms/gtk/items.md), [layout](platforms/gtk/layout.md),
  [motion](platforms/gtk/motion.md), [pages](platforms/gtk/pages.md).
  `platforms/web/`: [the runtime](platforms/web/runtime.md), [the look](platforms/web/look.md),
  [pages](platforms/web/pages.md), [layout](platforms/web/layout.md), [controls](platforms/web/controls.md),
  [drawing](platforms/web/drawing.md), [input](platforms/web/input.md), [items](platforms/web/items.md),
  [interop](platforms/web/interop.md).

## Writing a note

A note describes the current design: what it is, why, and what breaks if it
changes. It names no earlier design and no other product. Diagrams are text in
`text` blocks, so they read the same in an editor, in a diff and on the web.
