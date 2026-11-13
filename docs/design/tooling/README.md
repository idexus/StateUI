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
