# StateUI handbook

This handbook is the complete conceptual guide to the current StateUI model.
The declarations in `lib/StateUI/Sources` are the API reference, the Gallery
exercises the contract, and the platform matrix records which native hosts have
proved each part.

StateUI is under active development. Before 1.0, public declarations and the
host contract may change together when native evidence improves the shared
model. A declaration that has no checked host in the platform matrix is not a
usable platform promise.

## Start here

- [Getting started](getting-started.md) builds the smallest application and
  explains the application module, native host, resources, and registration
  boundary.
- [Architecture](architecture.md) defines StateUI's two reactive paths,
  `Journey`, host-side motion, engines, and ownership split.
- [State and reactivity](state-and-reactivity.md) is the practical guide to
  `@State`, `@Binding`, persistence, conversions, sampling, and engines.
- [Motion and journeys](motion-and-journeys.md) defines motion laws,
  precedence, value journeys, interruption, visibility, and layout motion.
- [Environment](environment.md) covers application models, standard provider
  domains, dates, time, locale, and values supplied by a host.

## Build an interface

- [Applications and sessions](application-and-sessions.md) covers
  `Application -> Scene -> Window -> page`, restoration, scene-local state,
  window groups, lifecycle, and geometry.
- [Navigation and presentation](navigation-and-presentation.md) covers stacks,
  tabs, split views, modal pages, toolbars, menu bars, and context menus.
- [Layout](layout.md) covers stacks, grids, absolute placement, scrolling,
  frame readings, sizing, and the boundary for StateUI-authored layouts.
- [Controls and input](controls-and-input.md) explains control initializers,
  modifiers, two-way input, text, selection, focus, and control events.
- [Styles and drawing](styles-and-drawing.md) covers style resolution, themes,
  visual states, images, brushes, shapes, and `Canvas`.
- [Interaction and actions](interaction-and-actions.md) covers gestures,
  accessibility, `@Aim`, dialogs, and host actions.
- [Composition and identity](composition-and-identity.md) covers composed
  views, builders, identity, lifetime reactions, frame reports, and render
  diagnostics.
- [Concurrency](concurrency.md) defines `@MainThread`, handler suspension,
  `Ticker`, and the application module's compiler setting.

## Extend or host StateUI

- [Host contract](host-contract.md) specifies typed sparse patches, update
  order, host-carried state, native ownership, and Wire.
- [Platform contract](platform-contract.md) is the checked control, property,
  event, environment, and host-capability matrix. A check mark means native
  implementation plus host tests.
- [Control dictionary](controls/README.md) lists every control and part of an
  application's structure member by member, each with a mark per platform.
- [Project structure and development](development.md) covers repository
  layout, Gallery samples, vertical feature work, tests, and native builds.
- [Contributing](../CONTRIBUTING.md) states the evidence, documentation, and
  review rules for changing the contract.

## Project terms

- [License](../LICENSE) and [NOTICE](../NOTICE) state the terms and attribution
  carried by the source.
- [Trademark policy](../TRADEMARK.md) explains use of the StateUI name and
  mark, including forks and integrations.
- [Contributor agreement](../CLA.md) records the terms accepted for submitted
  contributions.

## Sources of truth

StateUI uses one source for each kind of question:

| Question | Source |
| --- | --- |
| What StateUI means | this handbook and public `///` documentation |
| What an application can spell | public declarations in `lib/StateUI/Sources` |
| What crosses a host boundary | `HostContract` and [Host contract](host-contract.md) |
| What a particular host implements | [Platform contract](platform-contract.md) and the [control dictionary](controls/README.md) |
| What works as visible behavior | the native Gallery |
| What keeps the contract stable | core, host, and Gallery tests |

A declaration is not evidence that every host implements it. Check the matrix
before relying on a capability on a target platform.
