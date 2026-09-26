// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if APPKIT || GTK || WINUI || ANDROID
/// The host this build of the gallery runs on, as its interop group names it: the one place the group's samples
/// differ by host, beside each sample's host half.
enum InteropHost {
    #if APPKIT
    static let name = "AppKit"
    static let key = "appKit"
    static let control = "An AppKit control"
    static let controlSummary = "An NSView the app registers with its host, described like any other control."
    static let lamps = "The lamps are an `NSView` the gallery registers with `StateUIControls.add`, under the "
        + "members `TrafficLightContract` declares with the type of each value."
    static let made = "view"
    static let awaiting = ""
    static let cubeDrawn = "by Metal"
    #elseif GTK
    static let name = "GTK"
    static let key = "gtk"
    static let control = "A GTK control"
    static let controlSummary = "A GTK widget the app registers with its host, described like any other control."
    static let lamps = "The lamps are a `GtkDrawingArea` the gallery registers with `StateUIControls.add`, under the "
        + "members `TrafficLightContract` declares with the type of each value, held by a `GTKControl` of its own."
    static let made = "control"
    static let awaiting = " A performer may await: GTK reads the clipboard asynchronously."
    static let cubeDrawn = "by OpenGL"
    #elseif WINUI
    static let name = "WinUI"
    static let key = "winUI"
    static let control = "A WinUI control"
    static let controlSummary = "A WinUI element the app registers with its host, described like any other control."
    static let lamps = "The lamps are XAML the gallery's own relay makes, registered with `StateUIControls.add`, "
        + "under the members `TrafficLightContract` declares with the type of each value, held by a `WinUIControl` "
        + "of its own."
    static let made = "control"
    static let awaiting = " A performer may await."
    static let cubeDrawn = "by Direct3D"
    #else
    static let name = "Android"
    static let key = "android"
    static let control = "An Android control"
    static let controlSummary = "An Android view the app registers with its host, described like any other control."
    static let lamps = "The lamps are an Android view of the gallery's own Java, registered with "
        + "`StateUIControls.add`, under the members `TrafficLightContract` declares with the type of each value, "
        + "held by an `AndroidControl` of its own."
    static let made = "control"
    static let awaiting = " A performer may await."
    static let cubeDrawn = "by OpenGL ES"
    #endif
}
#endif
