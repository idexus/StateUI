// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.View;
import java.util.function.Predicate;

/**
 * The touches and the hovering a view made of parts gets, seen by its element's gestures before its parts get them:
 * a gesture under way takes the rest of the touch from the parts, which are told it was called off, and a touch no
 * part takes stays the view's where its element listens for one.
 */
final class StateUIWatch {
    /** The view's one listener; none before its element listens for a gesture. */
    private StateUIListener listener;

    /** Whether the gesture under way took the touch from the parts. */
    private boolean took;

    void watch(StateUIListener listener) {
        this.listener = listener;
    }

    /** Hands `event` to the gestures, then to the parts through `parts` unless a gesture took the touch. */
    boolean touch(View whole, MotionEvent event, Predicate<MotionEvent> parts) {
        if (listener == null) return parts.test(event);
        listener.onTouch(whole, event);
        if (listener.takesTouch()) {
            if (!took) {
                took = true;
                MotionEvent cancel = MotionEvent.obtain(event);
                cancel.setAction(MotionEvent.ACTION_CANCEL);
                parts.test(cancel);
                cancel.recycle();
            }
            return true;
        }
        int action = event.getActionMasked();
        if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) took = false;
        return parts.test(event) || listener.wantsTouch();
    }

    /** Hands a hovering pointer's `event` to the gestures, then to the parts. */
    boolean hover(View whole, MotionEvent event, Predicate<MotionEvent> parts) {
        if (listener != null && event.isFromSource(InputDevice.SOURCE_CLASS_POINTER)) listener.onHover(whole, event);
        return parts.test(event);
    }
}
