# Views

`lib/StateUI/Sources/Views` holds what an application writes: the structure
(`Application`, `Scene`, `Window`, `Page`), the controls, the layouts and
arrangements, the modifiers, the builders, the styles, and the library's own
composed views. Each of them is a value that describes itself as a node; the
core's differ turns the nodes into the patch a host applies.

Its folders: `Tiers` and `Mixins` the tiers and their modifiers, `Bindings` a
property carried from a state, `Composition` composed views and builders,
`Controls`, `Text`, `Layouts`, `Shapes` and `Collections` the library's views,
`Structure`, `Navigation` and `Menus` the application, its pages and what
hangs off them, `Styles` the styles and `Inspector` the inspector.

## The notes

| Note | What it covers |
| --- | --- |
| [composition.md](composition.md) | composed views as placeholders, their modifiers, container content, watchers, state and items in composed views |
| [builders.md](builders.md) | result builders, the path key every statement records, `ForEach` keys, menus, windows and styles |
| [tiers.md](tiers.md) | the two halves of the tier hierarchy, the mixin tiers, each control's own properties |
| [modifiers.md](modifiers.md) | how a modifier writes, handlers, slot children, motion, keys and aims, transforms, accessibility, gestures, placement |
| [bindings.md](bindings.md) | binding twins, carried states, modes, driven text, two-way controls, feeds, sampling |
| [controls.md](controls.md) | the shape of a control, closed vocabularies, and each control's own rules |
| [pages.md](pages.md) | application, scenes, windows, pages, the arrangements and their keys |
| [styles.md](styles.md) | styles resolved before the patch, visual states, the sheet |
| [measured-layouts.md](measured-layouts.md) | frame reports, placed layouts, the scroll reader and the gallery |
| [lists.md](lists.md) | the list that describes only the items in view |
| [inspector.md](inspector.md) | the in-app inspector of renders |

## From an application to the tree

An application declares types; the tree under a window is views.

```text
  Application ──scene──▶ Scene ──windows──▶ Windows ──main──▶ Window ──page──▶ any Page
      │                    │                   └──groups──▶ WindowGroup ──▶ Window     │
  ApplicationSession   SceneSession                          WindowSession            │
                                                                                      │
          ┌───────────────────────────────────────────────────────────────────────────┤
          │ an arrangement - NavigationStack, TabbedView, SplitView -                  │ any other view -
          │ is a page itself, and keys the pages it holds                              │ usually a ContentView -
          ▼                                                                            ▼ goes on a page element
      pages (each a view on a page element, or another arrangement)            that holds its PageSession
                                                                                       │
                                                                                       ▼
                                                                          views: composed views, controls,
                                                                          layouts, each with its modifiers
```

A window's node carries its page and what hangs off it - the title bar and the
modal stack from its session, the inspector's panel - and a page's node carries
the view and its toolbar, menus and title view. See pages.md.

## What a view is

Everything a builder collects is an `Element`: something that answers `body`, a
`Node` read afresh on every render.

```text
  a control              struct Label: View { var node: Node }
    Label("Total")         body is its node: Node(Label, props: [text: "Total"])

  a container            VStack { … }
                           Node(VStack) whose content closure runs only when
                           the differ reaches the stack

  a composed view        struct Header: ContentView { var content: any View }
    Header("Settings")     body is a placeholder, Node(Composed): the differ builds
                           `content` into it, keeping the view's @State - or
                           carries the view whole

  a modifier             .fontSize(20)        props[fontSize] = 20
  (a modified copy)      .onTapped { … }      events[tapped] gains a handler
                         .opacity($fade)      driven[opacity] = the state's registration
                         .id("total")         the node's key
                         .contextMenu { … }   a slot child after the view's own
```

A control's modifiers come from the tiers it wears, and a style wears only the
property half of the same tiers (tiers.md). A modifier on a composed view gives
back a `ModifiedContent`, since the composed value keeps no node of its own
(composition.md).

## One render

A state write rebuilds the bodies and container closures that read it, and the
differ turns what they describe into a patch.

```text
  a state is written
     │  its readers: a body, or a container's content closure
     ▼
  body / content ──▶ ViewBuilder ──▶ [Element], each keyed by its path ("0", "1.some.0")
     │                                ForEach views keyed by their items
     ▼
  a tree of nodes with placeholders and deferred content
     │
     ▼  the differ, element by element (Core/Diff/Differ.swift)
  children matched by explicit id, then path, then position
  a composed view: its @State boxes adopted, its content built - or carried whole
  a container: its content run in its own read scope
  styled(node, with: sheet): the style merged under the node's own values
  themed values resolved: Color(light:dark:), ImageSource(light:dark:)
     │
     ▼
  HostPatch, typed and sparse ──▶ a Swift host
  the same patch as Wire bytes ──▶ a runtime in another language
```

A value carried on a state crosses once, as a registration, and then moves on
the host's frames with no render at all (bindings.md).

## Where the element contracts come in

Every node type exists through one element contract: its node type, the tiers
it wears, and each member with its value's type. The views write and hear
through those members, never through spelled tokens.

```text
  Contracts/Elements, Contracts/Tiers, Contracts/Mixins
    LabelContract: ElementContract
      nodeType "Label", layer, tiers [View, TextElement, FontElement, …]
      members: lineBreak, maximumLines         ElementProperty / ElementEvent / ElementAct
         │
         ├─ Node(contract: LabelContract.self)           the control's node type
         ├─ setValue(LabelContract.maximumLines, 3)      a property: its token, a typed value
         ├─ onEvent(ButtonContract.clicked) { … }        an event: a typed payload, or none
         └─ aim.call(MapContract.moveToRegion, …)        an act, called through an aim
         │
         ▼
    the Swift tier protocols wear the same tiers:   VisualElementContract  ↔  VisualElementProperties
         │                                           ViewContract           ↔  ViewProperties …
         ▼
    each host declares which members it realizes:  docs/platform-contract.md, docs/controls/
```

The tier protocols here and the tier contracts under `Contracts/Tiers` and
`Contracts/Mixins` name the same sets, so a modifier offered on a tier is a
member that tier's contract declares.
