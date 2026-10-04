# StateUI handbook

This handbook is the complete conceptual guide to the current StateUI model.
The declarations in `lib/StateUI/Core/Sources` are the API reference, the Gallery
exercises the contract, and the platform matrix records which native hosts have
proved each part.

StateUI is under active development. Before 1.0, public declarations and the
host contract may change together when native evidence improves the shared
model. A declaration that has no checked host in the platform matrix is not a
usable platform promise.

The handbook stands in folders by topic, in the order below: `concepts/` the
model, `interface/` building an interface, `internals/` the core and the host
layer, `hosts/` each native host; the matrix, the control dictionary and the
design notes beside them.

## Start here

- [Getting started](getting-started.md) sets up VS Code and the StateUI
  extension, builds the smallest application, and explains the application
  module, native host, resources, and registration boundary.

## Concepts

- [Architecture](concepts/architecture.md) defines StateUI's two reactive
  paths, `Journey`, host-side motion, engines, and ownership split.
- [Why StateUI is shaped this way](concepts/why.md) states the decisions every
  API follows and the shapes deliberately rejected; read it before
  contributing.
- [State and reactivity](concepts/state-and-reactivity.md) is the practical
  guide to `@State`, `@Binding`, persistence, conversions, sampling, and
  engines.
- [Motion and journeys](concepts/motion-and-journeys.md) defines motion laws,
  precedence, value journeys, interruption, visibility, and layout motion.
- [Environment](concepts/environment.md) covers application models, standard
  provider domains, dates, time, locale, and values supplied by a host.

## Build an interface

- [Applications and sessions](interface/application-and-sessions.md) covers
  `Application -> Scene -> Window -> page`, restoration, scene-local state,
  window groups, lifecycle, and geometry.
- [Navigation and presentation](interface/navigation-and-presentation.md)
  covers stacks, tabs, split views, modal pages, toolbars, menu bars, and
  context menus.
- [Layout](interface/layout.md) covers stacks, grids, layers, scrolling,
  frame readings, sizing, and the boundary for StateUI-authored layouts.
- [Controls and input](interface/controls-and-input.md) explains control
  initializers, modifiers, two-way input, text, selection, focus, and control
  events.
- [Styles and drawing](interface/styles-and-drawing.md) covers style
  resolution, themes, visual states, images, brushes, shapes, and `Canvas`.
- [Interaction and actions](interface/interaction-and-actions.md) covers
  gestures, accessibility, `@Aim`, dialogs, and host actions.
- [Composition and identity](interface/composition-and-identity.md) covers
  composed views, builders, identity, lifetime reactions, frame reports, and
  render diagnostics.
- [Concurrency](interface/concurrency.md) defines handler isolation on
  `MainActor`, handler suspension, `Ticker`, and the application module's
  compiler setting.

## Internals

- [Host contract](internals/host-contract.md) specifies typed sparse patches,
  update order, host-carried state, native ownership, and the values a host is
  handed.
- [StateUI core](internals/core.md) maps the library every application and
  host links, folder by folder: what each part owns, who reaches it, and the
  typed boundary a host reads.
- [Host layer](internals/host-layer.md) maps the Swift every host runs on,
  module by module: what it decides for every host, and what a host provides
  and calls.

## Hosts

Each page builds, runs, and tests one Swift host, in the application's
process.

- [AppKit](hosts/appkit.md) renders an application with AppKit on macOS.
- [UIKit](hosts/uikit.md) renders it with UIKit on iOS and iPadOS, on a
  simulator or a device.
- [Android Views](hosts/android.md) renders it with Android views.
- [WinUI](hosts/winui.md) renders it with WinUI 3 on Windows.
- [GTK](hosts/gtk.md) renders it with GTK 4 and libadwaita on Linux.

## Support and development

- [Platform contract](platform-contract.md) is the checked control, property,
  event, environment, and host-capability matrix. A check mark means native
  implementation plus host tests.
- [Control dictionary](controls/README.md) lists every control and part of an
  application's structure member by member, each with a mark per platform.
- [Tested setups](tested-setups.md) names the systems, toolchains and
  devices on which each host's suites pass and its Gallery is walked.
- [Project structure and development](development.md) covers repository
  layout, Gallery samples, vertical feature work, tests, and native builds.
- [Design notes](design/README.md) draw the architecture and give the reasons
  behind the code, with a glossary of StateUI's terms.
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
| What an application can spell | public declarations in `lib/StateUI/Core/Sources` |
| What crosses a host boundary | the element contracts and [Host contract](internals/host-contract.md) |
| What a particular host implements | [Platform contract](platform-contract.md) and the [control dictionary](controls/README.md) |
| What works as visible behavior | the native Gallery |
| What keeps the contract stable | core, host, and Gallery tests |

A declaration is not evidence that every host implements it. Check the matrix
before relying on a capability on a target platform.
