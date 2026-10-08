// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// listing: InteropEventsSample.Android.swift
// The native methods of the gallery's Java views, com.stateui.gallery.GalleryNatives - found by their JNI names, each
// called on the UI thread, where Swift's main actor runs.
// listing: end

import Android
import GalleryUI
import StateUIAndroid

@_cdecl("Java_com_stateui_gallery_GalleryNatives_lampTapped")
public func galleryLampTapped(_ env: UnsafeMutablePointer<JNIEnv?>?, _ owner: jclass?, _ control: jlong, _ lamp: jint) {
    MainActor.assumeIsolated { (GalleryControls.control(control) as? TrafficLightView)?.tapped(Int(lamp)) }
}

@_cdecl("Java_com_stateui_gallery_GalleryNatives_rated")
public func galleryRated(_ env: UnsafeMutablePointer<JNIEnv?>?, _ owner: jclass?, _ control: jlong, _ rating: jdouble) {
    MainActor.assumeIsolated { (GalleryControls.control(control) as? RatingBarView)?.rated(rating) }
}

@_cdecl("Java_com_stateui_gallery_GalleryNatives_surfaceReady")
public func gallerySurfaceReady(
    _ env: UnsafeMutablePointer<JNIEnv?>?, _ owner: jclass?, _ control: jlong, _ surface: jobject?, _ width: jint,
    _ height: jint
) {
    nonisolated(unsafe) let (env, surface) = (env, surface)
    MainActor.assumeIsolated {
        (GalleryControls.control(control) as? GLESCube3DView)?.surfaceReady(
            surface, environment: env, width: width, height: height)
    }
}

@_cdecl("Java_com_stateui_gallery_GalleryNatives_surfaceGone")
public func gallerySurfaceGone(_ env: UnsafeMutablePointer<JNIEnv?>?, _ owner: jclass?, _ control: jlong) {
    MainActor.assumeIsolated { (GalleryControls.control(control) as? GLESCube3DView)?.surfaceGone() }
}

@_cdecl("Java_com_stateui_gallery_GalleryNatives_cubeFrame")
public func galleryCubeFrame(_ env: UnsafeMutablePointer<JNIEnv?>?, _ owner: jclass?, _ control: jlong, _ time: jlong) {
    MainActor.assumeIsolated { (GalleryControls.control(control) as? GLESCube3DView)?.frame(at: time) }
}

// listing: InteropEventsSample.Android.swift
@_cdecl("Java_com_stateui_gallery_GalleryNatives_batteryChanged")
public func galleryBatteryChanged(
    _ env: UnsafeMutablePointer<JNIEnv?>?, _ owner: jclass?, _ level: jdouble, _ charging: jboolean
) {
    MainActor.assumeIsolated { GalleryEventSources.report(level: level, charging: charging != 0) }
}
// listing: end
