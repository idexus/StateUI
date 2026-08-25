# Contributing

Thank you for looking. This file is the short version; [README.md](README.md) is
the long one, and it is worth reading the section that covers whatever you are
about to touch.

## Licensing, in one paragraph

**You keep the copyright in what you wrote.** There is no assignment here, and
nothing changes hands. Everything you submit ships under the same
[Apache License 2.0](LICENSE) as the rest of the repository - section 5 of that
licence says so, and signing the CLA does not change it.

**One signature, once.** The first time you open a pull request, a bot will ask
you to sign [CLA.md](CLA.md) - a comment, one click, and it never asks again.
It grants the project a broad licence to your contribution, including the right
to release it under other terms later - which is what keeps a future change of
terms possible without having to find every past contributor and ask. The patent
grant in it says from your side what section 3 of the licence already says from
the project's. It does not take your copyright and does not stop you using your
own work anywhere else.

**An idea and its implementation are different things.** Copyright reaches the
expression, not the idea, the method or the interface behind it - so a proposal
describing what a change should do leaves the implementation to whoever writes
it, and costs the proposer nothing. Code is the other half: anything pasted into
an issue stays its author's and is NOT covered by the CLA, which the bot asks
for on a pull request and nowhere else. So a patch travels as a pull request,
where the licence and the patent grant come with it, and an idea travels as a
proposal, where one line of confirmation is all it needs.

**Every source file under `src/` starts with two lines**, and a new one is no
different:

```swift
// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0
```

You are the *and Contributors*, and that stays true without your name being
added anywhere or your copyright going anywhere - the first paragraph above is
what governs it. The notice is there for the file that travels ALONE: a package
manager hands somebody the whole checkout, and a file copied out of one carries
nothing else saying where it came from. `testEverySourceCarriesTheLicenceHeader`
names any that is missing it.

Two things under `src/` are deliberately without it: the templates under
`src/StateUI.Template/templates/`, whose files become the reader's own the
moment `dotnet new stateui` copies them, and a `Package.swift`, whose first line
belongs to SwiftPM. The gallery and the apps beside it are outside the rule for
the first of those reasons - `new-app.sh` copies parts of the gallery into every
new application.

The NAME is a separate matter from the code - see [TRADEMARK.md](TRADEMARK.md).

## Which branch

**Open pull requests against `main`** - the base GitHub already offers.

A merge there reaches nobody's machine by itself: the template and the
manifests pin the library by exact version, so applications move when they
choose a new version, not when `main` does. What guards `main` is the gate
every pull request passes - both suites and the four platform builds - not a
second branch. Any other branch you see is the maintainer's own working area,
with no role a contributor needs to know.

## Before you write code

Two lanes, and what decides between them is what the change TOUCHES.

**Open a proposal first** - an issue, the *Proposal* template - when the change:

- adds or renames anything an application can reach: a control, a modifier, a
  token, an act;
- touches the wire (`src/StateUI/Sources/Core/Wire.swift` and the fixtures
  beside the tests), which is a contract between two languages and two suites;
- adds a dependency or changes a build script;
- or runs past about fifty lines outside tests.

The answer is usually one comment, because most of it is not a matter of taste:
the API is MAUI's, camelCased, so a name is something to look up rather than to
argue about. What the proposal buys is that the answer arrives before the
weekend goes into it - and if you have already written the code, say so in the
proposal and link it.

**Straight to a pull request** otherwise: a typo, a documentation fix, a bug fix
with the test that catches it, a sample, or a modifier MAUI declares and this
library has not written down yet.

A proposal nobody answered is not a refusal. [SUPPORT.md](SUPPORT.md) is honest
about what one person can promise; a comment on the thread brings it back up.

## Before you open a pull request

Run both suites. They are two halves of one contract and a change can break
either:

```bash
swift test --package-path src/Tests             # the Swift half
dotnet test src/Tests/StateUIRuntime.Tests      # the C# half
```

In VS Code: **Test: all (Swift + C#)** in the Run panel.

To see a change in a real application:

```bash
cd apps/Gallery
dotnet build -c Debug -f net10.0-maccatalyst -r maccatalyst-arm64
```

**Build one application at a time.** MSBuild does not lock across processes and
the Swift step wipes and rewrites the module's object directory, so a second
build - or an F5 beside one - corrupts both. The symptom is
`Rename failed: …o.tmp -> …o: no such file or directory`.

### What the pull request itself will run

Four workflows, and the badges at the top of the README are theirs - the CLA
check above runs on every pull request as well:

| Workflow | Where | What it does |
|---|---|---|
| **Tests** | macOS | both suites |
| **iOS / Mac Catalyst** | macOS | the gallery, Release, both Apple targets |
| **Android** | macOS | the gallery, Release, both ABIs, Swift runtime packaged |
| **Windows** | Windows | the gallery's Windows head, and both suites again |

They run on every pull request against `main`, and again when the merge
lands. Three of the four you can reproduce on one Mac; Windows
is the one you cannot, which is the point: a change that compiles on a Mac can
still fail to link on Windows, and the Swift half is where that happens.

## The rules a pull request is measured against

Most of these are checked by a test rather than by review, and the test names
what is missing. Trust what it says.

**The API is MAUI's, in Swift.** Property names are MAUI's, camelCased, and
nothing is renamed, shortened or merged: `HorizontalOptions` is
`.horizontalOptions(.center)`, never `.center()`. Someone who knows MAUI must
never have to guess, and MAUI's own documentation stays the reference. Properties
are set by modifiers, not initializer arguments - only the value that gives a
control its purpose goes in the initializer. See
[The API is MAUI's](README.md#the-api-is-mauis).

**Everything an author can reach carries a `///`**, in English, saying what it
does and which MAUI property it stands for. `testEveryPublicApiIsDocumented`
reads every `.swift` file and fails naming the line; on the C# side an
undocumented public member does not compile, because CS1591 and CS1573 are
errors.

**A comment describes the CURRENT STATE, never the road to it.** What the thing
IS, WHY it is that way, and the trap where there is one - in the present tense.
Not "this used to be a string", not "until version 8 this was joined with
commas". The reason stays; the same fact told as a story goes.

**The wire is deterministic.** One session writes the same bytes in every run and
every process, so props and events are written sorted by name and nothing may
iterate a Dictionary or a Set into a message - Swift salts each dictionary with
its own storage address, so an unsorted write differs between two instances
inside one run.

**The library never imports Foundation.** Nothing under `src/StateUI/Sources`
does. `Timer` and `RunLoop` are banned everywhere - they hang off a run loop
nothing drains on Android or Windows; a timer is `Task.sleep` and the waker. An
application may import Foundation, but zones and locale are the host's to answer.

**Memory allocated in Swift is freed in Swift**, and native strings come back
into C# as `IntPtr`, never `string`. Every `@_cdecl` lives in
`src/StateUI/Sources/Bridge/Exports.swift`, in that one file.

**The dependency runs app to library, never the reverse.** The library must not
know about any application - that is what lets it be published alone.

## Fixtures

`src/Tests/fixtures/*.bin` is the contract between the two languages: Swift
writes them, C# applies them. The `.txt` beside each one is what review reads.

If a change is meant to alter the format, regenerate and then READ the diff of
the sidecars - that diff is the change, stated in words:

```bash
STATEUI_UPDATE_FIXTURES=1 swift test --package-path src/Tests
```

Then run the C# suite, which applies what Swift just wrote.

## Adding something

The recipes are in the README, and the guard tests name anything forgotten.

- **A control** - [Adding a control](README.md#adding-a-control). A struct under
  `Views/`, its own `…Properties` protocol, a line in `Style.swift`, a
  `Reconcile` case, an arm in `SwiftStyles`, a fixture case with its check on the
  C# side, and a gallery sample.
- **A property** - a modifier on the tier that matches the MAUI class declaring
  it, a line in the matching Reconcile, the modifier added to that control's
  fixture, and an entry in `SwiftStyles` under the same name.
- **A composed control** - [Composing views](README.md#composing-views). What it
  IS goes in the initializer without a default; everything optional is a modifier.
- **A sample** - a `SampleContent` under `apps/Gallery/Swift/Samples/<Group>/`
  plus one line in `Catalog.swift`. Its `static let code` is the sample's own
  code and must compile.

Nothing lists source files anywhere: SwiftPM globs, the build scripts glob, and
all of it recurses. A new file is picked up by both. A type used from another
file cannot be `private` - at file scope that means fileprivate.

## Housekeeping

- The working tree is **LF** on every machine; `.gitattributes` says so. A guard
  test reading sources as text fails incomprehensibly on CRLF.
- Forward slashes in MSBuild paths, always.
- A new file in the gallery is invisible to the test package until
  `rm -f src/Tests/.build/build.db src/Tests/.build/debug.yaml`.
- The C# tests run one class at a time; MAUI's statics are not synchronized.

## Reporting something instead

An issue that says what you did, what happened and what you expected is worth
more than a patch that guesses. If it is platform-specific, say which platform
and which version - most of the traps in this project are.

[SUPPORT.md](SUPPORT.md) is honest about what a report can expect in return,
which at this stage of the project is not much: one person reads them, and a
reply is not promised. A vulnerability goes through the private form
[SECURITY.md](SECURITY.md) names, never into a public issue.
