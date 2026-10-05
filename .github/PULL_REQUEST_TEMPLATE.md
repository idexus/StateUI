## Issue

Fixes #

## What this changes


## Why


## Regression

<!--
For a bug fix: the regression test added for the linked issue. It fails
without this change and passes with it.
-->


## Checks

- [ ] The pull request targets `main`
- [ ] The change follows `docs/concepts/why.md` and brings back no shape it
      rejects
- [ ] A Bug or Proposal issue is linked with `Fixes #...`, unless this is a
      documentation-only or repository-maintenance change
- [ ] A bug fix includes a regression test that reproduces the linked issue
- [ ] **StateUI: Run Tests** passes on every host the change touches - AppKit,
      UIKit, Android, WinUI, GTK, Web (or `.scripts/test-native.sh` on a Mac)
- [ ] The Gallery was exercised on every affected host, where the behavior is
      visible or interactive
- [ ] Anything an author can reach has a `///` describing its StateUI semantics
- [ ] New or changed comments describe the current state, not how it got there
