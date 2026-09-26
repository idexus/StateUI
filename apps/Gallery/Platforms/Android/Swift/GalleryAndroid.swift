// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIAndroid

// What Android calls as it loads this library, on the UI thread: the application is named to the host, this head
// says what it answers for the application - the controls it realizes, the acts it performs, the events it raises,
// each in Host/ beside this file - and the host registers the native methods its activity calls.
@_cdecl("JNI_OnLoad")
public func JNI_OnLoad(_ machine: UnsafeMutableRawPointer?, _ reserved: UnsafeMutableRawPointer?) -> Int32 {
    stateui_app_register()
    MainActor.assumeIsolated {
        GalleryControls.register()
        GalleryActs.register()
        GalleryEventSources.register()
    }
    return StateUIAndroid.load(machine)
}
