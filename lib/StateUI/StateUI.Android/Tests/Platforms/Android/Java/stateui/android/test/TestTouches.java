// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.View;

/** Touches a test gives a view as a user does: two fingers pinching, a mouse hovering. */
public final class TestTouches {
    private TestTouches() {}

    /**
     * Two fingers on either side of (`x`, `y`) pixels of the view, `from` pixels apart - Android measures a
     * pinch from where the fingers first move, so they move once in place - then in four steps to `to` apart,
     * then lifted.
     */
    public static void pinch(View view, float x, float y, float from, float to) {
        long time = 0;
        send(view, time, MotionEvent.ACTION_DOWN, 1, x, y, from);
        send(view, time += 10, MotionEvent.ACTION_POINTER_DOWN | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, x, y, from);
        for (int step = 0; step <= 4; step++) {
            send(view, time += 20, MotionEvent.ACTION_MOVE, 2, x, y, from + (to - from) * step / 4);
        }
        send(view, time += 10, MotionEvent.ACTION_POINTER_UP | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, x, y, to);
        send(view, time + 10, MotionEvent.ACTION_UP, 1, x, y, to);
    }

    /**
     * Two fingers on either side of (`x`, `y`) pixels of the view, spreading by a tenth so Android tells the pinch
     * apart, then by `scale` in one step - one step of the pinch scaled by `scale` - then lifted. They begin 600
     * pixels apart, wider where they close, so they never come nearer than 660: Android ends a pinch whose fingers
     * stand nearer than its least span, some 27 mm, telling nothing of its last step.
     */
    public static void pinchBy(View view, float x, float y, float scale) {
        float begun = 660 * Math.max(1, 1 / scale);
        float start = begun / 1.1f;
        long time = 0;
        send(view, time, MotionEvent.ACTION_DOWN, 1, x, y, start);
        send(view, time += 10, MotionEvent.ACTION_POINTER_DOWN | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, x, y, start);
        send(view, time += 20, MotionEvent.ACTION_MOVE, 2, x, y, begun);
        send(view, time += 20, MotionEvent.ACTION_MOVE, 2, x, y, begun * scale);
        send(view, time += 10, MotionEvent.ACTION_POINTER_UP | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, x, y, begun * scale);
        send(view, time + 10, MotionEvent.ACTION_UP, 1, x, y, begun * scale);
    }

    /**
     * Two fingers either side of (`x`, `y`) pixels of the view, 600 pixels apart across, turned clockwise in four
     * steps by `degrees`, then lifted.
     */
    public static void rotate(View view, float x, float y, float degrees) {
        long time = 0;
        turned(view, time, MotionEvent.ACTION_DOWN, 1, x, y, 0);
        turned(view, time += 10, MotionEvent.ACTION_POINTER_DOWN | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, x, y, 0);
        for (int step = 1; step <= 4; step++) {
            turned(view, time += 20, MotionEvent.ACTION_MOVE, 2, x, y, degrees * step / 4);
        }
        turned(view, time += 10, MotionEvent.ACTION_POINTER_UP | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, x, y, degrees);
        turned(view, time + 10, MotionEvent.ACTION_UP, 1, x, y, degrees);
    }

    /** Two fingers 600 pixels apart about (`x`, `y`), the line between them turned clockwise `degrees` from across. */
    private static void turned(View view, long time, int action, int fingers, float x, float y, float degrees) {
        double angle = Math.toRadians(degrees);
        float dx = (float) (300 * Math.cos(angle));
        float dy = (float) (300 * Math.sin(angle));
        MotionEvent.PointerProperties[] properties = new MotionEvent.PointerProperties[fingers];
        MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[fingers];
        for (int finger = 0; finger < fingers; finger++) {
            properties[finger] = new MotionEvent.PointerProperties();
            properties[finger].id = finger;
            properties[finger].toolType = MotionEvent.TOOL_TYPE_FINGER;
            coords[finger] = new MotionEvent.PointerCoords();
            coords[finger].x = finger == 0 ? x - dx : x + dx;
            coords[finger].y = finger == 0 ? y - dy : y + dy;
            coords[finger].pressure = 1;
            coords[finger].size = 1;
        }
        MotionEvent event = MotionEvent.obtain(0, time, action, fingers, properties, coords, 0, 0, 1, 1, 0, 0,
                InputDevice.SOURCE_TOUCHSCREEN, 0);
        view.dispatchTouchEvent(event);
        event.recycle();
    }

    private static void send(View view, long time, int action, int fingers, float x, float y, float apart) {
        MotionEvent.PointerProperties[] properties = new MotionEvent.PointerProperties[fingers];
        MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[fingers];
        for (int finger = 0; finger < fingers; finger++) {
            properties[finger] = new MotionEvent.PointerProperties();
            properties[finger].id = finger;
            properties[finger].toolType = MotionEvent.TOOL_TYPE_FINGER;
            coords[finger] = new MotionEvent.PointerCoords();
            coords[finger].x = finger == 0 ? x - apart / 2 : x + apart / 2;
            coords[finger].y = y;
            coords[finger].pressure = 1;
            coords[finger].size = 1;
        }
        MotionEvent event = MotionEvent.obtain(0, time, action, fingers, properties, coords, 0, 0, 1, 1, 0, 0,
                InputDevice.SOURCE_TOUCHSCREEN, 0);
        view.dispatchTouchEvent(event);
        event.recycle();
    }

    /** A mouse doing `action` - entering, moving or leaving - over the view at (`x`, `y`) pixels. */
    public static void hover(View view, int action, float x, float y) {
        MotionEvent event = MotionEvent.obtain(0, 0, action, x, y, 0);
        event.setSource(InputDevice.SOURCE_MOUSE);
        view.dispatchGenericMotionEvent(event);
        event.recycle();
    }

    /** A mouse entering the view at (`x`, `y`) pixels, moving 10 pixels right, and leaving. */
    public static void hover(View view, float x, float y) {
        int[] actions = {MotionEvent.ACTION_HOVER_ENTER, MotionEvent.ACTION_HOVER_MOVE, MotionEvent.ACTION_HOVER_EXIT};
        for (int step = 0; step < actions.length; step++) {
            MotionEvent event = MotionEvent.obtain(0, step * 10, actions[step], x + step * 10, y, 0);
            event.setSource(InputDevice.SOURCE_MOUSE);
            view.dispatchGenericMotionEvent(event);
            event.recycle();
        }
    }
}
