# The tool

`stateui` is StateUI's developer tool: one implementation that creates,
builds, runs, tests and packages StateUI applications for the terminal,
automation and editors. It is the package `tools/StateUI.CLI`, apart from the
library: it links no StateUI runtime, stands in no application's graph, and
keeps its own dependencies.

```text
StateUICLI              the terminal: arguments, words, JSON, the editor service's entry
  |
StateUITooling          the work every client shares: ToolingService, processes, ...
  |
StateUIToolingProtocol  the messages a terminal's JSON and an editor's JSON-RPC carry
```

The terminal and an editor call the same `ToolingService`; the terminal
writes its result as words or as the message an editor receives.

- [Processes](processes.md): how a program runs, how it is stopped with
  everything it started, how its output is read.
- [The command line](command-line.md): what standard output holds and the
  statuses the tool ends with.
- [The protocol](protocol.md): the frames and messages an editor and the
  tool exchange.
- [Projects](projects.md): how a project, its applications and their
  checkouts are read.
- [Doctor](doctor.md): what the machine is checked for, and how the hosts'
  tools are found.
- [Builds](builds.md): what one build is and where it writes, one
  application build at a time on a machine, and the operation journal.
- [Pictures](pictures.md): which heads get their pictures drawn, and how
  an SVG, an application's pictures and a macOS icon are drawn.
- [Destinations](destinations.md): where a head runs - the iPhones, iPads
  and simulators - which one a run means, and the SDK each is built against.
- [Runs](runs.md): a run as one operation from its build to its
  application's end - on a simulator, on a device - and how a stop ends
  everything it started.
- [Android heads](android-heads.md): the Swift build of an ABI, the native
  libraries an APK ships, and the APK Gradle makes.
- [Apple bundles](apple-bundles.md): an Apple head's `Info.plist`, and what an
  AppKit bundle holds.
- [The repository's own work](repository.md): a host's suite, run as its CI runs it.
