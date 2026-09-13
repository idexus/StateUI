# Project structure and development

## Repository layout

```text
Package.swift                     StateUI core package and core tests
lib/StateUI/Sources/              platform-neutral StateUI
lib/StateUI/Tests/                core tests, fixtures, and shared test support
lib/StateUI.AppKit/               independent AppKit host package and tests
apps/Gallery/Sources/             platform-neutral Gallery application
apps/Gallery/Platforms/AppKit/    Gallery AppKit entry point
apps/Gallery/Tests/               Gallery acceptance tests
apps/HelloWorld/Sources/          small platform-neutral example application
apps/HelloWorld/Platforms/AppKit/ HelloWorld AppKit entry point
_old/                             inactive archive
```

The core never imports Foundation or a platform UI framework. Application code
may import Foundation. Platform frameworks remain inside host packages and
platform entry points.

## Gallery

Gallery is the acceptance surface for the active `HostContract`. Its examples
show behavior directly and keep on-screen prose to a title and, when needed,
one short instruction.

Across the catalog, applicable examples prove:

- a state read rebuilding only its reader;
- a host-carried binding updating without that rebuild;
- `Journey` and host-side motion.

Detailed teaching belongs in the Markdown documentation and public `///`
comments. A sample outside the active contract does not remain in the catalog.

## Build

The AppKit host requires macOS 14 or newer and a Swift 6 toolchain from Xcode.

Build the runnable Gallery bundle:

```bash
.scripts/build-gallery-appkit.sh debug
```

Build the smaller example:

```bash
swift build --package-path apps/HelloWorld --product HelloWorldAppKit
```

VS Code exposes Debug and Release F5 configurations for both applications.
The Gallery build task assembles its resources, icon, runtime libraries, and
ad-hoc signature.

## Test

Each suite lives beside the package whose behavior it verifies:

```bash
swift test
swift test --package-path lib/StateUI.AppKit
swift test --package-path apps/Gallery
```

Run all three in that order with:

```bash
.scripts/test-native.sh
```

The first suite covers core semantics and typed and Wire boundaries. The second
drives native AppKit objects. The third treats Gallery as application behavior
and compiles the documentation examples.

A passing unit suite does not prove native drawing or interaction. Exercise a
user-visible change in the running Gallery on the affected platform. Run only
one application build at a time because Swift build directories are shared by
the package graph.
