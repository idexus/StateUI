# Web heads

A Web head is a WebAssembly module, `<Name>Web.wasm`, that the host's
JavaScript relay starts in a page.

## The build

`stateui build --host web` builds the module with the Swift SDK for
WebAssembly of the compiler's release - the one whose id ends in `_wasm`,
never its Embedded `_wasm-embedded` sibling, which StateUI is not written
for. The SDK names the build's context (builds.md); `stateui doctor --host
web` says where to get one that is missing.

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
