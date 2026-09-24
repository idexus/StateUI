// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewParent;

/**
 * The gestures a view's element listens for, told apart in the touches and the hovering pointer the view gets:
 * taps counted, a pan and the fingers it takes, a swipe past its threshold in the directions asked, a pinch,
 * and the pointer entering, moving, pressing, releasing and leaving. Each reaches the Swift view by its number,
 * in points, through one native, `StateUIHost.gestured`.
 */
final class StateUIGestures implements ScaleGestureDetector.OnScaleGestureListener {
    /** What is reported, as the Swift host numbers it. */
    static final int TAPPED = 0, PANNED = 1, SWIPED = 2, PINCHED = 3, ENTERED = 4, EXITED = 5, MOVED = 6,
            PRESSED = 7, RELEASED = 8;

    /** A continuous gesture's phase, as StateUI numbers it. */
    private static final int STARTED = 0, RUNNING = 1, COMPLETED = 2, CANCELED = 3;

    /** A swipe's directions, as StateUI numbers them. */
    private static final int RIGHT = 1, LEFT = 2, UP = 4, DOWN = 8;

    private final View host;
    private final long view;
    private final float density;
    private final int slop;
    private final int tapTimeout;
    private final ScaleGestureDetector scale;

    /** How many taps make one - none below two, where a click is the tap - and the fingers a pan takes. */
    private int taps;
    private int panFingers;
    private int swipeDirections;
    private float swipeThreshold;
    private boolean pinch;
    private boolean pointer;

    /** Where the touch went down, on the screen: a moving view moves where its own touches are. */
    private float downX;
    private float downY;
    private boolean moved;
    private boolean panning;
    private boolean pinching;

    /** Where the pinch under way was last centred, as fractions of the view: where it ends. */
    private float pinchX;
    private float pinchY;

    /** The taps counted so far, when the last lifted, and where. */
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

    /** Which gestures the element listens for; none of any is 0 or false. */
    void configure(int taps, int panFingers, int swipeDirections, float swipeThreshold, boolean pinch,
                   boolean pointer) {
        this.taps = taps;
        this.panFingers = panFingers;
        this.swipeDirections = swipeDirections;
        this.swipeThreshold = swipeThreshold;
        this.pinch = pinch;
        this.pointer = pointer;
    }

    /**
     * Follows one touch event; whether the gestures take it. A pan or a pinch under way takes the rest of the
     * touch, the view's own handling cancelled; a view with no handling of its own is given the whole touch.
     */
    boolean onTouch(MotionEvent event) {
        boolean wanted = taps > 1 || panFingers > 0 || swipeDirections != 0 || pinch || pointer;
        if (!wanted) return false;
        if (pinch) scale.onTouchEvent(event);

        float dx = event.getRawX() - downX;
        float dy = event.getRawY() - downY;
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                downX = event.getRawX();
                downY = event.getRawY();
                moved = false;
                if (pointer) report(PRESSED, 0, event.getX() / density, event.getY() / density, 0);
                ViewParent parent = host.getParent();
                if (parent != null && (panFingers > 0 || swipeDirections != 0 || pinch)) {
                    parent.requestDisallowInterceptTouchEvent(true);
                }
                break;
            case MotionEvent.ACTION_MOVE:
                if (Math.hypot(dx, dy) > slop) moved = true;
                if (pointer) report(MOVED, 0, event.getX() / density, event.getY() / density, 0);
                if (!panning && !pinching && moved && panFingers > 0 && event.getPointerCount() == panFingers) {
                    panning = true;
                    cancelOwn(event);
                    report(PANNED, STARTED, 0, 0, 0);
                }
                if (panning) report(PANNED, RUNNING, dx / density, dy / density, 0);
                break;
            case MotionEvent.ACTION_UP:
                if (pointer) report(RELEASED, 0, event.getX() / density, event.getY() / density, 0);
                if (panning) report(PANNED, COMPLETED, 0, 0, 0);
                if (swipeDirections != 0) swipe(dx / density, dy / density);
                if (!moved && !pinching && taps > 1) tap(event);
                panning = false;
                break;
            case MotionEvent.ACTION_CANCEL:
                if (panning) report(PANNED, CANCELED, 0, 0, 0);
                panning = false;
                tapped = 0;
                break;
            default:
                break;
        }
        return panning || pinching || !(host.isClickable() || host.isLongClickable());
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

    /** One more tap near the last and soon after it; the tap that makes the count is reported. */
    private void tap(MotionEvent event) {
        long now = event.getEventTime();
        boolean near = Math.hypot(event.getRawX() - lastTapX, event.getRawY() - lastTapY) <= slop * 4;
        tapped = tapped > 0 && near && now - lastTap <= tapTimeout ? tapped + 1 : 1;
        lastTap = now;
        lastTapX = event.getRawX();
        lastTapY = event.getRawY();
        if (tapped == taps) {
            tapped = 0;
            report(TAPPED, 0, 0, 0, 0);
        }
    }

    /** A swipe along the axis it moved most on, past the threshold, in a direction asked for. */
    private void swipe(float dx, float dy) {
        boolean across = Math.abs(dx) >= Math.abs(dy);
        float distance = across ? Math.abs(dx) : Math.abs(dy);
        if (distance <= 0 || distance < swipeThreshold) return;
        int direction = across ? (dx > 0 ? RIGHT : LEFT) : (dy < 0 ? UP : DOWN);
        if ((swipeDirections & direction) != 0) report(SWIPED, direction, 0, 0, 0);
    }

    /** The view's own handling of the touch is called off: a pan is no press, and no click. */
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
        if (panning) {
            report(PANNED, CANCELED, 0, 0, 0);
            panning = false;
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
     * A pinch's phase, its scale since the last report, and where it is centred, as fractions of the view. It
     * ends where it was last centred: as a finger lifts, Android centres it on the finger left.
     */
    private void pinched(int phase, float factor, ScaleGestureDetector detector) {
        int width = host.getWidth();
        int height = host.getHeight();
        pinchX = width > 0 ? detector.getFocusX() / width : 0.5f;
        pinchY = height > 0 ? detector.getFocusY() / height : 0.5f;
        report(PINCHED, phase, factor, pinchX, pinchY);
    }

    private void report(int kind, int phase, float x, float y, float z) {
        StateUIHost.gestured(view, kind, phase, x, y, z);
    }
}
