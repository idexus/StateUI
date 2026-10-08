// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package com.stateui.gallery;

import android.view.Surface;

// listing: Cube3DSample.Android.java, InteropControlSample.Android.natives.java, InteropEventsSample.Android.java
/**
 * What the gallery's own Android views tell its Swift half, each by the number
 * its control was made with. The Swift half answers each, in Host/GalleryNatives.swift.
 */
final class GalleryNatives {
    private GalleryNatives() {}

    /** A traffic light's lamp was tapped, counted from the top. */
    static native void lampTapped(long control, int lamp);

    /** A rating bar's user chose a rating. */
    static native void rated(long control, double rating);

    /** A cube's surface came, or changed its size in pixels. */
    static native void surfaceReady(long control, Surface surface, int width, int height);

    /** A cube's surface is going: nothing draws into it once this returns. */
    static native void surfaceGone(long control);

    /** A display frame for a cube, while it asks for them. */
    static native void cubeFrame(long control, long nanoseconds);

    /** The battery said its level, 0 to 1, and whether it charges. */
    static native void batteryChanged(double level, boolean charging);
}
// listing: end
