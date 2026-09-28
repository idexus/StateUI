// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.view.MotionEvent;
import android.widget.LinearLayout;

/** A stepper's two buttons side by side, its element's gestures seeing the touches the buttons get. */
final class StateUIStepper extends LinearLayout {
    private final StateUIWatch watch = new StateUIWatch();

    StateUIStepper(Context context) {
        super(context);
    }

    /** Lets `listener`'s gestures see what the buttons get. */
    void watch(StateUIListener listener) {
        watch.watch(listener);
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        return watch.touch(this, event, super::dispatchTouchEvent);
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        return watch.hover(this, event, super::dispatchGenericMotionEvent);
    }
}
