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
- every applicable host, the MAUI host included;
- focused core and host tests;
- the Gallery, on every host the change reaches;
- the handbook (`README.md`, `docs/`, and public `///` documentation).

Update `docs/platform-contract.md` in the same slice. Add `✅` only when the
control or complete member group is implemented and exercised by that host's
tests; absent, partial, and unverified support stays unmarked.

Remove obsolete API, examples, and tests when the contract deliberately drops
the capability. Do not preserve aliases unless compatibility is an explicit
requirement.

## Keep the core platform-neutral

Code under `lib/StateUI/Sources` does not import Foundation or a platform UI
framework. AppKit belongs under `lib/StateUI.AppKit` and the .NET MAUI host
under `lib/StateUI.Maui`, with its build in `.scripts/Maui`; each later host
receives a sibling package of its own. Swift written for the MAUI host alone
stands under `#if MAUI`, the condition every MAUI build defines.

The core schedules nothing on Foundation's `Timer` or `RunLoop`, or on
`DispatchQueue.main`: nothing drains them on Android or Windows. Work for the
UI thread goes to `MainActor`, and a timer is `Task.sleep` or `Ticker`. Memory
allocated in Swift is freed in Swift - never `strdup` and `free` - because
several C runtimes can share a Windows process.

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
minimal on-screen prose: show behavior directly and tell the user only what
they need to try.

Every public C# member of the MAUI host carries XML documentation: CS1591 and
CS1573 are errors in its projects.

## Test

Run the suite owned by the area while iterating, then every suite before
handing off a complete vertical change. In VS Code, run **StateUI: Run Tests**
once with AppKit and once with .NET MAUI chosen. From a terminal,
`.scripts/test-native.sh` runs every Swift suite under both conditions:

```bash
.scripts/test-native.sh
dotnet test lib/StateUI.Maui/Tests
```

A plain `swift test` compiles neither `#if APPKIT` nor `#if MAUI` code, so it
does not test either host's half on its own.

Run the Gallery with **StateUI: Debug** on each host the change reaches:
AppKit, and .NET MAUI on the affected platform. From a terminal:

```bash
.scripts/AppKit/build-gallery-appkit.sh debug
dotnet build apps/Gallery/Platforms/Maui -f net10.0-maccatalyst27.0
```

Run one application build at a time. Concurrent application builds share Swift
object directories and can silently execute stale output.

A pull request to `main` or `dev` runs the `Tests` workflow and the four
platform builds: `iOS / Mac Catalyst`, `Android`, `Windows`, and `Linux`.

## Keep changes reviewable

Every source under `lib/` starts with the project's two SPDX lines, apart from
the documented `Package.swift` exception. Preserve unrelated worktree changes;
they belong to their author.

A commit message is a short declarative sentence describing what is now true.
Do not include generated-by text or authorship trailers.

## Contribution terms

StateUI is distributed under the Apache License 2.0. A submitted contribution
is accepted under the terms of the current [StateUI contributor agreement](CLA.md)
as well as the project's source license. The first pull request from a
contributor triggers the repository's electronic CLA record; do not include
work owned by another party unless its source, license, and submission authority
are stated as required by that agreement.
