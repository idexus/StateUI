# Android heads

An Android head is a library SwiftPM builds, `lib<Name>Android.so`, that the
host's Java layer loads; the APK carries it, everything it needs, the
application's pictures, the host's drawables and the launcher icon.

## The Swift build

The compiler is the swift.org toolchain of the Swift SDK for Android's
release (Xcode's cannot read the SDK; `stateui doctor --host android` says
what is missing), with the NDK the SDK's setup linked - else
`ANDROID_NDK_ROOT`, `ANDROID_NDK_HOME`, the Android SDK's newest - 30 or
newer. `swift build --swift-sdk <sdk> --triple <aarch64|x86_64>-unknown-linux-android28`
builds one ABI: the one asked for, else the device's the build is for, else
`arm64-v8a`. Each ABI is a build context of its own, its scratch folder told
apart by the Swift SDK and the NDK (builds.md).

## The native libraries

The APK ships `lib<Name>Android.so` and everything it needs by `DT_NEEDED`
(`llvm-readelf --needed-libs`), followed until nothing new is needed: from
SwiftPM's build, the Swift SDK's runtime for the ABI, or the NDK's
`libc++_shared.so`. A library the NDK's sysroot declares for API 28 is the
platform's and stays out. Each is laid stripped (`llvm-strip
--strip-unneeded`) for the APK and whole beside it, in the artifact's
`symbols/<abi>`, for a debugger and `ndk-stack`; a library is stripped again
only when its source changed, and one the closure no longer holds goes
(`AndroidLibraries`).

## The APK

Android draws no SVG: the application's `Resources/Images` are drawn three
times over into the APK's assets, and `Resources/AppIcon` becomes the
adaptive `@mipmap/appicon` (pictures.md) - on a Mac, where the drawing is
AppKit's for now. The host's drawables join the resources. Gradle, run on JDK
21 with the pinned Gradle - the wrapper's cache, else downloaded into it -
assembles the head's `Platforms/Android` project with the host's Java and
these folders, given as properties, `ANDROID_HOME` naming the SDK. The APK is
published as the artifact, `<Name>.apk`, signed with the debug key Gradle
keeps for every configuration; its package and the activity the launcher
opens are read back from it (`aapt2 dump badging`). `stateui package` lays
the APK in `artifacts/<Name>/Android`.
