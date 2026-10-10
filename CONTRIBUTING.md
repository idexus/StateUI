# Contributing to StateUI

StateUI is one platform-neutral Swift model with independent native hosts.
Changes should make that model smaller, clearer, and more deterministic.

## Know the decisions first

[Why StateUI is shaped this way](docs/concepts/why.md) states the decisions
every API follows and the shapes deliberately rejected - among them a modifier
without an argument such as `.bold()` or `.center()`, tracking `@Observable`
models, and routers. Every contribution follows them. A rejected shape is not a
gap waiting to be filled: a change to one of these decisions starts as a
**Proposal** issue that answers the reason the page gives.

## Start with an issue

| You have                             | Start with           |
| ------------------------------------ | -------------------- |
| a bug                                | a **Bug** issue      |
| a feature, an API or a design change | a **Proposal** issue |
| a typo, docs or maintenance          | a pull request       |

Every bug fix starts with an issue. Before writing the fix:

1. Open a **Bug** issue with the smallest example that reproduces it.
2. Confirm the behavior on the current `main`.
3. Create a branch from `main`, named for the issue:
   `fix/<issue>-<short-name>`.
4. Add a regression test that fails because of the reported behavior.
5. Implement the fix.
6. Run the suites, and the Gallery, of every host the change reaches.
7. Open a pull request against `main` that links the issue with
   `Fixes #<issue>`.

```bash
git switch main
git pull
git switch -c fix/142-button-disabled-state
```

The issue records the problem and its reproduction; the pull request records
the solution. A bug-fix pull request without an issue is not reviewed.

A **Proposal** issue comes first, agreed before any code, for a new or renamed
public API, a change to the host contract, a new dependency, a change to one
of the decisions in [Why StateUI is shaped this way](docs/concepts/why.md), or
another substantial design decision. Its branch is `feature/<issue>-<short-name>`.

A documentation-only correction, or repository maintenance that changes
nothing StateUI does, needs no issue and may go straight to a pull request
(`docs/<short-name>`, `chore/<short-name>`).

## Begin with evidence

Reproduce the behavior before changing it. A testable defect should have a
failing test that states the invariant. A native rendering or interaction issue
also needs a live Gallery check on the affected toolkit; a green core suite
proves only the contract it exercises.

## Change one vertical slice

A control, property, or event decision reaches every active layer together:

- Swift API and vocabulary;
- its `ElementContract` and the layer each member declares;
- every applicable host;
- focused core and host tests;
- the Gallery, on every host the change reaches;
- the handbook (`README.md`, `docs/`, and public `///` documentation).

Render `docs/platform-contract.md` and `docs/controls/` again in the same
slice. Every mark is the verdict of a test: a host's run of its suite with
`STATEUI_UPDATE_EXPORTS=1` writes them under `lib/StateUI/exports/marks/<host>/`,
and `STATEUI_UPDATE_DOCS=1 swift
test --filter ControlDictionaryTests` writes the documents from them. No mark
is written by hand.

Remove obsolete API, examples, and tests when the contract deliberately drops
the capability. Do not preserve aliases unless compatibility is an explicit
requirement.

## Keep the core platform-neutral

Code under `lib/StateUI/Core/Sources` and `lib/StateUI/StateUI.Host/Sources` does not
import Foundation or a platform UI framework. Each host is a sibling package of
its own - `lib/StateUI/StateUI.AppKit`, `lib/StateUI/StateUI.UIKit`, `lib/StateUI/StateUI.Android`,
`lib/StateUI/StateUI.WinUI`, `lib/StateUI/StateUI.GTK`, `lib/StateUI/StateUI.Web` - standing on the
host layer, with its build in `.scripts/<Platform>`. Swift written for one host alone stands under
that host's condition - `#if APPKIT`, `#if UIKIT`, `#if ANDROID`, `#if WINUI`,
`#if GTK`, `#if WEB` - which its builds define.

The core schedules nothing on Foundation's `Timer` or `RunLoop`, and nothing
on `DispatchQueue.main` but the one drain `UIThread.swift` posts there for a
process that turns that queue: nothing drains them on Android, on Windows or
in a browser. Work for the UI thread goes to `MainActor`, and a timer is
`Task.sleep` or `Ticker`. Memory allocated in Swift is freed in Swift - never
`strdup` and `free` - because several C runtimes can share a Windows process.

StateUI's core owns identity, diffing, state, journeys, and motion
descriptions. Hosts own native objects, platform callbacks, and display-frame
property motion. Keep renderers thin and derive richer behavior from StateUI
primitives where that produces one honest cross-platform contract.

## Write current documentation

README, `docs/`, and public API documentation are the handbook. Describe what
StateUI is now, why the current rule exists, and any current trap. Do not
narrate migration history or explain the API by comparison with another
framework.

Every public Swift declaration needs `///` documentation. Gallery pages use
minimal on-screen prose: show behavior directly and tell the user only what
they need to try.

## Test

Run the suite owned by the area while iterating, then every suite before
handing off a complete vertical change. In VS Code, run **StateUI: Run Tests**
once with each host this machine runs - AppKit, UIKit, Android and the Web on
a Mac. From a terminal, `.scripts/test-native.sh` runs the suites of the
library, the host layer, the conformance package, the AppKit host and the
applications on this Mac, `.scripts/UIKit/test-uikit.sh` the UIKit host's on a
simulator, `.scripts/Android/test-android.sh <serial>` the Android host's on a
device, and `.scripts/Web/test-web.sh` the Web host's:

```bash
.scripts/test-native.sh
.scripts/UIKit/test-uikit.sh "iPhone 18 Pro"
.scripts/Android/test-android.sh emulator-5554
.scripts/Web/test-web.sh
```

A plain `swift test` compiles no code under a host's condition, so it does not
test any host's half on its own.

Run the Gallery with **StateUI: Debug** on each host the change reaches. From a
terminal:

```bash
.scripts/AppKit/build-gallery-appkit.sh debug
.scripts/Android/run-app.sh apps/Gallery debug emulator-5554
```

Run one application build at a time. Concurrent application builds share Swift
object directories and can silently execute stale output.

Open every pull request against `main`. A release is a tag on `main`. A pull
request runs the core's workflows - `Core macOS`, `Core Windows` and
`Core Linux` - and each host's - `AppKit`, `UIKit`, `Android`, `WinUI`, `GTK`
and `Web`.

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
