# Indexing

An editor's language server indexes an application's code as one host - the
variable `STATEUI_HOST` set on its process, and SourceKit-LSP's
`.sourcekit-lsp/config.json` beside each package naming where and for what it
builds. What that is the tool decides once (`IndexContexts`, `index/describe`,
`stateui index describe --host <host>`):

- each host indexes in a scratch folder of its own, `.build/<host>/index-build`,
  and plain Swift in `.build/index-build` - one folder for two hosts is two
  differently configured builds in one place;
- a host whose heads run elsewhere is indexed for that platform: UIKit for
  the iOS simulator - its triple and the SDK Xcode ships, which SourceKit-LSP's
  SwiftPM does not infer from the triple; Android and the Web with the Swift
  SDK of the compiler's release, `_android` and `_wasm` (never `_wasm-embedded`),
  and their triples;
- where that SDK is missing the context says why (`fallback`), and the code
  is indexed for this machine.

`index/clean` (`stateui index clean`) takes every index's scratch folder away
from the folders named, nothing else of their builds. The editor writes the
context into the server's file, keeping whatever else the file says, prepares
the index by building (`backgroundPreparationMode: build`), waits for a build
still running in a package's `.build` before it restarts the server, and
cleans through the tool.
