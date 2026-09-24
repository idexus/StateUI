// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.view.Menu;
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

    /** The display turned or resized, or the theme changed. */
    static native void configured();

    /** The user asked to go back; whether the host went. */
    static native boolean back();

    /** The activity's lifecycle moved the application's phase. */
    static native void phase(int phase);

    /** A frame of the display began at {@code time}, in nanoseconds of the monotonic clock. */
    static native void frame(long time);

    /** A button was clicked. */
    static native void clicked(long view);

    /** A tab was chosen, by its place among the tabs. */
    static native void tabSelected(long view, int tab);

    /** One of a view's menu items was chosen - a bar's action, a context menu's item - by its place among them. */
    static native void menuChose(long view, int item);

    /** The user asks for a view's context menu - a long press, a secondary click - for Swift to write into `menu`. */
    static native void menuOpening(long view, Menu menu);

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

    /** A scroller moved. */
    static native void scrolled(long view);

    /** A finger took hold of a view, or let go of it. */
    static native void held(long view, boolean holding);

    /** The user opened a view's list, calendar or clock. */
    static native void opened(long view);

    /** A view's list, calendar or clock closed. */
    static native void closed(long view);

    /** The user chose a day - year, month, day - or a time - hour, minute, 0 - in a date or time field. */
    static native void fieldChose(long view, int first, int second, int third);

    /** The user chose a picker's option at `index`. */
    static native void chose(long view, int index);

    /**
     * The act waiting under `ticket` was answered: a dialog accepted or not, and the words chosen or typed;
     * a script's value as text.
     */
    static native void answered(long ticket, boolean accepted, String words);

    /**
     * A gesture on a view, as `StateUIGestures` numbers its kind: a tap; a pan's phase and its distance so far;
     * a swipe's direction; a pinch's phase, its scale since the last and where it is centred; the pointer
     * entering, moving, pressing, releasing or leaving, and where - all in points.
     */
    static native void gestured(long view, int kind, int phase, float x, float y, float z);

    /** A view took the keyboard's focus, or lost it. */
    static native void focusChanged(long view, boolean focused);

    /** The activity is finishing - the user left it, or it finished itself: its window is going. */
    static native void destroying();

    /** A web view's navigation started: why, as StateUI numbers it, and where it is going. */
    static native void webNavigating(long view, int cause, String address);

    /** A web view's navigation ended: how and why, as StateUI numbers them, and where it went. */
    static native void webNavigated(long view, int result, int cause, String address);

    /** Whether a web view has a page behind it and ahead of it, as its history now stands. */
    static native void webHistory(long view, boolean back, boolean forward);

    /** A web view's web process died, and the view was made again, blank. */
    static native void webProcessGone(long view);

    /** A finger went down on a canvas - 0 - moved on it - 1 - or was lifted - 2 - at a point in points. */
    static native void canvasTouched(long view, int phase, float x, float y);

    /** The window's views were laid out or scrolled: what stands where may have moved. */
    static native void laidOut();

    /** A layout is measured; its width in the high half, its height in the low one. */
    static native long measure(long view, int widthSpec, int heightSpec);

    /** A layout places its children. */
    static native void arrange(long view, int width, int height);
}
