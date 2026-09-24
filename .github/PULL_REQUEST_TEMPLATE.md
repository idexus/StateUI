## What this changes


## Why


## Checks

- [ ] A proposal issue is linked above, or the change is small enough not to
      need one - see the Proposal issue form
- [ ] **StateUI: Run Tests** passes as AppKit and as Android (or
      `.scripts/test-native.sh`)
- [ ] Anything an author can reach has a `///` describing its StateUI semantics
- [ ] New or changed comments describe the current state, not how it got there
- [ ] If the patch changed: fixtures regenerated with
      `STATEUI_UPDATE_FIXTURES=1`, and the diff read
