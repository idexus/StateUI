// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.widget.FrameLayout;

/** The Swift host: every method is registered by the head's JNI_OnLoad. */
final class StateUIHost {
    /** The application's phases, as StateUI numbers them. */
    static final int ACTIVE = 0;
    static final int INACTIVE = 1;
    static final int BACKGROUND = 2;

    private StateUIHost() {}

    /** Starts the host in the activity's root, at the display's density. */
    static native void start(Activity activity, FrameLayout root, float density);

    /** The activity's lifecycle moved the application's phase. */
    static native void phase(int phase);

    /** A frame of the display began at {@code time}, in nanoseconds of the monotonic clock. */
    static native void frame(long time);

    /** A button was clicked. */
    static native void clicked(long view);

    /** A switch was turned on or off. */
    static native void toggled(long view, boolean on);

    /** A slider's thumb moved to {@code progress}. */
    static native void moved(long view, int progress);

    /** The user took a slider's thumb. */
    static native void dragStarted(long view);

    /** The user let go of a slider's thumb. */
    static native void dragCompleted(long view);

    /** A field's words changed; {@code text} is all of them. */
    static native void textChanged(long view, String text);

    /** The user submitted a field. */
    static native void submitted(long view);

    /** A layout is measured; its width in the high half, its height in the low one. */
    static native long measure(long view, int widthSpec, int heightSpec);

    /** A layout places its children. */
    static native void arrange(long view, int width, int height);
}
