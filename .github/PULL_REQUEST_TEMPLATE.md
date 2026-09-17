## What this changes


## Why


## Checks

- [ ] A proposal issue is linked above, or the change is small enough not to
      need one - see the Proposal issue form
- [ ] **StateUI: Run Tests** passes as AppKit and as .NET MAUI (or
      `.scripts/test-native.sh`)
- [ ] `dotnet test lib/StateUI.Maui/Tests` passes
- [ ] Anything an author can reach has a `///` describing its StateUI semantics
- [ ] New or changed comments describe the current state, not how it got there
- [ ] If the wire format changed: fixtures regenerated with
      `STATEUI_UPDATE_FIXTURES=1`, and the `.txt` diff read
