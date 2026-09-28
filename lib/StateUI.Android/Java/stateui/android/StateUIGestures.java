// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewParent;

/**
 * What the user does to a view its element listens to, as the touches and the hovering pointer the view gets tell
 * it: taps counted in quick runs, a press and its moves - which the Swift host tells a drag in, by the host layer's
 * rule - a pinch, and the pointer entering, moving, pressing, releasing and leaving. All in points; a press through
 * `StateUIHost.pressed`, the rest through `StateUIHost.gestured`.
 */
final class StateUIGestures implements ScaleGestureDetector.OnScaleGestureListener {
    /** What is told through `gestured`, as the Swift host numbers it. */
    static final int TAPPED = 0, PINCHED = 3, ENTERED = 4, EXITED = 5, MOVED = 6, PRESSED = 7, RELEASED = 8;

    /** A press's phase through `pressed`, and a pinch's, as StateUI numbers them. */
    private static final int DOWN = 0, MOVE = 1, LET_GO = 2, TAKEN = 3;
    private static final int STARTED = 0, RUNNING = 1, COMPLETED = 2;

    private final View host;
    private final long view;
    private final float density;
    private final int slop;
    private final int tapTimeout;
    private final ScaleGestureDetector scale;

    /**
     * Whether the element counts taps in runs - a click is the tap where one makes it - and hears a press dragged,
     * a pinch, the pointer.
     */
    private boolean countsTaps;
    private boolean drags;
    private boolean pinch;
    private boolean pointer;

    /** Where the touch went down, on the screen: a moving view moves where its own touches are. */
    private float downX;
    private float downY;
    private boolean moved;
    private boolean pressing;
    private boolean dragging;
    private boolean pinching;

    /** Where the pinch under way was last centred, in points of the view: where it ends. */
    private float pinchX;
    private float pinchY;

    /** The taps of the run so far, when the last lifted, and where. */
    private int tapped;
    private long lastTap;
    private float lastTapX;
    private float lastTapY;

    StateUIGestures(View host, long view, float density) {
        this.host = host;
        this.view = view;
        this.density = density;
        ViewConfiguration configuration = ViewConfiguration.get(host.getContext());
        slop = configuration.getScaledTouchSlop();
        tapTimeout = ViewConfiguration.getDoubleTapTimeout();
        scale = new ScaleGestureDetector(host.getContext(), this);
    }

    /** What the element listens for; none is false everywhere. */
    void configure(boolean countsTaps, boolean drags, boolean pinch, boolean pointer) {
        this.countsTaps = countsTaps;
        this.drags = drags;
        this.pinch = pinch;
        this.pointer = pointer;
    }

    /**
     * Follows one touch event; whether the gestures take it. A drag or a pinch under way takes the rest of the
     * touch, the view's own handling cancelled; a view with no handling of its own is given the whole touch.
     */
    boolean onTouch(MotionEvent event) {
        if (!wanted()) return false;
        if (pinch) scale.onTouchEvent(event);

        float x = event.getRawX() / density;
        float y = event.getRawY() / density;
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                downX = event.getRawX();
                downY = event.getRawY();
                moved = false;
                if (pointer) report(PRESSED, 0, event.getX() / density, event.getY() / density, 0);
                ViewParent parent = host.getParent();
                if (parent != null && (drags || pinch)) parent.requestDisallowInterceptTouchEvent(true);
                if (drags) {
                    pressing = true;
                    press(DOWN, x, y);
                }
                break;
            case MotionEvent.ACTION_MOVE:
                if (Math.hypot(event.getRawX() - downX, event.getRawY() - downY) > slop) moved = true;
                if (pointer) report(MOVED, 0, event.getX() / density, event.getY() / density, 0);
                if (pressing && !pinching && event.getPointerCount() == 1 && press(MOVE, x, y) && !dragging) {
                    dragging = true;
                    cancelOwn(event);
                }
                break;
            case MotionEvent.ACTION_UP:
                if (pointer) report(RELEASED, 0, event.getX() / density, event.getY() / density, 0);
                if (pressing) press(LET_GO, x, y);
                if (!moved && !pinching && countsTaps) tap(event);
                pressing = false;
                dragging = false;
                break;
            case MotionEvent.ACTION_CANCEL:
                if (pressing) press(TAKEN, x, y);
                pressing = false;
                dragging = false;
                tapped = 0;
                break;
            default:
                break;
        }
        return dragging || pinching || !(host.isClickable() || host.isLongClickable());
    }

    /** Whether the element listens for any of the user's input. */
    boolean wanted() {
        return countsTaps || drags || pinch || pointer;
    }

    /** Whether a drag or a pinch under way takes the rest of the touch. */
    boolean taking() {
        return dragging || pinching;
    }

    /** Follows the pointer hovering over the view - a mouse's, a stylus's; it takes nothing. */
    boolean onHover(MotionEvent event) {
        if (!pointer) return false;
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_HOVER_ENTER: report(ENTERED, 0, 0, 0, 0); break;
            case MotionEvent.ACTION_HOVER_MOVE:
                report(MOVED, 0, event.getX() / density, event.getY() / density, 0);
                break;
            case MotionEvent.ACTION_HOVER_EXIT: report(EXITED, 0, 0, 0, 0); break;
            default: break;
        }
        return false;
    }

    /**
     * One more tap in the run where it is near the last and soon after it, as Android measures a double tap - it
     * counts no longer runs itself; each tap is told with its place in the run.
     */
    private void tap(MotionEvent event) {
        long now = event.getEventTime();
        boolean near = Math.hypot(event.getRawX() - lastTapX, event.getRawY() - lastTapY) <= slop * 4;
        tapped = tapped > 0 && near && now - lastTap <= tapTimeout ? tapped + 1 : 1;
        lastTap = now;
        lastTapX = event.getRawX();
        lastTapY = event.getRawY();
        report(TAPPED, tapped, 0, 0, 0);
    }

    /** The view's own handling of the touch is called off: a drag is no press, and no click. */
    private void cancelOwn(MotionEvent event) {
        if (!(host.isClickable() || host.isLongClickable())) return;
        MotionEvent cancel = MotionEvent.obtain(event);
        cancel.setAction(MotionEvent.ACTION_CANCEL);
        host.onTouchEvent(cancel);
        cancel.recycle();
    }

    @Override
    public boolean onScaleBegin(ScaleGestureDetector detector) {
        if (!pinch) return false;
        pinching = true;
        if (pressing) {
            press(TAKEN, 0, 0);
            pressing = false;
            dragging = false;
        }
        pinched(STARTED, 1, detector);
        return true;
    }

    @Override
    public boolean onScale(ScaleGestureDetector detector) {
        pinched(RUNNING, detector.getScaleFactor(), detector);
        return true;
    }

    @Override
    public void onScaleEnd(ScaleGestureDetector detector) {
        pinching = false;
        report(PINCHED, COMPLETED, 1, pinchX, pinchY);
    }

    /**
     * A pinch's phase, its scale since the last report, and where it is centred in points of the view. It ends
     * where it was last centred: as a finger lifts, Android centres it on the finger left.
     */
    private void pinched(int phase, float factor, ScaleGestureDetector detector) {
        pinchX = detector.getFocusX() / density;
        pinchY = detector.getFocusY() / density;
        report(PINCHED, phase, factor, pinchX, pinchY);
    }

    /** A press's phase at a point of the screen; whether it is a drag now. */
    private boolean press(int phase, float x, float y) {
        return StateUIHost.pressed(view, phase, x, y);
    }

    private void report(int kind, int phase, float x, float y, float z) {
        StateUIHost.gestured(view, kind, phase, x, y, z);
    }
}
