# Web host

The Web host renders a StateUI application in a browser's page, as the
browser's own elements. The application, the library and the host are one
WebAssembly module - Swift compiled with the Swift SDK for WebAssembly - which
applies the typed sparse patches of the
[host contract](../internals/host-contract.md) and calls the page's DOM
through a small JavaScript relay beneath it. The relay makes, places and
changes elements as Swift says and calls Swift back when one hears an event;
it decides nothing of StateUI's.

It presents the controls HelloWorld shows: a page, vertical and horizontal
stacks, text, buttons, text fields and pictures, each the browser's own
element - `<section>`, a flexbox, `<span>`, `<button>`, `<input>`, `<img>` -
in the look the browser gives it and the light or dark appearance of the
user's system, until the application gives it a look of its own. The browser
lays them out: each child's margin, alignments and sizes are written as its
CSS, so it stands where StateUI places it on every host. It shows any other
control's name in red where the control belongs, so a gap is visible rather
than silent. The page the user sees names the browser's tab.

```text
lib/StateUI/StateUI.Web/
  Sources/StateUIWeb/        the host: its runtime, elements, registrations, layout and window
  Sources/CStateUIWeb/       the relay's functions, as the module imports them
  JavaScript/
    stateui-web.js           the relay, and the system interface a Swift program asks of its machine
    index.html               the page a head runs in
  Testing/                   a package of its own: the host's suite, compiled for WebAssembly, and the
                             page in Node it runs over
.scripts/Web/
  run-app.sh                 builds an application's Web head, lays its page out, serves it and opens it
  serve.py                   serves the page on this machine
  browsers.sh                lists the browsers installed, and opens a page in one
  deploy.sh                  builds it for release and lays the page in a folder of its own
  test-web.sh                runs the host's suite
apps/<App>/Platforms/Web/
  main.swift                 the application's Web head
```

## Requirements

The host builds on macOS and on Linux:

- Swift 6.4 and the Swift SDK for WebAssembly of the same release,
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

## Running

```bash
.scripts/Web/run-app.sh apps/HelloWorld
```

`run-app.sh` builds the head, lays its page out in the application's
`.build/web/site/<configuration>` - `index.html`, the relay, the module and
the pictures in `Images/` - serves it at `http://127.0.0.1:8460/` and opens it
in the system's browser. The port stays the same from run to run, so the
page's address, and what the browser keeps for it, does too; a server the
script started for the application before is stopped first. `release` builds
the optimized module, `--browser <id>` opens another browser -
`.scripts/Web/browsers.sh list` lists them - and `--browser none` none, and
`--build-only` builds and lays the page out, serving nothing. Every
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
does to the page's elements, not how a browser draws them. The host has no
conformance driver yet: it makes no marks in the
[platform contract](../platform-contract.md).
