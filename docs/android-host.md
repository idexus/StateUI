# Android Views host

The Android Views host renders a StateUI application with Android views. It is
Swift, in the application's own process, beside the application module and the
library: it applies the typed sparse patches of the
[host contract](host-contract.md) directly and calls the views through JNI. No
Wire encoding stands between them.

It presents its first controls - `Label`, `Button`, `TextField`, `Switch`,
`Slider`, `VStack` and `HStack` - over the runtime every host shares, and
shows any other control's name in red where the control belongs, so a gap is
visible rather than silent.

```text
lib/StateUI.Android/
  Sources/StateUIAndroid/    the host: its runtime, elements, registrations, layout and JNI
  Sources/CStateUIAndroid/   the NDK's C surface: JNI, the looper, the log
  Java/stateui/android/      the Java layer: the activity, the layout view group, the frame callback, the listener
  Tests/                     the host's suite, run in a test APK on a device
.scripts/Android/
  build-swift.sh             an application's Swift for Android, for the ABIs asked
  run-app.sh                 builds an application's Android head, installs and starts it
  test-android.sh            builds and runs the host's suite on a device
  devices.sh                 the devices attached, the emulators, and booting one
apps/<App>/Platforms/Android/
  Swift/<App>Android.swift   the application's Android head
  build.gradle.kts           its APK: the host's Java layer and the Swift libraries
  AndroidManifest.xml        the activity, and the library it loads
```

## Requirements

The host builds on macOS, for Android 9 (API 28) or newer:

- Swift 6.4 from swift.org, `swift-6.4.0-RELEASE`, and the Swift SDK for
  Android of the same release, installed with `swift sdk install`. Xcode's own
  Swift 6.4 is a different build and cannot read the SDK's modules;
  `build-swift.sh` finds the matching toolchain by itself;
- the Android NDK r30, found in the Android SDK or named by `ANDROID_NDK_HOME`;
- the Android SDK with platform 36, and JDK 21 for Gradle. The scripts fetch
  Gradle itself the first time.

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
`stateui.library`. The activity loads it and starts the host; the application
has no Java of its own.

`STATEUI_ANDROID=1` is what makes a build an Android Views one: the
application's manifest reads it, declares the `Platforms/Android/Swift` target,
the library it makes and the `StateUIAndroid` dependency, and defines the
`ANDROID` compilation condition for every module of the application. Swift
written for this host alone stands under `#if ANDROID`. `build-swift.sh` sets
nothing else: the library itself is built as every host but MAUI builds it.

## Running

```bash
.scripts/Android/devices.sh list
.scripts/Android/run-app.sh apps/HelloWorld debug emulator-5554
```

`run-app.sh` builds the application's Swift for the device's ABI alone, then
the APK, installs it, starts it and follows its log. Everything a build writes
stays in the application's `.build-android/`. The APK carries the libraries
the head needs and nothing else - the Swift runtime's own among them -
stripped, with the unstripped copies kept in `.build-android/symbols/` for
`ndk-stack` and a debugger. An application's `print` reaches logcat under the
tag `StateUI`.

In VS Code, choose **Android** as the host and a device, and press **F5**.

## Testing

A view exists only in an application's process, so the host's suite is a
library a test APK loads, run on the device's UI thread by its
instrumentation:

```bash
.scripts/Android/test-android.sh emulator-5554
```

The suite is XCTest. With no discovery on Android, each test case lists its
tests in `allTests` and the runner lists the cases; `test-android.sh` refuses
to run while a test or a case is listed nowhere.
