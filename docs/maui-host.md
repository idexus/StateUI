# MAUI host

The MAUI host renders a StateUI application with .NET MAUI controls on Android,
iOS, Mac Catalyst, Windows, and Linux. It runs the same application module as
the AppKit host. An ordinary `dotnet build` compiles the application's
`Sources/` once for each platform, and a thin C# layer applies what the Swift
side describes to MAUI controls.

The host is a foreign-language host. It calls the library's C exports in
`lib/StateUI/Sources/Bridge/Exports.swift` and applies the deterministic
[Wire encoding](host-contract.md#wire-encoding) of each render.

```text
lib/StateUI.Maui/
  Sources/    StateUI.Maui: the Wire reader, the renderer, windows and sessions
  Linux/      StateUI.Maui.Linux: the Linux platform over MAUI's GTK 4 backend
  Tests/      the host's suite
  Template/   StateUI.Maui.Template: the `dotnet new stateui-maui` template
.scripts/Maui/
  StateUI.targets              the MSBuild integration every MAUI head imports
  build-apple.sh               iOS and Mac Catalyst
  build-android.sh             Android
  build-windows.ps1, .cmd      Windows
  build-linux.sh               Linux
  run-app.sh, run-app.ps1      build and launch without a debugger
```

The [platform contract](platform-contract.md) and the
[control dictionary](controls/README.md) record the MAUI host member by member
in their first column. A mark there stands for the host's own suite, and the
Gallery's MAUI head shows the behavior.

## Platforms

| Platform | Target framework | Swift is compiled into | Travels with the application | Built on |
| --- | --- | --- | --- | --- |
| Android | `net10.0-android` | one `.so` per module and ABI (`arm64-v8a`, `x86_64`), through SwiftPM and the Swift SDK for Android | the Swift runtime and `libc++_shared.so`, inside the APK | macOS |
| iOS | `net10.0-ios` | one static archive per module, linked into the application binary | nothing: the OS carries the Swift runtime | macOS with Xcode |
| Mac Catalyst | `net10.0-maccatalyst` | the same as iOS | nothing | macOS with Xcode |
| Windows | `net10.0-windows10.0.19041.0` | one DLL per module, linked with the MSVC toolchain | the Swift runtime DLLs, beside the executable | Windows |
| Linux | `net10.0` | one `.so` per module, through SwiftPM with the host toolchain | the Swift runtime and a small C shim, beside the executable | Linux |

The minimum platforms are iOS 17, Mac Catalyst 17, Android API 28, and Windows
10.0.17763. A head's project lists only the frameworks its host can build:

- Android, iOS, and Mac Catalyst on macOS;
- Android and Windows on Windows;
- `net10.0` alone on Linux.

A Windows host builds the Android head without its Swift libraries: the targets
compile Swift for Android only on macOS.

## Requirements

| Tool | Needed for |
| --- | --- |
| .NET 10 SDK | every platform |
| MAUI workload: `dotnet workload install maui` | every platform except Linux, which has no workload |
| Swift 6.3 or newer | every platform. On macOS, Xcode's toolchain. On Windows, the swift.org toolchain plus Visual Studio Build Tools, because Swift links through the MSVC linker. On Linux, the swift.org toolchain |
| Xcode | iOS and Mac Catalyst |
| Android SDK with NDK 27 or newer, the Swift SDK for Android, and the swift.org toolchain whose build matches that SDK | Android |
| GTK 4.12 or newer | Linux: `libgtk-4-1` and `gir1.2-gtk-4.0` to run; `libgtk-4-dev`, `libgraphene-1.0-dev`, and a C compiler to build |

The CI workflows build with Xcode 26.6 and Swift 6.3.3; on Linux they use the
`swift:6.3.3-noble` image.

In VS Code, three extensions serve the host:

- **.NET MAUI** (Microsoft), for the device picker and the MAUI launches;
- **Swift** (swiftlang), for completion;
- **LLDB DAP**, for the Swift debugger.

The Linux C# launches use the C# extension's `coreclr` debugger.

## An application's MAUI head

An application keeps one head per host under `Platforms/`. HelloWorld's is the
smallest:

```text
apps/HelloWorld/
  Package.swift                  the application module, HelloWorldUI
  Sources/                       the application; every head compiles it
  Resources/
    AppIcon/                     appicon_bkg.svg and appicon_mark.svg
    Splash/                      splash.svg
    Images/                      the interface's artwork
  Platforms/
    AppKit/main.swift            the AppKit head
    Maui/
      HelloWorld.csproj          the MAUI head
      Host/App.cs                the MAUI application: every window a StateUIWindow
      Host/MauiProgram.cs        hosting and registrations
      Android/                   MainApplication.cs, MainActivity.cs, AndroidManifest.xml
      iOS/                       AppDelegate.cs, Program.cs, Info.plist
      MacCatalyst/               AppDelegate.cs, Program.cs, Info.plist
      Windows/                   App.xaml, App.xaml.cs, app.manifest
      Linux/Program.cs           the Linux entry point
      Properties/launchSettings.json
```

- **The project imports the StateUI targets.** In this repository the line is
  `<Import Project="../../../../.scripts/Maui/StateUI.targets" />`; a generated
  application imports `../../.scripts/Maui/StateUI.targets`. Those targets
  compile the StateUI library and the application module for the platform
  being built, attach the results to the build, and stop it when a Swift
  library is missing. Nothing else in the project names Swift.
- **The module is named after the project.** `HelloWorld.csproj` builds
  `HelloWorldUI`, and `Package.swift` names the same target and product. A
  manifest that does not mention the name stops the build with *"StateUI: the
  module name does not match"*. `StateUIAppModule` in the project chooses a
  different name.
- **Registration needs no C#.** The application module exports
  `stateui_app_register`, as described in
  [Getting started](getting-started.md#two-modules-and-one-registration-point).
  The build generates `StateUIAppInterop.g.cs`, whose module initializer hands
  that function to the host.
- **`Host/` is the application's C#.** `App.CreateWindow` returns a
  `StateUIWindow`, which asks the Swift side what to show.
  `MauiProgram.CreateMauiApp` calls `builder.UseStateUIApp<App>()` and holds
  the registrations described [below](#controls-acts-events-and-stores-registered-in-c).
  On Linux the same call comes from `StateUI.Maui.Linux`, so `Host/` compiles
  unchanged for every head.
- **Each platform folder compiles only into its own build.** The folders sit
  beside the project, and the project removes each one from every other
  platform's build.
- **Artwork is shared.** `Resources/` sits at the application's root beside
  `Sources/`. An SVG under `Resources/Images/` is rasterized at build time
  (`BaseSize` 24×24 unless the project gives it its own), and Swift names the
  rasterized file: `stateui_tile.svg` is `Image("stateui_tile.png")`. A picture
  drawn large gets its own `<MauiImage Update="…" BaseSize="…" />` line, so it
  is not stretched from a small raster. Linux copies the vectors under the same
  `.png` names.
- **`#if MAUI` marks Swift for this host alone.** Every Swift module the MAUI
  host compiles, the library and the application alike, is compiled with the
  `MAUI` condition. `NativeProjectTests` refuses any other mention of the host
  in `lib/StateUI/Sources` and in the applications' `Sources/`.
- **Both halves come from one place.** In this repository:
  - the head references `lib/StateUI.Maui/Sources/StateUI.Maui.csproj`, and
    on Linux also `lib/StateUI.Maui/Linux/StateUI.Maui.Linux.csproj`;
  - the manifest names the repository root with `.package(path: "../..")`.

  A generated application names either the packages or a checkout. The two
  halves speak one Wire version, so they always move together.

Some platform features need entries in the head itself:

- **More than one window on iOS and Mac Catalyst.** The Gallery's `Info.plist`
  declares `UIApplicationSceneManifest` with
  `UIApplicationSupportsMultipleScenes` and names `SceneDelegate`, a class in
  the head:

  ```csharp
  [Register(nameof(SceneDelegate))]
  public class SceneDelegate : MauiUISceneDelegate
  {
  }
  ```

  The class gives the plist a name the linker keeps. With the manifest and
  without the class, the first window opens blank. HelloWorld and the template
  declare neither.
- **Network access.** The Android manifests state
  `android.permission.INTERNET`, which only a Debug build receives
  implicitly. For its WebView sample the Gallery also sets
  `android:usesCleartextTraffic` on Android and
  `NSAllowsArbitraryLoadsInWebContent` on iOS.
- **Maps.** `builder.UseMauiMaps()` registers the Map control's handlers. The
  Gallery calls it everywhere except Windows, where the call throws during
  start-up, and Linux, whose backend has no map; there the Map node draws the
  unknown-control marker. On Android the map needs a Google Maps API key in the
  manifest's `com.google.android.geo.API_KEY` entry.

## Creating an application

### From the template

`StateUI.Maui.Template` writes a complete application: the layout above at
its own root, `.scripts/Maui/`, `.vscode/`, a solution, and a README. Install
it from a pack of this repository:

```bash
dotnet pack lib/StateUI.Maui/Template -c Release -o artifacts
dotnet new install artifacts/StateUI.Maui.Template.0.3.1.nupkg
```

Create an application built against a StateUI checkout, outside that checkout:

```bash
cd ~/src
dotnet new stateui-maui -n Notes --stateui-path ~/src/StateUI
```

Add `--appkit` for a native macOS head beside the MAUI one. The AppKit host
always comes from a checkout, so `--appkit` needs `--stateui-path`, and a
manifest generated without it stops with an `#error` that says so.

```bash
dotnet new stateui-maui -n Notes --stateui-path ~/src/StateUI --appkit
```

- **The name.** Name the application with letters and digits, starting with a
  letter. It becomes:
  - the project, the C# namespace, and the process;
  - the Swift module (`NotesUI`);
  - the lower-cased application id (`com.example.notes`).

  Without `-n`, the current directory's name is used.
- **The checkout.** `--stateui-path` takes an absolute path to a checkout whose
  directory is called `StateUI`. SwiftPM identifies a path dependency by its
  last path component, and the application depends on the product by that bare
  name. With it:
  - the project references the host's C# projects in the checkout;
  - `Package.swift` names the checkout with `.package(path:)`;
  - `StateUIPackagePath` tells the Swift build where it is.
- **The package route.** Without `--stateui-path`, the application takes
  `StateUI.Maui` and `StateUI.Maui.Linux` 0.3.1 from NuGet, and the Swift half
  from `https://github.com/idexus/StateUI.git` at exactly `0.3.1`. That route
  resolves only once release 0.3.1 is tagged and its packages are published.
  Until then, create applications with `--stateui-path`.
- **Reinstalling.** Before installing a rebuilt template of the same version,
  remove the previous one with `dotnet new uninstall StateUI.Maui.Template`.

The generated README describes the application's own builds; its source is
`lib/StateUI.Maui/Template/templates/StateUIStarter/README.md`.

### In this repository

An application inside this repository is wired to it by relative paths rather
than to packages. `.scripts/new-app.sh Notes` creates `apps/Notes/` in
HelloWorld's layout and registers its MAUI project in `StateUI.slnx`. On
Windows the same script is `.scripts\new-app.ps1 -Name Notes`, and in VS Code
it is the task "New app (in apps/)". The name rule is the template's.

## Building and running

These commands build the Gallery from the repository root. Every head builds the
same way from its own `Platforms/Maui` directory.

```bash
# Mac Catalyst
dotnet build apps/Gallery/Platforms/Maui -f net10.0-maccatalyst

# iOS Simulator: a plain net10.0-ios build targets the simulator
dotnet build apps/Gallery/Platforms/Maui -f net10.0-ios

# Android: build, deploy to the selected emulator or device, and start
dotnet build apps/Gallery/Platforms/Maui -f net10.0-android -t:Run

# Linux: the only framework a Linux host builds
dotnet build apps/Gallery/Platforms/Maui
```

```powershell
# Windows
dotnet build apps\Gallery\Platforms\Maui -f net10.0-windows10.0.19041.0
```

- **iOS devices.** A device build names `-r ios-arm64` and needs a signing
  identity; the simulator needs none.
- **Windows.** Do not pass `-r` on Windows. The project picks the host
  architecture itself, and a runtime identifier given on the command line also
  reaches the Android target's restore, which the project lists there too.
- **Linux.** In a head's directory, `dotnet run` builds and starts it.

The run scripts build, launch without a debugger, and return once the process
exists:

```bash
.scripts/Maui/run-app.sh maccatalyst
.scripts/Maui/run-app.sh ios Release
.scripts/Maui/run-app.sh linux
.scripts/Maui/run-app.sh ios apps/HelloWorld/Platforms/Maui/HelloWorld.csproj
```

```powershell
.scripts\Maui\run-app.ps1
.scripts\Maui\run-app.ps1 -Configuration Release -Project apps\HelloWorld\Platforms\Maui\HelloWorld.csproj
```

`run-app.sh` reads its arguments by shape, in any order:

- a platform: `ios`, `maccatalyst`, or `linux`;
- a configuration: `Debug` or `Release`;
- the path of a project.

Without a project it runs the Gallery in this repository, and the one
`Platforms/Maui/*.csproj` in a generated application. It stops a previous
instance first.

- **iOS.** It boots the newest installed iPhone simulator when none is
  running, then installs and launches the application.
- **Linux.** The application's output goes to `${TMPDIR:-/tmp}/stateui-run.log`.
- **In a generated application.** NuGet does not carry the execute bit, so
  there run the script as `bash .scripts/Maui/run-app.sh`.

The Swift half follows MSBuild's configuration: `-c Debug` compiles it without
optimization and with symbols, `-c Release` optimizes it. The targets also
accept:

| Property | Effect |
| --- | --- |
| `-p:SwiftConfig=release` | an optimized Swift half inside a Debug build, for profiling |
| `-p:SkipSwiftBuild=true` | a C#-only rebuild over a Swift build that already exists; on Apple a cold `obj/` then fails at the link |
| `-p:SwiftDebugFormat=codeview` | Windows only: Swift debug information for Visual Studio instead of LLDB |

- **The first build.** It compiles the whole library once into the head's
  `obj/stateui/`. Every later build compiles only what changed, and the Swift
  step runs again when a `.swift` file in either module changes.
- **One build at a time.** Two builds share and rewrite the same Swift object
  directories, and the second can silently run stale output.

## Debugging in VS Code

`.vscode/launch.json` groups its entries as "1 AppKit", "2 MAUI", and "3 tests".

| Goal | Configuration |
| --- | --- |
| The AppKit host | "Debug Gallery (AppKit)", "Debug HelloWorld (AppKit)", and their Release entries |
| Any MAUI platform except Linux, C# | "Debug app (C#)" |
| Any MAUI platform except Linux, the Release build | "Launch app (Release)" |
| iOS Simulator, Swift | "Debug app (Swift)" |
| Windows, Swift | "Debug app (Swift)" |
| Mac Catalyst, C# and Swift | "Debug app (C# + Swift, Mac Catalyst)" |
| Linux, C# | "Debug app (Linux)" |
| Linux, the Release build | "Launch app (Release, Linux)" |
| Linux, Swift | "Debug app (Swift, Linux)" |
| Windows, C# and Swift in one session | Visual Studio, with `SwiftDebugFormat=codeview` |
| Android, or any physical device, Swift | not available: LLDB here reaches only local processes |
| The suites | "Test: all (Swift + C#)", "Test: C#", "Test: C# (debug)" |

- **"Debug app (C#)" and "Launch app (Release)" name no project.** ".NET MAUI:
  Select Startup Project" chooses the head, and the status bar chooses the
  device. They build Release only because `.vscode/settings.json` sets
  `maui.configuration.useLaunchJsonConfigurations`; without it the extension
  builds Debug. On Windows the Release entry names its executable,
  `apps/Gallery/Platforms/Maui/bin/Release/net10.0-windows10.0.19041.0/Gallery.exe`.
- **The Swift attach entries attach by process name.** In this repository that
  name is `Gallery` (`Gallery.exe` on Windows). The Linux entries start
  `apps/Gallery/Platforms/Maui/bin/<Configuration>/net10.0/Gallery`. A
  generated application's `.vscode` names its own project instead.
- **Attaching stops the application; press Continue.** Never add `--continue`
  to an attach command: lldb-dap registers breakpoints while the process is
  stopped.
- **iOS Simulator.** The simulator's watchdog kills an application a debugger
  holds stopped. So "Debug app (Swift)" first launches the application without
  a debugger, through the task "Run app (no debugger)", and attaches afterwards.
- **Mac Catalyst.** In the compound, C# launches the application and Swift
  attaches once the task "Wait for app startup" finds the process. The two
  sessions stay separate: stepping in C# does not enter Swift.
- **Windows.** A process accepts one native debugger. VS Code therefore debugs
  Swift and C# in separate sessions. Visual Studio debugs both in one, with the
  `"nativeDebugging": true` profile in `Properties/launchSettings.json` and a
  CodeView build. DWARF stays the default because LLDB reads it; a Debug build
  links with lld-link to keep the DWARF sections LLDB needs.
- **Linux.** Ubuntu and Debian set `kernel.yama.ptrace_scope = 1`, so the Swift
  entry launches the application under LLDB instead of attaching. C#
  breakpoints do not bind in that session.

Several tasks in `.vscode/tasks.json` serve the MAUI host:

- **Builds:**
  - "Build (debug)" prompts for a target framework;
  - "Build app (Linux)" and "Build app (Release, Linux)" build the Linux head.
- **Launches and diagnosis:**
  - "Run app (no debugger)" and "Run app (Release, no debugger)" call the run
    scripts;
  - "Diagnose native build" runs `StateUIDiagnose`, described under
    [Troubleshooting](#troubleshooting).
- **Cleaning:**
  - "Clean native artifacts" removes the head's `obj/stateui`;
  - "Clean app (everything)" removes its `obj/`, its `bin/`, and the
    application's `.build/`;
  - "Clean all (app and library)" also removes the host projects' `obj/` and
    `bin/` and the root `.build/`.
- **Tests:** "Test StateUI.Maui" runs the C# suite, and "Test (update wire
  fixtures)" regenerates the Wire fixtures and then runs it.
- **New applications:** "New app (in apps/)".

The build and clean tasks name the Gallery's head. A generated application's
`.vscode` names its own, and with `--appkit` it adds "Debug app (AppKit)" and
"Release app (AppKit)".

## Controls, acts, events, and stores registered in C#

An application extends the host from `Host/MauiProgram.cs`. Registrations run
in `CreateMauiApp`, before the first render. Each name carries the
application's own prefix, such as `Notes.`, so it never meets a name the host
adds later. Registering a name again replaces the earlier registration. The
registries live in `StateUI.Maui.Rendering`, and the Wire values in
`StateUI.Maui.Protocol`.

```csharp
using StateUI.Maui.Hosting;
using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

namespace Notes;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        MauiAppBuilder builder = MauiApp.CreateBuilder();
        builder.UseStateUIApp<App>();

        // StateUIControls.Add(…), StateUIActs.Add(…), StateUIEvents and
        // StateUIStores registrations go here.

        return builder.Build();
    }
}
```

The Swift half of each registration is ordinary StateUI API. Only the
registries on this page are specific to the MAUI host; the AppKit host has no
equivalent. The Gallery's "C# interop" group, compiled under `#if MAUI`, shows
every kind of registration working.

### A control

`StateUIControls.Add` names an application's own MAUI view under a node type:

```csharp
public static void Add<TControl>(
    string type,
    Func<StateUIRaise, TControl> create,
    Action<TControl, SwiftNode>? apply = null,
    IReadOnlyDictionary<string, BindableProperty>? properties = null,
    Action<TControl, View?>? content = null)
    where TControl : View
```

- **`create`** makes the control once per element. It wires the control's
  events through the `StateUIRaise` it receives:
  `raise(sender, eventName, params SwiftWireValue[] payload)`.
- **`apply`** runs on every message that touches the control and reads only
  what arrived: an absent property did not change.
- **`properties`** declares properties backed by a `BindableProperty`, by Wire
  name. The renderer assigns them, and styles, visual states, and journeys
  reach them. See [A control's own properties](#a-controls-own-properties).
- **`content`** places the one child view the Swift side describes into the
  control.

The renderer keeps a registered control between renders by identity, and
applies the shared view properties after `apply`: margins, opacity, sizing,
gestures, focus, and frame reports. A node type with no registration draws the
unknown-control marker.

`TrafficLight` below is the application's own MAUI view, with a `Phase`
property, a `LightTapped` event, and a `Flash` method:

```csharp
StateUIControls.Add("Notes.TrafficLight",
    create: raise =>
    {
        var light = new TrafficLight();
        light.LightTapped += (_, index) =>
            raise(light, "lightTapped", SwiftWireValue.Of(index));
        return light;
    },
    apply: (light, node) =>
    {
        if (node.GetString("phase") is string phase)
        {
            light.Phase = phase;
        }
    });

StateUIActs.Add("Notes.FlashLight", call =>
{
    if (StateUIActs.TargetOf(call) is TrafficLight light)
    {
        light.Flash(call.GetInt(1) ?? 1);
    }

    return [];
});
```

The Swift half describes the same node type:

- it writes the property with `setValue`;
- it hears the event with `onEvent`;
- it aims the act at the control with an
  [`Aim`](interaction-and-actions.md#aims-and-control-methods).

```swift
extension NodeType {
    static let trafficLight = NodeType("Notes.TrafficLight")
}

extension Prop {
    static let lightPhase = Prop("phase")
}

extension Event {
    static let lightTapped = Event("lightTapped")
}

extension Act {
    static let flashLight = Act("Notes.FlashLight")
}

struct TrafficLight: View {
    var node = Node(type: .trafficLight)

    func phase(_ value: String) -> Modified {
        setValue(.lightPhase, .string(value))
    }
}

extension Aim where Target == TrafficLight {
    func flash(times: Int) async throws {
        try await stateUICall(.flashLight, [try target, .number(Double(times))])
    }
}

struct Crossing: ContentView {
    @Aim(TrafficLight.self) private var light
    @State private var phase = "red"
    @State private var taps = 0

    var content: any View {
        VStack {
            Label("Tapped \(taps) times")
            TrafficLight()
                .phase(phase)
                .aim(light)
                .onEvent(.lightTapped) { _ in taps += 1 }
            Button("Flash").onClicked { try await light.flash(times: 3) }
        }
    }
}
```

`Aim.target` puts the control's identity in argument 0, and
`StateUIActs.TargetOf` turns it back into the control. `TargetOf` answers null
when the control has left the tree before the host performs the act.

A Swift `Style` can target the control once its Swift struct conforms to
`StyleTarget`. Styles resolve on the Swift side, so the control arrives with
the style's values already among its own; the C# registration needs nothing
for it.

### A control's own properties

A property backed by a `BindableProperty` can be declared instead of applied
by hand. The renderer then assigns it whenever a message carries it, and a
host-carried state can drive it:

```csharp
StateUIControls.Add("Notes.Gauge",
    create: _ => new Gauge(),
    properties: new Dictionary<string, BindableProperty>
    {
        ["level"] = Gauge.LevelProperty,
    });
```

```swift
extension NodeType {
    static let gauge = NodeType("Notes.Gauge")
}

extension Prop {
    static let gaugeLevel = Prop("level")
}

struct Gauge: View {
    var node = Node(type: .gauge)

    func level(_ state: Binding<Double>) -> Modified {
        setValue(.gaugeLevel, on: state, mode: .inOut, kind: .property)
    }
}

struct Dashboard: ContentView {
    @State private var level = 0.25

    var content: any View {
        VStack {
            Gauge().level($level)
            Button("Fill").onClicked { level = 1 }
        }
    }
}
```

Handing `$level` to the control makes the gauge a host-carried reader. A write
to `level`, and its journey, reaches the control without rebuilding
`Dashboard`; see [Motion and journeys](motion-and-journeys.md).

### An act

`StateUIActs.Add` registers a function that Swift calls by name with
`stateUICall` or `stateUISend`. There are two overloads:

```csharp
public static void Add(string name, Func<HostActCall, Task<SwiftWireValue[]>> performer)
public static void Add(string name, Func<HostActCall, SwiftWireValue[]> performer)
```

```csharp
StateUIActs.Add("Notes.BatteryLevel",
    call => [SwiftWireValue.Of(Battery.Default.ChargeLevel)]);

StateUIActs.Add("Notes.Export", async call =>
{
    string location = await Exporter.SaveAsync(call.GetString(0) ?? "");
    return [SwiftWireValue.Of(location)];
});
```

- **Where it runs.** A performer runs on the thread MAUI draws on, and an
  async one is awaited there.
- **Its values.** It reads its arguments with the typed accessors of
  `HostActCall`: `GetString`, `GetDouble`, `GetInt`, `GetBool`, `GetName`,
  `GetEnumeration`. It answers with values built by `SwiftWireValue.Of`,
  `OfMember`, or `OfValues`, and answers empty when it has nothing to say.
- **Failure.** An exception fails the act: the awaiting Swift handler throws
  `StateUIError` with the exception's message.
- **Scope.** A registration never shadows an act of the host's own.

The Swift half is under
[Host-extension actions](interaction-and-actions.md#host-extension-actions).

### An event without a control

`StateUIEvents.Raise` pushes a named event that belongs to no element, such as
a battery or connectivity change:

```csharp
Battery.Default.BatteryInfoChanged += (_, e) =>
    StateUIEvents.Raise("Notes.BatteryChanged", SwiftWireValue.Of(e.ChargeLevel));
```

`Raise` is safe from any thread. It drops an event nobody subscribed to, and
one raised before the first interface exists. The Swift side subscribes with
`HostEvents.on`; see
[Host-extension events](interaction-and-actions.md#host-extension-events).

### A persistent store

State kept with `@State(persistentKey:)` goes to the platform's own settings
store unless the application names another. `StateUIStores.Add` registers an
`IPreferences` under a name:

```csharp
StateUIStores.Add("Notes.Json", new JsonPreferences(path));
```

The application selects it in its `init` with
`application.persistentStorage = PersistentStorage("Notes.Json")`. Here
`JsonPreferences` stands for the application's own `IPreferences`
implementation.

- **What it stores.** The store holds four value types: `bool`, `long`,
  `double`, and `string`.
- **When to register.** Before the first render. The first render reads the
  store once, and a name that resolves to nothing by then is reported, while
  the kept states stay at their declared values.

See [Persistent state](state-and-reactivity.md#persistent-state).

### Placing a Swift tree inside a C# page

`StateUIHost` is a MAUI `ContentView` whose content comes from the Swift tree,
for a page C# owns. A process renders one Swift tree, so it holds one
`StateUIHost`, and never one beside a `StateUIWindow`.

## Lists: `ItemsView`

`ItemsView` is the MAUI host's list. It shows a collection of identified items
in a scroller and describes only the items in view: however long the
collection, the tree holds the items the reader can see and a margin of six
slots either side. It is compiled for the MAUI host alone, so an application
writes it under `#if MAUI`. The AppKit host has no `ItemsView`; there the type
does not exist, and using it is a compile error.

```swift
#if MAUI
struct Library: ContentView {
    @State private var chosen: String?

    let files = ["Notes.md", "Budget.numbers", "Trip.key", "Photos"]

    var content: any View {
        Grid {
            ItemsView(files) { file in
                Label(file)
                    .padding(14, 10)
                    .background(chosen == file ? .cornflowerBlue : .transparent)
            }
            .selection($chosen)
        }
        .rows(.fill)
    }
}
#endif
```

`ItemsView` is a composition of controls every MAUI platform already renders: a
`ScrollView` holding an `AbsoluteLayout` whose length is computed, with each
item in view placed in it by arithmetic. Nothing about it crosses the Wire that
a `ScrollView` and an `AbsoluteLayout` do not already carry. From the outside it
is a scroller, so an act aimed at it takes an `Aim<ScrollView>`.

The initializer is the item template, run for the items in view. An element is
its item's identity, so elements are distinct; `ItemsView(files, id: \.path)`
names the distinct part of elements that repeat or are not `Hashable` whole.

A list is bounded across its axis, as any scroller is. A star row of a `Grid`,
or a `.height`, bounds a list that runs down. In a bare stack a list is given
the length of all its items, describes every one of them, and has nothing left
to scroll.

### Item length and orientation

The list works out where each item sits instead of laying every item out, so it
knows an item's length before it describes one. By default,
`.itemSizing(.uniform)`, the first item placed is measured and its length
answers for every item: the run is the count times one number, and a hundred
thousand items cost what ten do. `.itemSize(_:)` states the length in device
units instead, which also makes an item's offset arithmetic: item 500 of a list
of `.itemSize(44)` starts at `500 * 44`.

`.itemSizing(.individual)` measures every item, filed under its identity, for
items whose lengths differ: a feed, a chat, a run of tags. The run is then
worked out item by item, which suits tens or hundreds of items. An item that has
never been in view has not been measured, and the run's length is an estimate
until it has. The items before the reader have been measured, so nothing in view
shifts as the rest of the run is worked out.

```swift
#if MAUI
struct Tags: ContentView {
    let tags = ["State", "Binding", "Journey", "Engine", "Motion", "Placement"]

    var content: any View {
        ItemsView(tags) { tag in
            Label(tag).padding(14, 0)
        }
        .orientation(.horizontal)
        .itemSizing(.individual)
        .height(40)
    }
}
#endif
```

`.orientation(.horizontal)` runs the list across with the same arithmetic on
the other axis: an item takes the list's whole height, and its length is a
width. A list turned round forgets every length it measured along the other
axis and measures its slots again.

### Headers, footers, and groups

`.header(_:)` and `.footer(_:)` scroll with the items, before and after them.
`.emptyView(_:)` stands between them while the list has nothing to place.

`ItemsView(groups:)` takes an array of `ItemsGroup` values. A group's header and
footer are slots in the same run as its items. Each kind is measured once for
the whole list, so every group's header has one shape, and every footer
another. A group given no footer has no footer slot, and its items close up.

```swift
#if MAUI
struct Shelves: ContentView {
    struct Shelf {
        let name: String
        let items: [String]
    }

    let shelves = [
        Shelf(name: "Fruit", items: ["Apple", "Pear", "Plum"]),
        Shelf(name: "Bakery", items: ["Rye loaf", "Bagel"]),
    ]

    var content: any View {
        ItemsView(groups: shelves.map { shelf in
            ItemsGroup(shelf.items) { item in Label(item) }
                .id(shelf.name)
                .header(Label(shelf.name))
                .footer(Label("\(shelf.items.count) items"))
        })
    }
}
#endif
```

An item's identity is written under its group's `.id(_:)`, so two groups can
hold equal elements. A group without an `id` is identified by its position.

### Selection

`.selection(_:)` takes a binding to the chosen identity, and the binding's type
is the mode. With `Binding<Id?>` one item is chosen, and a tap on the chosen
item clears it. With `Binding<Set<Id>>` each tap adds or removes the item
tapped. A list without a selection answers no tap. How a chosen item looks is
the template's: it reads the state the binding writes.

### Loading at the end

`.onEndReached(within:_:)` runs when the reader is within `within` items of the
end, counted after the last item in view; a group's header and footer are not
items. `0`, the default, runs as the last item comes into view. The question is
asked when the slot at the top changes, and when the scroller or the run is
measured, so a batch shorter than the view asks again until the list outgrows
it. The handler runs more than once while the reader stays near the end, so it
guards on what it has already asked for.

```swift
#if MAUI
struct Feed: ContentView {
    @State private var count = 30
    @State private var loading = false

    var content: any View {
        ItemsView(0..<count) { number in
            Label("Item \(number + 1)")
        }
        .onEndReached(within: 5) {
            guard !loading else { return }

            loading = true
            try await Task.sleep(for: .milliseconds(400))
            count += 30
            loading = false
        }
    }
}
#endif
```

### Scrolling

`.scrollOffset(_:)` carries the list's offset on a `Binding<Point>`, both ways:
the host writes the reader's scrolling into it, and a write moves the list. The
list's own arithmetic arrives rather than travels, and its scroller carries
`Motion.none`, so a plain write is a jump and a journey with a law glides:

```swift
#if MAUI
struct Numbers: ContentView {
    @State private var offset = Point.zero

    var content: any View {
        VStack {
            Button("Row 500").onClicked {
                try await $offset.journey.move(to: Point(0, 500 * 44), .eased(300, .cubicOut))
            }

            ItemsView(0..<1_000) { number in
                Label("Row \(number)")
            }
            .itemSize(44)
            .scrollOffset($offset)
            .height(400)
        }
    }
}
#endif
```

Scrolling renders nothing by itself. The offset is host-carried state, and the
list follows it with an engine that writes which slot is at the top only when
that slot changes. The list's body reads that slot and describes the new
window: once per item crossed, never once per frame. `.aim(_:)` puts the
scroller in an author's hands for an act.

### What it costs

An item that scrolls out of the window leaves the tree, and its own `@State`
leaves with it. The host keeps the item's control and gives it to the next item
of the same shape, but nothing of the item's state survives. What must outlive
the window, such as a half-typed edit or whether an item is expanded, belongs
in the page, keyed by the item.

Items arrive; they do not travel. A control is handed from the item that left
to the item that arrives, so a law on an item's root would walk the new item's
contents across the screen while the reader scrolls. The list therefore writes
`Motion.none` on each item's root unless the author wrote a law there. A law is
per node and never inherited: what an author writes inside an item travels as
the author says, and a law on the root is left alone.

## Linux

Linux has no MAUI workload. Its head is a plain `net10.0` executable drawn by
`Microsoft.Maui.Platforms.Linux.Gtk4`, MAUI's GTK 4 backend from
dotnet/maui-labs. That backend is a preview package, which `StateUI.Maui.Linux`
pins at `0.1.0-preview.12.26421.1` together with its Essentials package.

- **The project decides by host.** On a Linux host:
  - the head has a single `<TargetFramework>net10.0</TargetFramework>`, which
    is what lets `dotnet run` start it without a framework named;
  - `UseMaui` and `SingleProject` stay off;
  - MAUI arrives as package references at 10.0.41, the version the backend is
    built against, where the other platforms use 10.0.100;
  - the usings the workload would inject are written as `<Using>` items.

  Every Linux condition asks for the host OS, because plain `net10.0` has no
  platform identifier.
- **`StateUI.Maui.Linux` is the platform.** A head references it on Linux
  only. It answers `builder.UseStateUIApp<App>()` there, and it supplies what
  the backend leaves open:
  - styling, gestures, scrolling, and measurement;
  - dispatching, navigation teardown, transforms, and Essentials;
  - the frame clock, the window icon, and the desktop's light or dark choice;
  - the overlay the inspector docks in.
- **The entry point** is `Linux/Program.cs`:

  ```csharp
  using System.Runtime.Versioning;
  using StateUI.Maui.Hosting;

  [assembly: SupportedOSPlatform("linux")]

  namespace Notes;

  public class Program : StateUIApplication
  {
      protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();

      public static void Main(string[] args) => Start<Program>(args);
  }
  ```

  `Start` runs the GTK loop with a synchronization context that returns every
  `await` to the thread GTK owns.
- **Swift and its runtime travel beside the executable.** `build-linux.sh`:
  - builds the library and the application module in one SwiftPM pass, with
    `-DMAUI`;
  - copies the Swift runtime beside them, with an `$ORIGIN` run path;
  - compiles the C shims in the library's `lib/StateUI.Maui/Linux/native/`,
    and any `.c` file in the head's `Linux/` folder, into `lib<name>.so`;
  - checks that every library a module needs is packaged.

  The graphene shim keeps a view that wears a transform from freeing that
  transform twice.
- **Artwork keeps its vectors.** `Resources/Images/*.svg` are copied beside
  the executable under their `.png` names, and GTK reads a picture by its
  content. GTK recognizes an SVG only when `<svg` falls within the first
  hundred bytes of the file, so a file's comment goes inside the `<svg>`
  element. `Resources/Images/stateui_tile.svg` is published under
  `hicolor/…/apps/appicon.svg` and becomes every window's icon.
- **The theme follows the desktop.** The platform reads the desktop's own
  light-or-dark setting and reports a change while the application runs.
- **No map.** The backend has no map control, so the Map node draws the
  unknown-control marker.

To build on Ubuntu, install the development packages the Linux workflow uses,
beside the .NET 10 SDK and Swift:

```bash
sudo apt-get install libgtk-4-dev libgraphene-1.0-dev gir1.2-gtk-4.0 build-essential
```

The Linux workflow builds the Gallery and HelloWorld in the
`swift:6.3.3-noble` container and runs both suites there. Nothing runs the
application in CI: a GTK 4 application needs a display.

## The host's suite

```bash
dotnet test lib/StateUI.Maui/Tests
```

The suite drives MAUI's controls as ordinary .NET objects over the Wire
fixtures that the StateUI suite writes to `lib/StateUI/Tests/Fixtures`. It needs
the .NET 10 SDK and, except on Linux, the MAUI workload. Its test classes run
one at a time (`DisableTestParallelization` in `Tests/Support.cs`), because
they share state that is static per process.

After a deliberate Wire change, regenerate the fixtures and apply them here in
one step with the task "Test (update wire fixtures)":

```bash
STATEUI_UPDATE_FIXTURES=1 swift test && dotnet test lib/StateUI.Maui/Tests
```

The `Tests` workflow runs the suite on Ubuntu, and the Windows and Linux
workflows run it again on their hosts.

## Publishing the packages

A release is three NuGet packages and one tag:

| Package | Project | Contents |
| --- | --- | --- |
| `StateUI.Maui` | `lib/StateUI.Maui/Sources` | the C# host for Android, iOS, Mac Catalyst, and Windows, and the plain `net10.0` library Linux runs |
| `StateUI.Maui.Linux` | `lib/StateUI.Maui/Linux` | the Linux platform over the GTK 4 backend |
| `StateUI.Maui.Template` | `lib/StateUI.Maui/Template` | the `stateui-maui` template |

The Swift half is the repository itself. The root `Package.swift` is the Swift
package, and a tag such as `0.3.1` is what
`.package(url: "https://github.com/idexus/StateUI.git", exact: "0.3.1")`
resolves.

Three things move together:

- the three packages' `<Version>`;
- the template's two package references and its `exact:` pin;
- the tag.

Tag first: a template pinned to an untagged version generates an application
that cannot resolve its Swift half.

```bash
dotnet pack lib/StateUI.Maui/Sources -c Release -o artifacts     # on Windows
dotnet pack lib/StateUI.Maui/Linux -c Release -o artifacts
dotnet pack lib/StateUI.Maui/Template -c Release -o artifacts
```

- **`StateUI.Maui` is complete only when packed on Windows.** The WinUI head
  builds only there, while the Android, iOS, and Mac Catalyst heads build
  wherever the MAUI workload is installed. A pack from macOS lacks the Windows
  library, and a Windows application consuming it silently binds the plain
  `net10.0` library, where every `#if WINDOWS` block is compiled out. A Linux
  host packs `net10.0` alone.
- **The template takes `.scripts/Maui/` from the repository as it packs**, so
  the package never carries a second copy that drifts. `template.json` copies
  those scripts byte for byte (`copyOnly`), because the templating engine
  would otherwise evaluate the MSBuild conditions in them and drop the
  missing-library errors.
- **Each package carries `LICENSE`, `NOTICE`, and its `README.md`.**

To try the packages before they are published:

- **Register the local source once per machine:**
  `dotnet nuget add source "$PWD/artifacts" -n stateui-local`.
- **Clear the cached copies after every re-pack of the same version.** NuGet
  keeps serving the copy it already holds:

  ```bash
  rm -rf ~/.nuget/packages/stateui.maui ~/.nuget/packages/stateui.maui.linux
  ```

- **Reinstall the template:** `dotnet new uninstall StateUI.Maui.Template`, then
  `dotnet new install` again.

## Troubleshooting

**The application starts without its interface, or reports a missing native
library.**
Run the diagnostic first:

```bash
dotnet build apps/Gallery/Platforms/Maui -t:StateUIDiagnose -f net10.0-android
```

It prints:

- the library package and the application package it resolved, with their
  source counts;
- the application module;
- the artifacts directory, and whether it exists;
- the generated interop file;
- how many native libraries exist for each platform.

Zero libraries means the build never produced them where the application looks.
Android packs its libraries into the APK rather than into `bin/`:

```bash
unzip -l apps/Gallery/Platforms/Maui/bin/Debug/net10.0-android/com.example.gallery-Signed.apk | grep '\.so'
```

Expect `lib/arm64-v8a/libStateUI.so`, `lib/arm64-v8a/libGalleryUI.so`, and the
Swift runtime beside them.

**"StateUI: … was not built" or "… was not produced".**
Every platform stops the build when a Swift library is missing, and names it.
The script's own error is printed above the message. The application module's
library matters as much as the StateUI one: it holds the registration, and a
build without it would start and describe nothing. Each script states its
usage at its top and can be run by hand. Run that way, it builds release unless
`SWIFT_CONFIG=debug` is set, while MSBuild passes the build's own
configuration.

**"StateUI: the module name does not match."**
The project name decides the module (`Notes.csproj` builds `NotesUI`), and
`Package.swift` must name the same target and product. Rename them in the
manifest, or set `StateUIAppModule` in the project. After renaming an
application, delete the head's `bin/` and `obj/` and the application's
`.build/`: they are named after the old module.

**"StateUI: no checkout under … holds the library's sources."**
The application's `Package.swift` must depend on StateUI. A `.package(path:)`
dependency is never checked out, so a project that uses one also sets
`StateUIPackagePath` to that checkout.

**"unknown dependency 'StateUI' in target …".**
The StateUI checkout's directory has another name. SwiftPM identifies a path
dependency by its last path component, so the directory is called `StateUI`.

**"no versions of 'stateui' match the requirement 0.3.1".**
The generated application's Swift half names a release that is not tagged.
Create the application with `--stateui-path`, or point its `Package.swift` at
a checkout with `.package(path:)` and set `StateUIPackagePath`.

**"NU1101: Unable to find package StateUI.Maui".**
The packages are not on a NuGet source this machine knows. Register the local
`artifacts/` directory as described under
[Publishing the packages](#publishing-the-packages).

**Android: "no Swift SDK for Android installed."**
Install the Swift SDK for Android with `swift sdk install` and its checksum,
following swift.org's guide. Then bring the NDK into it with the bundle's
`setup-android-sdk.sh`. `swift sdk list` must show an `android` entry.

**Android: "toolchain … does not match SDK …", or "compiled module was created
by an older version of the compiler; rebuild 'Dispatch'".**
The SDK's binary modules can be read only by the compiler build that wrote
them, and Xcode's and swift.org's toolchains can report the same version from
different builds. `build-android.sh` compares the build in the parentheses of
`swift --version` with the SDK's tag. On a mismatch it looks for a matching
toolchain at:

- `~/Library/Developer/Toolchains/<tag>.xctoolchain`;
- `/Library/Developer/Toolchains/<tag>.xctoolchain`;
- `~/.swiftly/bin/swift`.

Install the swift.org toolchain the message names, or point the build at one
with `SWIFT_BIN=/path/to/swift`.

**Android: "needed but not packaged: libc++_shared.so".**
The NDK's sysroot is linked into the Swift SDK, and the packaging step does
not follow symbolic links. Run the SDK's `setup-android-sdk.sh` with
`SWIFT_ANDROID_NDK_LINK=0`, which copies the sysroot instead.

**Android: an application installed by hand stops at once.**
A Debug APK carries no assemblies; `-t:Run` pushes them. Deploy with
`-t:Run`, or build a self-contained APK with
`-p:EmbedAssembliesIntoApk=true` before `adb install`. A launch failure's
stack is in the crash buffer, which `adb logcat -b crash -d` prints. When
`-t:Run` succeeds in seconds and installs nothing on a fresh emulator, delete
the head's `obj/Debug/net10.0-android` and `bin/Debug/net10.0-android`.

**iOS Simulator: "no iPhone simulator is installed".**
`run-app.sh ios` boots the newest installed iPhone simulator when none is
running. Add one in Xcode under Window > Devices and Simulators.

**iOS Simulator: "Terminated due to signal 9" after the Swift debugger
attaches.**
The watchdog killed an application that a debugger held stopped. Use "Debug app
(Swift)", which launches first and attaches afterwards.

**iOS: the application aborts during runtime start-up after builds for
different runtime identifiers in one tree.**
Delete the head's `obj/<Configuration>/net10.0-ios` and
`bin/<Configuration>/net10.0-ios`, then build with `-f net10.0-ios` and no
`-r`.

**iOS device: "NETSDK1047: … doesn't have a target for
'net10.0-ios/ios-arm64'".**
The heads name the three iOS runtime identifiers during restore only; keep that
property group when editing a head's project.

**Mac Catalyst or iOS: an edited `Info.plist` has no effect.**
The merged plist is cached per configuration and framework. Run "Clean app
(everything)" and build again.

**"compilation reported success but object file(s) are missing".**
The incremental state in the head's `obj/stateui` no longer matches the
sources, usually after a checkout rewrote many files. Delete `obj/stateui`;
"Clean native artifacts" does that for the Gallery. Clear it after editing a
build script too: the targets compare against the `.swift` sources, so a
changed script alone leaves the previous library in place.

**`run-app.sh`: "more than one .app".**
A renamed `ApplicationTitle` left the previous bundle beside the new one. Remove
the stale bundle, or clean.

**Windows: "StateUI: could not replace the Swift library in …".**
The application is still running, and Windows keeps a loaded DLL locked. Close
the application or stop the debug session, then build again. Until then `bin/`
holds the previous Swift build.

**Windows: "the DLL format is invalid" (BadImageFormatException).**
The process and the Swift DLL were built for different architectures. The head
defaults its runtime identifier to the host's architecture; do not hard-code
`win-x64`.

**Windows: "swiftc not found on PATH."**
Install the Swift toolchain for Windows, then open a new shell.

**Windows: "DWARF debug info needs lld-link".**
Use a Swift toolchain that ships lld, or build with `-p:SwiftDebugFormat=codeview`.

**The editor reports "No such module 'StateUI'" while the build succeeds.**
SourceKit resolves imports through the application's `Package.swift`, at the
application's root. Check that the manifest and its StateUI dependency resolve,
then reload the window.

**A VS Code task never reports that it finished.**
MSBuild's worker processes outlive a build and hold the terminal of the task
that started it. The build tasks and `run-app.ps1` pass `-nodeReuse:false` for
that reason; keep it on any task that builds.
