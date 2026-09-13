# Contributing to StateUI

StateUI is one platform-neutral Swift model with independent native hosts.
Changes should make that model smaller, clearer, and more deterministic.

## Begin with evidence

Reproduce the behavior before changing it. A testable defect should have a
failing test that states the invariant. A native rendering or interaction issue
also needs a live Gallery check on the affected toolkit; a green core suite
proves only the contract it exercises.

## Change one vertical slice

A control, property, or event decision reaches every active layer together:

- Swift API and vocabulary;
- `HostContract` ownership;
- every applicable native host;
- focused core and host tests;
- the native Gallery;
- the handbook (`README.md`, `docs/`, and public `///` documentation).

Update `docs/platform-contract.md` in the same slice. Add `✅` only when the
control or complete member group is implemented and exercised by that host's
tests; absent, partial, and unverified support stays unmarked.

Remove obsolete API, examples, and tests when the contract deliberately drops
the capability. Do not preserve aliases unless compatibility is an explicit
requirement.

## Keep the core platform-neutral

Code under `lib/StateUI/Sources` does not import Foundation or a platform UI
framework. AppKit belongs under `lib/StateUI.AppKit`; each later host receives a
sibling package of its own.

Swift owns identity, diffing, state, journeys, and motion descriptions. Hosts
own native objects, platform callbacks, and display-frame property motion. Keep
renderers thin and derive richer behavior from StateUI primitives where that
produces one honest cross-platform contract.

## Write current documentation

README, `docs/`, and public API documentation are the handbook. Describe what
StateUI is now, why the current rule exists, and any current trap. Do not
narrate migration history or explain the API by comparison with another
framework.

Every public Swift declaration needs `///` documentation. Gallery pages use
minimal on-screen prose: show behavior directly and tell the reader only what
they need to try.

## Test

Run the suite owned by the area while iterating, then all three before handing
off a complete vertical change:

```bash
swift test
swift test --package-path lib/StateUI.AppKit
swift test --package-path apps/Gallery
```

Build the native Gallery bundle:

```bash
.scripts/build-gallery-appkit.sh debug
```

Run one application build at a time. Concurrent application builds share Swift
object directories and can silently execute stale output.

## Keep changes reviewable

Every source under `lib/` starts with the project's two SPDX lines, apart from
the documented `Package.swift` exception. Preserve unrelated worktree changes;
they belong to their author.

A commit message is a short declarative sentence describing what is now true.
Do not include generated-by text or authorship trailers.

The `_old/` tree is frozen reference material. It is outside active builds,
tests, packaging, and synchronization.

## Contribution terms

StateUI is distributed under the Apache License 2.0. A submitted contribution
is accepted under the terms of the current [StateUI contributor agreement](CLA.md)
as well as the project's source license. The first pull request from a
contributor triggers the repository's electronic CLA record; do not include
work owned by another party unless its source, license, and submission authority
are stated as required by that agreement.
