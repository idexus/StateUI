# Android Views host

The Android Views host renders a StateUI application with Android views. It is
Swift, in the application's own process, beside the application module and the
library: it applies the typed sparse patches of the
[host contract](../internals/host-contract.md) directly and calls the views through JNI.

It presents StateUI's controls, arrangements and pages over the runtime every
host shares - the [platform contract](../platform-contract.md#control-creation) says
which, member by member - and shows any other control's name in red where the control
belongs, so a gap is visible rather than silent.

```text
lib/StateUI/StateUI.Android/
  Sources/StateUIAndroid/    the host: its runtime, elements, registrations, layout and JNI
  Sources/CStateUIAndroid/   the NDK's C surface: JNI, the looper, the log
  Java/stateui/android/      the Java layer: the activity, the layout view group, the frame callback, the listener
  Tests/                     the host's suite, run in a test APK on a device
.scripts/Android/
  build-swift.sh             an application's Swift for Android, for the ABIs asked
  run-app.sh                 builds an application's Android head, installs and starts it
  deploy.sh                  builds it for release and lays its APK in a folder of its own
  test-android.sh            builds and runs the host's suite on a device
  devices.sh                 the devices attached, the emulators, and booting one
  tools.sh                   what they share: the SDK, adb, JDK 21, Gradle, a head's APK, the device
  draw-app-icon.swift        a head's launcher icon, drawn from the application's Resources/AppIcon
apps/<App>/Platforms/Android/
  Swift/<App>Android.swift   the application's Android head
  Java/                      the application's own views, where it has any
  build.gradle.kts           its APK: the host's Java layer, the application's, and the Swift libraries
  AndroidManifest.xml        the activity, and the library it loads
```

## Requirements

The host builds on macOS, for Android 9 (API 28) or newer:

- Swift 6.4 from swift.org, `swift-6.4.0-RELEASE`, and the Swift SDK for
  Android of the same release, installed with `swift sdk install`. Xcode's own
  Swift 6.4 is a different build and cannot read the SDK's modules;
  `build-swift.sh` finds the matching toolchain by itself;
- the Android NDK r30 or newer: the one `ANDROID_NDK_ROOT` or
  `ANDROID_NDK_HOME` names, else the
  one the Swift SDK's setup linked into its bundle, else the Android SDK's
  newest;
- the Android SDK with platform 36 and its build tools, and JDK 21 for
  Gradle. The scripts fetch Gradle itself the first time.

## The head

An application's Android head is a library Android loads. Its `JNI_OnLoad`
names the application and hands the virtual machine to the host:

```swift quote
import NotesUI
import StateUIAndroid

@_cdecl("JNI_OnLoad")
public func JNI_OnLoad(_ machine: UnsafeMutableRawPointer?, _ reserved: UnsafeMutableRawPointer?) -> Int32 {
    stateui_app_register()
    return StateUIAndroid.load(machine)
}
```

The head's `AndroidManifest.xml` declares the host's activity,
`stateui.android.StateUIActivity`, with the library to load as its
`stateui.library`. The activity loads it and starts the host; an application
needs no Java of its own. Its `build.gradle.kts` depends on AndroidX's
`recyclerview`, the collection an ItemsView stands on. One that extends the host with views of its own
keeps their Java beside the head, in `Java/`, and may extend the activity,
declaring its own class in the manifest instead.

`STATEUI_HOST=android` is what makes a build an Android Views one: the
application's manifest reads it, declares its `Platforms/Android/Swift` head
and the library it makes, and defines the `ANDROID` compilation condition for
every module of the application; `lib/StateUI.Head` brings the
`StateUIAndroid` host to the head. Swift written for this host alone stands
under `#if ANDROID`. `build-swift.sh` sets nothing else: the library itself is
built as every host builds it.

A new application made in `apps/` - **StateUI: New Application in apps/**, or
`.scripts/new-app.sh` - has an Android head, as HelloWorld does, and runs and
is debugged as soon as it is made.

## Controls, acts, and events registered in Swift

An application extends the host from its Android head. Registrations run in
`JNI_OnLoad`, on the UI thread - the main actor's - before
`StateUIAndroid.load`. Registering a contract or an act again replaces the
earlier registration. Every registration is written against the
application's own contracts, so they are `public`: the host lives in a module
of its own and must see them. The Gallery's Android halves are in
`apps/Gallery/Platforms/Android/`: Swift in `Swift/Host/`, Java in `Java/`.

### A control

A control of the application's own is an object holding the Android view it
shows, an `AndroidControl`. The view is a class of the application's own
Java, made from Swift through `Java` - the host's JNI, the same calls it
makes itself - with the activity, `StateUIAndroid.context`, and held as a
`JavaObject`. `StateUIControls.add` says which contract it realizes:

```swift quote
public static func add<Realized: ElementContract, Made: AndroidControl>(
    _ contract: Realized.Type,
    create: @escaping (AndroidReports<Realized>) -> Made,
    members: (AndroidRegistration<Realized, Made>) -> Void = { _ in })
```

- **`create`** makes the control once per element, and wires what it reports:
  `reports.raise(Contract.member, values)` for an event of the element's own,
  and `reports.report(property, value, as: event)` for a value the USER
  changed.
- **`members`** registers what the control takes: `property(_:_:)` hands a
  value over as the type its contract declares, `nil` where it is no longer
  described, and `raises(_:)` records an event the control raises.

```swift quote
StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
    let light = TrafficLightView()
    light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
    return light
}) { light in
    light.property(TrafficLightContract.signal) { control, signal in
        control.signal = signal ?? .stop
    }
    light.raises(TrafficLightContract.lampTapped)
}
```

The host places, sizes and shows the view as it does its own - margins,
alignment, opacity, gestures, frame reports - measuring it by the view's own
`onMeasure`. A registered control is a leaf: it draws the children of a
contract it names itself, as the next section says. The view tells its Swift half
what the user did through a native method of the application's own, found by
its JNI name (`@_cdecl("Java_..._lampTapped")`), handed the number the
control made it with. A control that draws with the GPU is a view like any
other: the Gallery's `Cube3D` is a `TextureView` whose surface Swift draws
into with OpenGL ES 3.0 over EGL, following the display's frames only while
it spins and stands in a window - the same declaration Metal draws on AppKit.

### Children a control draws

A control may draw the children of one contract itself - a map draws its markers.
`children` names their contract and what of each the control realizes, and hands
it every such child, in the tree's order, whenever the element's children
change: one added, moved, taken away, or given another value. A child is a
`AndroidChild` - its values read as the types its contract declares, and its own
`reports` to raise its events on it - and stays the same child for as long as
it lives, so the control keeps what it drew for one by it. Such a child has no
view of its own.

```swift quote
StateUIControls.add(MapContract.self, create: { reports -> MyMap in … }) { map in
    map.property(MapContract.region) { control, region in … }
    map.children(MarkerContract.self, members: [MarkerContract.location, MarkerContract.selected]) { control, markers in
        control.show(markers.map { marker in (marker, marker.value(MarkerContract.location)) })
        // the user taps one: marker.reports.raise(MarkerContract.selected)
    }
}
```

A library element a host does not realize - a `Map` where the platform has no
map of its own - is registered the same way, with the provider and the key it
needs.

This host leaves `Map` and its `Marker` to the application: the platform has
no map of its own, and a map needs a provider and its key, so the host makes
neither (`byApplication` in `AndroidRealization.swift`), and the
[platform contract](../platform-contract.md#reading-the-matrix) marks them 🧩.
What the user sees there is the application's own registration. Every other
element of the library is the host's own, its `WebView` included: Android's
web view, in the Java layer's `StateUIWebView`, which makes it again, blank,
should its web process die. The head registers nothing for it.

### An act

`StateUIActs.add` registers a function the application calls by its act, and
`StateUIActs.add(_:on:_:)` one aimed at the application's own element, handed
that element's control:

```swift quote
StateUIActs.add(GalleryContract.setClipboard) { text in
    Java.frame {
        Java.callStatic(device, copy, .object(StateUIAndroid.context), .object(Java.string(text)))
    }
}

StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
    bar.flash()
}
```

A performer runs on the UI thread, and may await, the call answered once it
returns. Its arguments and answer are the act's own types; a call carrying
anything else fails with the reason. A thrown error fails the act, and so does
an aim at nothing; an act nobody registered is refused by name.

### An event without a control

`StateUIEvents.raise` pushes an event of the application's that belongs to no
element, from any thread; `StateUIEvents.raises` declares it before the host
starts, so a handler listening for one no source raises is told so. Its
source is often Android's own - the Gallery's activity registers a receiver
for the battery while it lives:

```swift quote
StateUIEvents.raises(GalleryContract.batteryChanged)
StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
```

## Running

```bash
.scripts/Android/devices.sh list
.scripts/Android/run-app.sh apps/HelloWorld debug emulator-5554
.scripts/Android/run-app.sh apps/Gallery debug emulator-5554
```

`run-app.sh` builds the application's Swift for the device's ABI alone, then
the APK, installs it, starts it and follows its log. Everything a build writes
stays in the application's `.build/android/`. The APK carries the libraries
the head needs and nothing else - the Swift runtime's own among them -
stripped, with the unstripped copies kept in `.build/android/symbols/` for
`ndk-stack` and a debugger. Android draws no SVG, so the application's
`Resources/Images` are drawn for it as the APK is built: an SVG three times
over, as a PNG, which `Image("mark.png")` finds as it finds the SVG on every
other host. An application's `print` reaches logcat under the
tag `StateUI`, and so does what `STATEUI_TALLY=1` and `STATEUI_INSPECT=1`
write: `run-app.sh` hands every `STATEUI_` variable of the shell that runs it
to the application's environment. A head's manifest asks for
`ACCESS_NETWORK_STATE`, which the host needs to report the network to the
application's views.

In VS Code, choose **Android** as the host and a device, and press **F5**.

## Debugging

**StateUI: Debug** builds, installs and starts the application as `run-app.sh`
does, and then attaches `lldb-dap` to it: a breakpoint in the application, in
StateUI or in the host stops it, with its source, its stack and its variables.
It is the application running that is attached to, so what runs before - the
first render - runs without the debugger. Only a debug build can be debugged.

`run-app.sh --debugger` readies it: the NDK's `lldb-server` runs as the
application, in its own sandbox, and `.build/android/debugger.json` says where
it listens and which process to attach to. From a terminal, with the toolchain's
`lldb`:

```bash
.scripts/Android/run-app.sh apps/Gallery debug emulator-5554 --no-logcat --debugger
cat apps/Gallery/.build/android/debugger.json
lldb -o "settings set plugin.jit-loader.gdb.enable off" \
     -o "platform select remote-android" \
     -o "platform connect unix-abstract-connect://emulator-5554/com.stateui.gallery/stateui-debugger.sock" \
     -o "settings append target.exec-search-paths $PWD/apps/Gallery/.build/android/symbols/arm64-v8a" \
     -o "process attach --pid <process from debugger.json>" \
     -o "process handle SIGSEGV SIGBUS --pass true --stop false --notify false"
```

The libraries are read from the build, which kept them unstripped; they must
be the ones installed, so the application is always run through the script
before it is attached to. Android's runtime raises SIGSEGV and SIGBUS on purpose,
and the debugger passes them to it rather than stopping. Nor does the debugger
follow the code the runtime's JIT compiles: the runtime announces each method
it compiles, and a debugger that reads each announcement stops the whole
application every time - over USB, opening a page took seconds. End a session by
detaching - stopping the debugger itself leaves its breakpoints in the
application, which the next of them then ends.

## Deploying

```bash
.scripts/Android/deploy.sh apps/Gallery artifacts/Gallery/Android emulator-5554
```

`deploy.sh` builds an application's head for release, for the ABI of the
device named - `ANDROID_SERIAL`, or the one device attached, where none is
named - and lays its APK, `<application>.apk`, in the folder named, made
anew. The APK is signed as the head's `build.gradle.kts` says: HelloWorld's
and the Gallery's sign a release with the debug key. **StateUI: Deploy** in
the editor runs it for the application and the device chosen, and lays the
APK in `artifacts/<application>/Android` of the folder that holds the
application's `apps/` - a checkout's, or a project group's.

## Testing

A view exists only in an application's process, so the host's suite is a
library a test APK loads, run on the device's UI thread by its
instrumentation:

```bash
.scripts/Android/test-android.sh emulator-5554
```

The suite is XCTest. With no discovery on Android, each test case lists its
tests in `allTests` and the runner lists the cases; `test-android.sh` refuses
to run while a test or a case is listed nowhere. Each test and each
conformance case says as it ends where the run stands, followed from the
device's log, and the run ends with *Executed N tests, with M failures*.

The suite runs the conformance families too, one test a family -
`AndroidConformanceTests.testButton`. A whole run holds what it says to
`lib/StateUI/exports/`: what the host declares to `android.txt`, and the
verdicts it takes off the device to `marks/android/<Family>.txt`, each under
the revision its family stands at in
`lib/StateUI/StateUI.Conformance/revisions.txt`, which the script writes over
them, as the device reads no repository. A run that says otherwise fails;
`STATEUI_UPDATE_EXPORTS=1` writes them instead. `STATEUI_FILTER` runs the
tests whose `Case.test` name holds one of its comma-separated names, and then
holds nothing to `lib/StateUI/exports/`: a part of the suite proves only part
of what the host declares. `STATEUI_STALE_ONLY=1` runs only the families
whose verdict files stand at another revision, or at none - the script
chooses them - and holds or writes only theirs.

```bash
STATEUI_FILTER=testPicker,AndroidColorBoxViewTests .scripts/Android/test-android.sh emulator-5554
STATEUI_UPDATE_EXPORTS=1 .scripts/Android/test-android.sh emulator-5554
STATEUI_UPDATE_EXPORTS=1 STATEUI_STALE_ONLY=1 .scripts/Android/test-android.sh emulator-5554
STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests
```

With the verdicts written, the last line - at the repository's root - renders
the [platform contract](../platform-contract.md#reading-the-matrix) and
[the control dictionary](../controls/README.md) from them. In the editor,
with Android and a device chosen, **StateUI: Conformance - Rebuild all** runs
the whole suite on the device with `STATEUI_UPDATE_EXPORTS=1`, then renders
the documents. **StateUI: Conformance - Rebuild changed** runs nothing for
Android: the editor answers that the device reads no repository, so its marks
are made again whole, by Rebuild all. From a terminal, `STATEUI_STALE_ONLY=1`
runs the stale families alone, as above.

The test APK can be built on one machine and run on another:
`test-android.sh --build x86_64` builds it for that ABI with no device and
prints where it is, and `STATEUI_TEST_APK=<apk> test-android.sh` installs
that APK instead of building one. CI builds on macOS, where the build draws
the pictures, and runs the suite on a Linux emulator.
