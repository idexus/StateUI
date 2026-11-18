# Doctor

`stateui doctor` and `toolchain/check` say what this machine has of what each
host needs - the handbook's requirements, a component at a time - and what to
install where something is missing. They look and change nothing: no SDK is
installed, no setup command run.

## What doctor checks

Every machine: Swift 6.4 or newer (the compiler `SWIFT_BIN` names, else the
search path's), lldb-dap for Debug, Git for a new project's releases, Node.js
for the editor extension's own build. Then what this machine's hosts need:

```text
macOS     macOS and Xcode (AppKit, UIKit), an iOS simulator runtime, an Apple
          Development certificate (a device), the swift.org toolchain with the
          Swift SDK for Android, the Android SDK, the NDK, JDK 21
Linux     pkg-config, GTK, libadwaita, WebKitGTK (the web view), gdk-pixbuf's
          SVG loader, a desktop session
Windows   Swift from swift.org, Visual Studio with the C++ tools, the WebView2
          runtime (the web view), the Windows SDK
macOS and Linux   the Swift SDK for WebAssembly (the Web)
macOS     Safari 27 with its WebAssembly debugger (Debug in Safari)
```

Each finding names its component with the least of it that serves, who needs
it, what was found or the version found too old, and how to get it. Its
`hosts` are the hosts that cannot be built without it; a component serving a
part of the work - a device, a web view, Debug - names none. The checks run at
once and are told in their order.

Doctor fails - status 3 - when something is missing that every host needs, or,
given `--host`, something that host needs. A machine lacking another
platform's tools is no failure: a Mac without the Android NDK builds AppKit.
Given `--device` naming a guest of the Mac, it checks that guest for the
host's heads instead, each finding naming its machine
([The doctor of a guest](guests.md#the-doctor-of-a-guest)).

## Android's tools

The Android build and doctor find its tools one way (`AndroidTools`): the
SDK is `ANDROID_HOME`, `ANDROID_SDK_ROOT`, else Android Studio's own place;
the compiler is the one the build takes - `SWIFT_BIN`, else `swift` on the
search path, 6.4 or newer - with the Swift SDK for Android of its release, and
where that compiler is Xcode's, which cannot read the SDK, the swift.org
toolchain of the same release; the NDK is the one `ANDROID_NDK_ROOT` or
`ANDROID_NDK_HOME` names, else the one the Swift SDK's setup linked into its
bundle, else the SDK's newest. Asking any other toolchain says what the build
will not meet: a newer release's SDK whose bundle no setup has linked an NDK
into reads as an older one's NDK found.
