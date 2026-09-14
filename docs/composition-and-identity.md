# Composition and identity

StateUI applications build larger meanings from small native primitives.
Composition stays in Swift; identity lets the differ preserve the native
controls, state, focus, caret, and scroll positions that belong to that
meaning.

## Composed views

A `ContentView` declares one semantic component and returns the views it is
made from:

```swift
struct StatusBadge: ContentView {
    let title: String
    let ready: Bool

    var content: any View {
        HStack {
            BoxView(ready ? .green : .gray)
                .width(8)
                .height(8)
            Label(title)
        }
        .spacing(8)
    }
}

StatusBadge(title: "Archive", ready: true)
    .margin(12)
```

The initializer carries the component's purpose. Optional presentation and
behavior are modifiers. A composed view receives the modifiers common to
every view; a control-specific modifier belongs inside the component, on the
control that actually implements it.

A composed view does not create an extra native wrapper. Its placeholder gives
the differ an ownership boundary, then resolves to `content` when that boundary
must be described. This keeps composition cheap while giving local state and
invalidation a precise owner.

Prefer composition when several primitives together express an application
concept. Add a base control only when the behavior has one honest native
contract across the target platforms or belongs to an optional provider.

A modifier specific to the composed concept returns another `Self`:

```swift
struct Badge: ContentView {
    private var color = Color.cornflowerBlue

    var content: any View {
        Label("New")
            .textColor(.white)
            .backgroundColor(color)
    }

    func color(_ value: Color) -> Self {
        var copy = self
        copy.color = value
        return copy
    }
}

Badge()
    .color(.gold)
    .margin(8)
```

Write a component-specific modifier before common view modifiers. A common
modifier such as `margin` returns StateUI's modified wrapper, whose surface is
the shared view contract rather than the original component's custom methods.

## What makes a composed view rebuild

When a parent is described again, the differ compares what each composed child
was built with. Equal comparable inputs allow the complete child subtree to be
carried without rebuilding it. The comparison follows the semantic kind of an
input:

| Input | What is compared |
| --- | --- |
| value conforming to `Equatable` | value equality |
| ordinary class | object identity |
| `@Binding` | the storage and member being borrowed, not its current value |
| owned `@State` or `@Aim` | the adopted storage box |
| `@Environment` | the resolved object |
| opaque closure or value | not comparable, so the view rebuilds |

This comparison complements read tracking. A changed input rebuilds the child;
a write to state the child read also rebuilds it. A binding passed through but
not read remains a stable channel and does not become a reason to rebuild.

The comparison always errs toward rebuilding. An input whose equality cannot
be established is never assumed unchanged.

## Element identity

Identity answers one question: which element in the new description continues
which element from the previous description? A continuing element keeps its
native control, local state, handlers, focus, caret, selection, and other
platform-owned standing state.

StateUI resolves identity in this order:

1. An explicit `.id(...)` written by the application.
2. The item identity supplied by `ForEach`.
3. The stable path recorded by `ViewBuilder`, including conditional branches.
4. Position among siblings when no stronger identity exists.

An explicit id must be unique among siblings and stable while the element means
the same thing. Its text representation is the boundary, so a custom
`description` must remain just as distinct as the underlying value. Identify a
class instance by a stable property it owns rather than by the class value
itself.

```swift
struct FileRow: ContentView {
    let path: String

    var content: any View {
        Entry()
            .placeholder(path)
            .id(path)
    }
}
```

`.id` is internal tree identity. `.automationId` is a stable external handle
for platform automation. `.aim` lets an action reach a current element. These
three names solve different problems and do not replace one another.

## Builders and conditional identity

`ViewBuilder` records the statement and branch that produced each child. A
view after an optional branch therefore keeps its identity when that branch
appears or disappears:

```swift
@State var signedIn = false
@State var search = ""

VStack {
    if signedIn {
        Label("Welcome")
    }

    Entry($search)
}
```

The `Entry` remains the second statement in the builder even while its flattened
array position changes. Its native focus and caret do not belong to the
temporary array index.

The `if` and `else` branches are distinct identities even when both create the
same control type. Switching branches replaces the element because the
application described a different logical place.

A plain `for` is deliberately unavailable inside `ViewBuilder`. Use `ForEach`
so each repeated child has an item identity:

```swift
let names = ["Ada", "Grace", "Linus"]

VStack {
    ForEach(names) { name in
        Label(name)
    }
}
```

Items must be distinct. If complete values repeat or are not `Hashable`, pass a
stable distinct key path with `ForEach(items, id: \.id)`.

## State follows identity

State declared by a value-type composed view survives because the differ adopts
the previous element's state storage before building its new value. The rule is
simple: same identity and same composed-view type means the same owned state.
A different identity or view type starts from the declaration's initial value.

Moving an identified row preserves its state. Removing it ends that state.
Reintroducing the same textual id later creates a new element; ids match
between adjacent descriptions and are not a global object registry.

## Element lifetime

`onCreated` and `onDestroying` describe membership in the StateUI tree, not
allocation of a platform object:

```swift
@State var visible = true
@State var log: [String] = []

VStack {
    Button(visible ? "Hide" : "Show").onClicked { visible.toggle() }

    if visible {
        Label("Draft")
            .onCreated { log.append("created") }
            .onDestroying { log.append("destroying") }
    }
}
```

`onCreated` runs once after the render that first describes the element has
walked the tree. State and environment already resolve, and writes made before
the handler's first suspension can enter that render's patch.

`onDestroying` runs once after the first render that no longer describes the
element. Its state and environment still answer, which makes it the place to
save local work or stop a resource owned by that element. Descendants destroy
inside-out before a replacement is created; creation runs outside-in.

Rebuilding or carrying an existing element is neither creation nor destruction.

## Reacting to a changed value

`onChanged` compares one `Equatable` value with the value the same element
carried in its previous description:

```swift
@State var step = 0
@State var direction = ""

Label(direction)
    .onChanged(step) { old, new in
        direction = new > old ? "forward" : "back"
    }
```

It does not run on the first description; use `onCreated` when arrival itself
requires work. Multiple watchers are paired by modifier order. If their count
or value type changes, that element starts watching afresh instead of matching
unrelated slots.

Handlers run after the tree walk. A write made by a handler can therefore be
settled safely. A handler that unconditionally changes the value it watches
creates a feedback loop; every such write needs a stopping condition.

## Build diagnostics

Call `debugInfo()` inside the description whose work you want to understand:

```swift
struct BuildProbe: ContentView {
    @State private var count = 0

    var content: any View {
        VStack {
            Label(debugInfo())
            Button("Build").onClicked { count += 1 }
            Label("\(count)")
        }
    }
}
```

It reports the current composed view, its build count, and why it is being
described: first time, a named state it read, the whole tree, or with its
parent. It is a reading taken during construction and has no meaning outside a
build scope.

The Inspector records complete render passes only while it is open or host
logging is enabled. Offer it from a page toolbar and optionally give the scene
its own inspector window:

```swift quote
struct EditorScene: Scene {
    var windows: Windows {
        Windows {
            WindowGroup(.debugInspector) { DebugInspector() }
        } main: {
            EditorWindow()
        }
    }
}

// Inside a page with SceneSession and PageSession environments:
.onCreated { page.toolbarItems = [.inspector(scene)] }
```

The inspector shows what caused each pass, whether a composed view was built,
carried, or walked, the Swift and host costs, and how many native controls were
made, kept, or adopted. It records nothing while closed, so applications that
do not use it pay only disabled checks.

Set `STATEUI_INSPECT=1` in the host process to emit the same render record as
diagnostic text from the first pass. Use this for automated runs or a problem
that happens before the inspector can be opened.

## Recovery and resynchronization

Normal renders are sparse: unchanged properties, handlers, driven bindings,
and children are absent from the patch. If a host reports that it lost its
tree, the renderer sends one complete generation. That pass builds even the
composed views that an ordinary render could carry, because the host needs
every effective field once. It still reconciles against the retained tree, so
the same identities and current state reconcile the complete native hierarchy
without creating or destroying continuing elements. Application code does not
maintain a second recovery path. The exact update semantics are defined in
[Host contract](host-contract.md).
