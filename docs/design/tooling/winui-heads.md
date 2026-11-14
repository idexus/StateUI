# WinUI heads

A WinUI head is a program SwiftPM builds on Windows, for the machine's own
architecture or the other one - on an ARM64 machine x86_64 too, which Windows
runs emulated - laid out self-contained: it runs with no package installed.

## The packages

What a WinUI head is built and laid out with comes from NuGet, pinned in the
tool alone (`WinUIPackages`): C++/WinRT, the Windows App SDK's WinUI,
Foundation and InteractiveExperiences, and the WebView2 WinUI's nuspec names.
A package stands in `NUGET_PACKAGES`, else the user's `.nuget/packages`, at
its pin. One missing is fetched from nuget.org, and its SHA-512 - by
Windows' own cryptography, CNG - is held to the one nuget.org's catalog gives
before a byte of it is unpacked; a package that differs is refused, nothing
of it laid.

## The projection

The host's relay includes the C++/WinRT projection of the Windows SDK,
WinUI, the Windows App SDK and WebView2, in
`lib/StateUI/StateUI.WinUI/.projection`, with WinUI's header for drawing with
DirectX into its elements beside it. Its `versions.txt` names the pins it
was made of; a build makes it again before SwiftPM compiles where a pin
changed. One application build at a time on a machine keeps two builds from
writing it at once.

## The head

`stateui build --host winui` builds the head with `STATEUI_HOST=winui` - the
toolchain's own architecture as it is, the other with `--arch` - and
publishes, from SwiftPM's folder, the program and every library and
package's resources beside it, never what only a build reads (`WinUIHead`):

- the Windows App SDK's runtime of the architecture, each component's
  `runtimes-framework/win-<arm64|x64>/native` merged into the folder;
- `<Product>.exe.manifest`, which Windows reads for an executable carrying
  none of its own, registering each component's classes ([the
  manifest](#the-manifest));
- `resources.pri`, WinUI's controls' own, where they find their resources;
- what each backend among the application's dependencies declares ([a
  backend's runtime](#a-backends-runtime));
- the Swift runtime of the architecture where it is not the toolchain's
  ([the Swift runtime](#the-swift-runtime));
- the application's `Resources/Images` as they are: WinUI draws SVG.

The program runs from the artifact, its own architecture's Swift runtime the
toolchain's on the search path. The executable is the one SwiftPM linked,
never rewritten: the manifest stands beside it.

## The manifest

A self-contained application has no package registering the Windows App SDK's
classes. The manifest registers what each component's `package.appxfragment`
declares - each in-process server's classes in the library holding them, each
proxy stub's class and interfaces - but the two proxy stubs a self-contained
application has no singleton for (`PushNotificationsLongRunningTask`, the
Widgets'), and gives the application per-monitor DPI and Windows 10 and later
(`WinUIManifest`).

## A backend's runtime

A backend whose engine needs files beside the application declares them in
its package, `lib/Backends/<Element>.WinUI/Packaging/runtime.txt`: a line a
file - the package, its path there, its path beside the application -
`{architecture}` in the package's path standing for Windows' word for the
architecture, `arm64` or `x64`, and `#` a comment. The package is one the
tool pins. Only a backend among the application's resolved dependencies
(`swift package show-dependencies`) contributes - never one because its
library happens to stand in SwiftPM's folder. A line of another shape, an
unpinned package, a path leaving its folder, or two backends laying one file
from different sources fail before anything is laid (`BackendRuntime`). The
web view's backend lays WebView2's component and loader.

## The Swift runtime

Another architecture's Swift runtime stands nowhere on the machine: the Swift
installer keeps each architecture's as a merge module in its
`Redistributables/<version>/rtl.shared.<amd64|arm64>.msm`. The tool reads the
module's `File` table and its cabinet through Windows Installer's `msi.dll`,
unpacks the cabinet with `expand.exe`, names each file as the table does,
and leaves Foundation's `plutil.exe` out - once a module, into the
application's `.build/stateui/caches`, copied from there by a build and a
package alike (`SwiftRuntime`).

## Packaging

`stateui package --host winui` lays the release artifact in `--output`, else
`artifacts/<Name>/WinUI`, made anew, and readies it for a machine with
nothing installed: the Swift runtime of its architecture even where it is
the toolchain's, and Visual Studio's app-local C++ runtime, which the Swift
runtime links - the newest MSVC redistributable's `Microsoft.VC*.CRT`,
found through `vswhere`.
