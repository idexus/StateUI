# Web heads

A Web head is a WebAssembly module, `<Name>Web.wasm`, that the host's
JavaScript relay starts in a page.

## The build

`stateui build --host web` builds the module with the Swift SDK for
WebAssembly of the compiler's release - the one whose id ends in `_wasm`,
never its Embedded `_wasm-embedded` sibling, which StateUI is not written
for. The SDK names the build's context (builds.md); `stateui doctor --host
web` says where to get one that is missing.

A debug module keeps its DWARF, which the browser's debugger reads to stop
on a line of Swift; a release module is linked without it (`-Xlinker
--strip-debug`, HelloWorld's 14.5 MB rather than 23.7), as it is the page's
first download. The tool passes that flag to a release build itself: a
library's linker settings conditioned on a configuration reach a product in
every configuration under SwiftPM's build system, so the head's manifest
cannot say it.

## The page

The artifact is the page, laid beside the module (`WebPage`): `index.html`
from the host's template, `lib/StateUI/StateUI.Web/JavaScript/index.html`,
the relay `stateui-web.js` and its look `stateui-web.css`, the module, every
script of the head's `Platforms/Web/Page` - each loaded before the
application starts - and the application's `Resources/Images` as they are,
since a browser draws SVG. The template's marks are filled: the name the
page says as it loads - the head's `application-name`, else its `<title>`,
else the application's, a quote written as HTML's - the module, and a stamp,
the build's second, on every script's and the look's address so a browser
never shows an older build. The head's `Page/head.html` - a description, the
address it is found at, what a shared link shows - stands in the page as
written, after a `<title>` named after the application where it names none.
`stateui package --host web` lays the page in `artifacts/<Name>/Web`, a
folder any web server serves as it is.

## The page's server

`stateui run --host web` serves the page from its artifact while the run
lasts (`PageServer`, on SwiftNIO's HTTP/1, on macOS and Linux): GET and HEAD
of the files in the page's folder - a folder's `index.html`, the query
aside, the path percent-decoded - each answer typed by its file and saying
not to keep it (`no-store`), so the build shown is always the last. A path
leaving the folder, by `..` or by a link, is answered as missing, and any
other method is refused. A missing file is said in the run's output, but
for a picture asked for as a PNG, which the relay asks for before its SVG.
It listens on this machine alone; `--listen lan` shares the page with the
network and says the machine's addresses. The port is 8460 from run to run,
so the page's address - and what a browser keeps for it - stays the same; a
server another program holds on it on any interface leaves the run another
free port, and a port asked for with `--port` that is in use is refused.
The server stands before the run's `started` event names its address; the
run's stop closes it and its connections.

