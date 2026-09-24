# Glossary

StateUI's words and the common term for each. Comments and design notes use
the common term where one exists; a name in the API keeps its StateUI word,
and this table maps the two.

## People and structure

| StateUI term | Common term | What it means here |
| --- | --- | --- |
| user | user | the person using the application |
| application, scene, window, page | same | the structure an application declares: `Application -> Scene -> Window -> Page` |
| element | node | one entry of the described tree: a control, a layout, a part of the structure |
| element contract | node schema | a node type's declaration: its tiers and each member with its value's type |
| tier | trait | a set of members several elements share, such as `VisualElement` |
| member | property, event or method | a property, an event or an act an element declares |
| wear (a tier) | adopt, conform to | an element contract taking a tier's members |
| layer (`ElementLayer`) | implementation source | who realizes a node type or a member: the platform, an adaptation, StateUI, the structure or a provider |
| slot | named placeholder | a structural child that holds authored content in a known place: `Content`, `LeadingContent`, `TitleView` |
| slot child | auxiliary child | a child a modifier appends after the laid-out ones: a context menu, visual states |
| watcher (`.onChanged`) | change observer | a view that runs code when a value it watches changes |
| mixin tier | mixin, trait | a tier several contracts wear for one group of members |
| resting state | default visual state | the visual state a control shows when no other applies |
| arrangement (`PageArrangement`) | page container | a page that arranges other pages: a stack, tabs, a split view |
| arrangement (navigation) | navigation container | `NavigationStack`, `TabbedView` and `SplitView`: what decides which page shows |
| session | per-instance runtime state | the values one opening of an application, a scene, a window or a page holds |
| session (`PageSession`) | per-page state | the runtime values a page holds while it is shown |

## State and reactivity

| StateUI term | Common term | What it means here |
| --- | --- | --- |
| `@State` | state | the one declaration of mutable state |
| `Binding` (`$x`) | binding | a borrowed reference to a state |
| body rebuild, reactive path 1 | re-render | a body that read a written state runs again and is diffed |
| reader (of a state) | dependent, subscriber | the body or content that read a state and is rebuilt when it changes |
| binding twin | binding overload | the `Binding` form of a value modifier |
| driven property | bound property | a control property that reads a state the host carries |
| follow (`following:`) | depend on, subscribe to | what wakes an engine: a write to a state it follows |
| conversion (`convert`) | derived binding | a binding that reads and writes another state through a mapping |
| lender, lent | source storage | what a `Binding` borrows its value from |
| reading, sample (`.samples`) | throttled copy | an animated value copied into ordinary state at a pace |
| host-carried state, reactive path 2 | bound control value | a state a native control shows and changes with no rebuild |
| attachment, wear (a state), wearer | binding, bound control | a control property tied to a state |
| report | input event | the user's change on its way from a control to the core |
| feed | host-supplied value | a value only the platform knows, such as focus or a frame, read into a state |
| kept value (`persistent`) | persisted state | a state saved in a store and read back at launch |
| standard environment, provider | environment object | the typed values an application and its host provide down the tree |
| themed pair, the half in force | light and dark variant, the active variant | a value with one side for each theme, and the side the theme picks |
| engine | frame callback | application code that runs once per display frame while it follows states |

## Identity and diffing

| StateUI term | Common term | What it means here |
| --- | --- | --- |
| identity, `.id()`, `ElementId` | key | what keeps an element the same element across renders: an explicit `.id()`, then the builder path, then the position |
| render | reconcile | build the patch between the tree the host holds and the tree the state describes |
| patch (`HostPatch`) | diff | the sparse change from one tree to the next |
| road (walk, build, complete) | render mode | how a render reaches the elements it describes |
| path (builder) | structural key | where a statement stood in its builder: `1.else.0` |
| clean walk (`revisit`) | partial re-render | only the elements whose reads meet the changes are rebuilt |
| resync (`describeAll`) | full sync | the complete tree sent to a host that lost its generation |
| settle pass | handler flush | the handlers a render found run, their writes merged into the same message |
| carry, carried view | skipped subtree | a composed view whose inputs and reads held is not built, compared or sent |
| inputs (`Input`) | props | a view's stored values, compared to decide whether to carry it |
| placeholder (`Node.Stateful`) | lazy node | a composed view not built yet |
| producer | deferred children | a container's content, run when the element is described |
| shape (recycling) | reuse identifier | what says two rows have the same structure |
| generation, baseline | version | the tree a patch was computed against |
| drift | desync | a patch that does not match the tree the host holds |
| mount, mounted element | mounted node | the host's live instance of an element; `mount` is its instance number |
| realization | native adapter | how a host implements an element with its toolkit's control |
| described property | declared value | a property value the patch carries |
| recycling | view reuse | a list row's native views kept and given to the next row of the same shape |
| closed vocabulary, open vocabulary (`Name`) | enumeration, interned name | a fixed set of numbered choices, and a set an author names |
| kind first (`Kind`) | tagged value | a structured value whose first part says which shape follows |
| state image, carried value | state buffer | a bound state's value as the host reads and writes it |
| dirty word | dirty mask | the bits saying which parts of a value changed |
| board (`CycleBoard`) | per-clock frame state | one clock's images, engines and cycle |
| image (`HostStorage`) | shared value buffer | the bytes both sides read for a carried state |
| crossing | boundary encoding | the published bytes, inherited and custom timing resolved |
| door (`StateKind`) | binding kind | how a carried state reaches a control: text, plain value, animated value, placement run, feed |
| latch, publish | snapshot, commit | the first and the last step of a cycle |
| stamp | write counter | what an engine compares to know a state changed |
| armed, stirred, awake | wake reasons | why an engine runs on a frame |

## Motion

| StateUI term | Common term | What it means here |
| --- | --- | --- |
| motion (`Motion`) | animation timing | how a change animates: an eased curve over a duration, a spring, or none |
| law, motion law | timing function | the curve or spring that gives a value at a time (`HostMotionLaw`) |
| journey (`$x.journey`) | animated value | a state's value with its destination, speed and timing |
| animation (`Animation`) | animation | one running animation of one value |
| animator (`Animator`), advance | animator, advance a frame | the one place a runtime advances every animation |
| lane | component | one number of an animated value: x of a point, red of a colour |
| land, arrive | finish | an animation reaching its destination |
| snap | jump | a change applied at once, with no animation |
| travels, cleared, moves (member facts) | animatable, reset when unset, animation group | what a member's contract says about how its value changes |
| travel, travelling layout | layout animation | a layout's children animating to their new places |
| state channel | animated state source | the one place a runtime animates a bound state for every control tied to it |
| described motion | property animation | the animation a patch describes for a property |

## The runtime

| StateUI term | Common term | What it means here |
| --- | --- | --- |
| host | platform backend | the code that shows StateUI with one toolkit |
| runtime | backend runtime | a host's elements: the host layer and its toolkit half |
| host layer | shared backend code | the toolkit-neutral elements in `lib/StateUI/Sources/Host` |
| display cycle, cycle | frame update | the ordered work of one display frame |
| frame clock | display link, vsync | what ticks once per display frame while something holds it |
| doorbell | wake-up thread | a thread parked until the core has work, which then wakes the UI thread |
| pump, turn | event-loop pass | one pass of the host's work: jobs, a cycle, a render, then acts |
| program write | programmatic change | a write to a control made by the program, not the user |
| act | imperative control call | a call the application makes on a control, such as `focus` |
| aim (`@Aim`) | control reference | the reference an act is called through |
| completion id | continuation handle | the negative id an awaited act or animation is answered by |
| receipt | in-flight call record | what fails the calls of a batch a host could not read |
| declaration (`HostDeclaration`) | capability manifest | which elements and members a host realizes: presence, not ownership |
| dictionary, announcement (`WireDictionary`) | interning table | the names the Wire sends once and then by number |
| tally, pass, complaint | render counters, trace record, logged warning | what the core's diagnostics count, trace and say once |
| sync (`Sync`) | frame source | the clock a cycle runs on |
| arrangement (layout) | layout pass | a layout placing its children |
| placement | frame | the rectangle a layout gives a child |
| shade, rank | dimming overlay, z-order | what a placement run draws over a child, and its order among siblings |
| room | layout boundary | a container its place sizes, which lays out a change inside itself; in a view's own text, the space it is given |
| seat | layout position | a child's place in a layout while it animates |
| Wire | binary protocol | the patch and the cycle as deterministic bytes for a runtime in another language |
| record, mark (the dictionary) | declaration entry, support status | a host's statement that it realizes a member, and the ✅ or ☑️ it earns |
