# Web host

The Web host renders a StateUI application in a browser's page, as the
browser's own elements. The application, the library and the host are one
WebAssembly module - Swift compiled with the Swift SDK for WebAssembly - which
applies the typed sparse patches of the
[host contract](../internals/host-contract.md) and calls the page's DOM
through a small JavaScript relay beneath it. The relay makes, places and
changes elements as Swift says and calls Swift back when one hears an event;
it decides nothing of StateUI's.

It presents the library's controls and pages, each the browser's own element
where the browser has one - `<button>`, `<input>`, `<select>`, `<progress>`,
`<img>`, `<canvas>`, `<iframe>`, a modal `<dialog>` - and StateUI's own
arrangement of them where it has none: a map is the application's, which it
registers with the host. Each stands in the look the browser gives it and the
light or dark appearance of the user's system, until the application gives it
a look of its own. The browser
lays them out: each child's margin, alignments and sizes are written as its
CSS, so it stands where StateUI places it on every host. It shows any other
control's name in red where the control belongs, so a gap is visible rather
than silent. The page the user sees names the browser's tab. A page is one
window, the browser's own: `openWindow` asking for another is refused with
`WindowError.unsupported`, as on a phone, and the inspector offers no window
of its own.

```text
lib/StateUI/StateUI.Web/
  Sources/StateUIWeb/        the host: its runtime, elements, registrations, layout and window
  Sources/CStateUIWeb/       the relay's functions, as the module imports them
  JavaScript/
    stateui-web.js           the relay, and the system interface a Swift program asks of its machine
    stateui-web.css          the look of the page's elements
    index.html               the page a head runs in
  Testing/                   a package of its own: the host's suite, compiled for WebAssembly, the page in
                             Node it runs over, and what it runs in a browser
.scripts/Web/
  run-app.sh                 builds an application's Web head, lays its page out, serves it and opens it
  page.sh                    lays an application's page out beside its module
  serve.py                   serves the page on this machine
  browsers.sh                lists the browsers installed, and opens a page in one
  deploy.sh                  builds it for release and lays the page in a folder of its own
  test-web.sh                runs the host's suite, or what of it needs a browser
  swift-sdk.sh               names the Swift SDK for WebAssembly of the compiler's release
apps/<App>/Platforms/Web/
  main.swift                 the application's Web head
  Page/                      what the application adds to its page: its scripts, and head.html
```

## Requirements

The host builds on macOS and on Linux:

- swift.org's Swift 6.4.0 toolchain, not Xcode's, first on `PATH`, and the
  Swift SDK for WebAssembly of the same release,
  `swift-6.4.0-RELEASE_wasm`, which `swift sdk install` installs
  ([Getting started with WebAssembly](https://www.swift.org/documentation/articles/wasm-getting-started.html));
  its `_wasm-embedded` sibling is Embedded Swift, which StateUI does not use;
- Python 3, which serves the page on this machine;
- a browser;
- Node.js 20 or newer for the host's own suite.

## The head

An application's Web head is an executable the browser runs: the page loads
the module and runs its `main`, which names the application and shows it in
the page. `main` returns; from then on the browser calls the application as
the user acts and as the display draws.

```swift quote
import NotesUI
import StateUIWeb

stateui_app_register()
StateUIWeb.run(name: "Notes")
```

`STATEUI_HOST=web` is what makes a build a Web one: the application's manifest
reads it, declares its `Platforms/Web` head and the module it makes, links the
application's own library into it rather than beside it - a page loads one
module - and defines the `WEB` compilation condition for every module of the
application; `lib/StateUI.Head` brings the `StateUIWeb` host to the head and
links it with an 8 MB stack. Swift written for this host alone stands under
`#if WEB`.

A new application made in `apps/` - `.scripts/new-app.sh` - has a Web head,
as HelloWorld does.

## The page

The page a head runs in is the library's `index.html`: it loads the relay and
the module, and shows the application's name while the module loads. The
head's `Page` folder - `apps/<App>/Platforms/Web/Page` - adds the
application's own to it. Each script there is laid beside the page and loaded
before the application starts ([Controls, acts, and events registered in
Swift](#controls-acts-and-events-registered-in-swift)). `head.html` is written
into the page's head as it stands: what a search engine reads of the page and
what a link to it shows - its description, the address it is found at, its
preview.

```html
<title>Notes - Plain notes, kept</title>
<meta name="application-name" content="Notes">
<meta name="description" content="Notes keeps what you write, on every device you use.">
<link rel="canonical" href="https://notes.example/">
<meta property="og:title" content="Notes - Plain notes, kept">
<meta property="og:image" content="https://notes.example/preview.jpg">
```

A `<title>` there names the page while the module loads, and what a link to
it shows; without one the page is named after the application. Once the
application runs, the tab names the page it shows beside the site's name the
head gives in `application-name` - "Home - Notes" - and the page alone where
the head gives none. The Gallery's describes StateUI at stateui.dev:
`apps/Gallery/Platforms/Web/Page/head.html`.

## Controls, acts, and events registered in Swift

An application extends the host from its Web head: registrations run before
`StateUIWeb.run`. A control of the application's own is an object that makes
and holds the page's element it shows, a `WebControl`; `StateUIControls.add`
says which contract it realizes, as on every host:

```swift quote
public static func add<Realized: ElementContract, Made: WebControl>(
    _ contract: Realized.Type,
    create: @escaping (WebReports<Realized>) -> Made,
    members: (WebRegistration<Realized, Made>) -> Void = { _ in })
```

The element a control shows is a `WebPageElement`: one of the browser's own,
or a custom element of the application's own JavaScript. A script in the
head's `Page` folder - `apps/<App>/Platforms/Web/Page/*.js` - is laid beside
the page and loaded before the application starts, so the element it defines
is the browser's own by the time a control makes one. The control tells the
element what it is through its attributes, and hears what it does through its
events:

```swift quote
@MainActor
final class WebGLCube3DView: WebControl {
    let element = WebPageElement(tag: "gallery-cube3d")

    var color = CubeColor.teal {
        didSet { element.setAttribute("color", String(color.rawValue)) }
    }
}

StateUIControls.add(Cube3DContract.self, create: { _ in WebGLCube3DView() }) { cube in
    cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
}
```

The host places, sizes and shows the element as it does its own, and lets
go of it with its element. The Gallery's cube - `<gallery-cube3d>`, WebGL 2
on a canvas of its own - is `apps/Gallery/Platforms/Web/`. An element tells
a number in its event's `detail` to `listen(_:_:)` handed a `Double`, and
words to `listen(_:words:)`.

### Children a control draws

A control may draw the children of one contract itself - a map draws its markers.
`children` names their contract and what of each the control realizes, and hands
it every such child, in the tree's order, whenever the element's children
change: one added, moved, taken away, or given another value. A child is a
`WebChild` - its values read as the types its contract declares, and its own
`reports` to raise its events on it - and stays the same child for as long as
it lives, so the control keeps what it drew for one by it. Such a child has no
element of its own on the page.

```swift quote
StateUIControls.add(MapContract.self, create: { reports -> MyMap in … }) { map in
    map.property(MapContract.region) { control, region in … }
    map.children(MarkerContract.self, members: [MarkerContract.location, MarkerContract.selected]) { control, markers in
        control.show(markers.map { marker in (marker, marker.value(MarkerContract.location)) })
        // the user taps one: marker.reports.raise(MarkerContract.selected)
    }
}
```

A `Map` is the application's on the Web - the browser has no map of its own -
registered the same way, with the provider and the key it needs. The
Gallery's is Google's: `<gallery-map>` over the Maps JavaScript API, its
markers the map's children. Its key is the application's own, never the
repository's - `Page/google-maps-key.js`, which git keeps out, sets
`StateUI.googleMapsKey`:

```javascript
StateUI.googleMapsKey = "your key";
```

### Acts and events

An act of the application's own is performed with `StateUIActs.add`, and an
act aimed at one of its controls with `StateUIActs.add(_:on:_:)`, which hands
the performer that control. An event of the application's own is declared
with `StateUIEvents.raises` and raised with `StateUIEvents.raise`; every
`HostEvents.on` subscription hears it.

What only a page's JavaScript reaches - its clipboard, its battery - the
application's own scripts reach for it. A script answers an act by name on
`StateUI.acts`, and tells with `StateUI.tell(name, words)`; Swift calls the
one with `StateUIScripts.call` - awaiting its promise, throwing why it broke -
and hears the other with `StateUIScripts.hear`:

```swift quote
StateUIActs.add(GalleryContract.readClipboard) {
    try await StateUIScripts.call("readClipboard")
}

StateUIScripts.hear("battery") { words in
    let (level, charging) = GalleryActs.battery(words)
    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
}
```

```text
// Page/gallery-acts.js
StateUI.acts.readClipboard = () => navigator.clipboard.readText();
navigator.getBattery?.().then((power) => {
    const tell = () => StateUI.tell("battery", `${power.level} ${power.charging}`);
    power.addEventListener("levelchange", tell);
    tell();
});
```

Words cross both ways: what an act takes and answers is written in them. A
page served over plain http has no clipboard - its act fails with the
reason - and a browser that says nothing of its battery answers none.

## Running

```bash
.scripts/Web/run-app.sh apps/HelloWorld
```

`run-app.sh` builds the head, lays its page out in the application's
`.build/web/site/<configuration>` - `index.html`, the relay and its
stylesheet, the module and the pictures in `Images/` - serves it at
`http://127.0.0.1:8460/` and opens it in the system's browser. The server
listens on every interface of this machine, so a phone or a tablet on its
network opens the page too. The port stays the same from run to run, so the
page's address, and what the browser keeps for it, does too; `--port <port>`
names another, and where the port is taken the server listens on a free one.
A server the script started for the application before is stopped first.
`release` builds the optimized module, `--browser <id>` opens another
browser - `.scripts/Web/browsers.sh list` lists them - and `--browser none`
none, and `--build-only` builds and lays the page out, serving nothing. Every
`STATEUI_` variable of the shell that runs it - `STATEUI_TALLY=1` - reaches
the application as a parameter of the page's address, which the application
reads as its environment.

What the application prints goes to the browser's console, and so does a
failure: one that stops the module also shows in red on the page.

In VS Code, with **Web** chosen in the status bar, a third item shows the
browser - click it, or run **StateUI: Select Browser**, which offers the
browsers installed on this machine, the system's own first. **StateUI: Debug**
builds and serves the page in a task whose terminal follows the server. In
Chrome, Edge or another of Chromium's browsers, VS Code's own JavaScript
debugger then starts the browser on the page, in a profile of its own: the
page's console is in the Debug Console, and closing the browser ends the
session. Any other browser, and **StateUI: Release**, the script opens itself.

## Deploying

```bash
.scripts/Web/deploy.sh apps/HelloWorld artifacts/HelloWorld/Web
```

`deploy.sh` builds the head for release, as `run-app.sh release --build-only`
does, and lays its page in the folder named, made anew: a folder any web
server serves as it is. **StateUI: Deploy** in the editor runs it for the
application chosen, and lays the page in `artifacts/<application>/Web` of the
folder that holds the application's `apps/`.

## Testing

```bash
.scripts/Web/test-web.sh
.scripts/Web/test-web.sh WebLayoutViewTests/testAReorderedLayoutStandsItsChildrenInTheirNewOrder
```

The suite is XCTest, in `lib/StateUI/StateUI.Web/Testing`, compiled for
WebAssembly and run in Node - Node 20 or newer - over a page with just enough
of a DOM: elements holding their children in order, their attributes, style
and listeners. The host's own relay stands beneath it, and the suite reads
what the page holds through functions of its own. It proves what the host
does to the page's elements, not how a browser draws them.

```bash
.scripts/Web/test-web.sh --browser
.scripts/Web/test-web.sh --browser Button TextField
```

What needs a browser's own page runs in Google Chrome or Chromium, headless -
or the browser `STATEUI_BROWSER` names: the conformance suite, with the user's
input as the browser takes it - every family, or those named - and the host's
tests that run a host, which `--browser --host` runs alone. A run with `STATEUI_UPDATE_EXPORTS=1` writes
each family's verdicts under `lib/StateUI/exports/marks/web`, and
`STATEUI_STALE_ONLY=1` runs only the families whose verdicts stand at another
revision.
