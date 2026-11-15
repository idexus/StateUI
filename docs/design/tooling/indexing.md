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

## Two windows on one package

A package holds one `.sourcekit-lsp/config.json`, so two windows indexing it
as two hosts would write it in turn, each server then building as its own
host in the other's scratch folder. A connection therefore holds the
packages it indexes as one host, its life long (`IndexLeases`,
`index/acquire`): a lock the system keeps on a file of the package and the
host under `index-leases` in the user's state folder - the build permit's
folder ([Builds](builds.md#one-application-build-at-a-time)) - let go of when
the connection's process ends, however it ends. Connections share a package
as one host; another host - plain Swift is one - is answered with the
package and the host that holds it (`conflict`), and the connection keeps
what it held. A lease whose process ended is taken away by the next that
looks.

Cleaning an index (`index/clean`) takes away only what no other connection
indexes, as any host - the same host too, whose server builds in that
folder: a package another connection holds is left as it stands and
answered with its host (`conflicts`); a connection cleans what it holds
itself. The editor then restarts no server and says which window holds it.

The editor takes the lease before it writes a package's configuration. Where
another window holds one as another host it writes nothing: a host chosen is
refused and the one before kept; a window opening on such a package works as
the host it is held as. The extension's own suite names a state folder of its
own (`STATEUI_STATE`), so it switches hosts on the checkout's packages while
a window of the user's works on them.
