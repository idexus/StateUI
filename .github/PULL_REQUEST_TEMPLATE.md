## What this changes


## Why


## Checks

- [ ] A proposal issue is linked above, or the change is small enough not to
      need one - see CONTRIBUTING.md
- [ ] `swift test --package-path src/Tests` passes
- [ ] `dotnet test src/Tests/StateUIRuntime.Tests` passes
- [ ] Anything an author can reach has a `///` saying what it does and which MAUI
      property it stands for
- [ ] New or changed comments describe the current state, not how it got there
- [ ] If the wire format changed: fixtures regenerated with
      `STATEUI_UPDATE_FIXTURES=1`, and the `.txt` diff read
