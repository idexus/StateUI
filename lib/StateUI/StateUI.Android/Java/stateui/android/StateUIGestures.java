// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.MotionEvent;
import android.view.InputDevice;
import android.view.ScaleGestureDetector;
import android.view.VelocityTracker;
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
    // Swift: AndroidGestureKind
    static final int TAPPED = 0, PINCHED = 3, ENTERED = 4, EXITED = 5, MOVED = 6, PRESSED = 7, RELEASED = 8;

    /** A press's phase through `pressed`, and a pinch's, as StateUI numbers them. */
    // Swift: AndroidPressPhase
    private static final int DOWN = 0, MOVE = 1, LET_GO = 2, TAKEN = 3;
    // Swift: GesturePhase
    private static final int BEGAN = 0, CHANGED = 1, ENDED = 2, CANCELLED = 3;

    private final View host;
    private final long view;
    private final float density;
    private final int slop;
    /** When the listener was made, on the events' clock: a tap's time is told from here. */
    private final long madeAt = android.os.SystemClock.uptimeMillis();
    private final ScaleGestureDetector scale;

    /**
     * Whether the element counts taps in runs - a click is the tap where one makes it - and hears a press dragged,
     * a pinch, the pointer.
     */
    private boolean countsTaps;
    private boolean drags;
    private boolean pinch;
    private boolean pointer;

    /** Whether the element is a layout two fingers turn, and whether two fingers stand on it now. */
    private boolean rotation;
    private boolean turning;

    /**
     * Whether the element is a layout a hand moves - each finger on it told to the Swift host, which reads them as
     * one hand and says whether the layout has it - and a wheel; whether it has it, and the hand's speed.
     */
    private boolean hand;
    private boolean handTaking;
    private VelocityTracker handSpeed;

    /** Where the touch went down, on the screen: a moving view moves where its own touches are. */
    private float downX;
    private float downY;
    private boolean moved;
    private boolean pressing;
    private boolean dragging;
    private boolean pinching;

    /**
     * Whether a pinch began in the touch under way - no tap, however still its last finger - and whether the touch
     * is being cancelled, which ends a pinch cancelled.
     */
    private boolean pinched;
    private boolean cancelling;

    /** Where the pinch under way was last centered, in points of the view: where it ends. */
    private float pinchX;
    private float pinchY;

    StateUIGestures(View host, long view, float density) {
        this.host = host;
        this.view = view;
        this.density = density;
        ViewConfiguration configuration = ViewConfiguration.get(host.getContext());
        slop = configuration.getScaledTouchSlop();
        scale = new ScaleGestureDetector(host.getContext(), this);
    }

    /** What the element listens for; none is false everywhere. */
    void configure(
            boolean countsTaps, boolean drags, boolean pinch, boolean pointer, boolean hand, boolean rotation) {
        this.countsTaps = countsTaps;
        this.drags = drags;
        this.pinch = pinch;
        this.pointer = pointer;
        this.hand = hand;
        this.rotation = rotation;
    }

    /**
     * Follows one touch event; whether the gestures take it. A drag or a pinch under way takes the rest of the
     * touch, the view's own handling cancelled; a view with no handling of its own is given the whole touch.
     */
    boolean onTouch(MotionEvent event) {
        if (!wanted()) return false;
        cancelling = event.getActionMasked() == MotionEvent.ACTION_CANCEL;
        if (event.getActionMasked() == MotionEvent.ACTION_DOWN) pinched = false;
        boolean wasPinched = pinched;
        if (pinch) scale.onTouchEvent(event);
        // A pinch begun is no press of the view's own: its click is called off.
        if (pinched && !wasPinched) cancelOwn(event);
        if (rotation) fingers(event);

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
                if (hand) handReport(event);
                break;
            case MotionEvent.ACTION_MOVE:
                if (Math.hypot(event.getRawX() - downX, event.getRawY() - downY) > slop) moved = true;
                if (pointer) report(MOVED, 0, event.getX() / density, event.getY() / density, 0);
                if (pressing && !pinching && event.getPointerCount() == 1 && press(MOVE, x, y) && !dragging) {
                    dragging = true;
                    cancelOwn(event);
                }
                if (hand) handReport(event);
                break;
            case MotionEvent.ACTION_UP:
                if (pointer) report(RELEASED, 0, event.getX() / density, event.getY() / density, 0);
                if (pressing) press(LET_GO, x, y);
                if (hand) handReport(event);
                if (!moved && !pinched && countsTaps) tap(event);
                pressing = false;
                dragging = false;
                break;
            case MotionEvent.ACTION_CANCEL:
                if (pressing) press(TAKEN, x, y);
                if (hand) handReport(event);
                pressing = false;
                dragging = false;
                break;
            default:
                // A finger more, or one of several lifting.
                if (hand) handReport(event);
                break;
        }
        return dragging || pinching || handTaking || !(host.isClickable() || host.isLongClickable());
    }

    /** Whether the element listens for any of the user's input. */
    boolean wanted() {
        return countsTaps || drags || pinch || pointer || hand || rotation;
    }

    /** Whether a drag, a pinch, two fingers or the hand under way takes the rest of the touch. */
    boolean taking() {
        return dragging || pinching || turning || handTaking;
    }

    /**
     * Two fingers on a layout they turn: told where each stands as the second goes down, as they move and as one
     * lifts - the Swift host reads the turn between them.
     */
    private void fingers(MotionEvent event) {
        int action = event.getActionMasked();
        if (action == MotionEvent.ACTION_CANCEL) {
            if (turning) StateUIHost.fingers(view, CANCELLED, 0, 0, 0, 0);
            turning = false;
            return;
        }
        if (event.getPointerCount() < 2) return;
        boolean lifting = action == MotionEvent.ACTION_POINTER_UP && event.getPointerCount() == 2;
        int phase = !turning ? BEGAN : lifting ? ENDED : CHANGED;
        if (!turning && action != MotionEvent.ACTION_POINTER_DOWN && action != MotionEvent.ACTION_MOVE) return;
        turning = !lifting;
        if (phase == BEGAN) {
            ViewParent parent = host.getParent();
            if (parent != null) parent.requestDisallowInterceptTouchEvent(true);
        }
        StateUIHost.fingers(
                view, phase, event.getX(0) / density, event.getY(0) / density, event.getX(1) / density,
                event.getY(1) / density);
    }

    /**
     * A wheel's notches over a layout a hand moves - Android's scroll axes count them, a part of one for a fine wheel
     * - the way they move what is under the hand; whether it took them.
     */
    boolean onGenericMotion(MotionEvent event) {
        if (!hand || event.getActionMasked() != MotionEvent.ACTION_SCROLL) return false;
        if (!event.isFromSource(InputDevice.SOURCE_CLASS_POINTER)) return false;
        float across = -event.getAxisValue(MotionEvent.AXIS_HSCROLL);
        float down = event.getAxisValue(MotionEvent.AXIS_VSCROLL);
        return StateUIHost.notched(view, across, down);
    }

    /**
     * Each finger on a layout a hand moves, told as it goes down, moves and lifts - where it stands on the screen and
     * in the view, in points - the last as it lets go with the hand's speed: the Swift host reads them as one hand and
     * says whether the layout has it, which then takes the rest of the touch - the parent may intercept it no more,
     * and the view's own press is called off.
     */
    private void handReport(MotionEvent event) {
        int action = event.getActionMasked();
        if (action == MotionEvent.ACTION_DOWN) {
            if (handSpeed != null) handSpeed.recycle();
            handSpeed = VelocityTracker.obtain();
        }
        if (handSpeed != null) handSpeed.addMovement(event);
        boolean had = handTaking;
        switch (action) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_POINTER_DOWN:
                handTaking = finger(event, event.getActionIndex(), DOWN, 0, 0);
                break;
            case MotionEvent.ACTION_MOVE:
                for (int index = 0; index < event.getPointerCount(); index++) {
                    handTaking = finger(event, index, MOVE, 0, 0);
                }
                break;
            case MotionEvent.ACTION_POINTER_UP:
                handTaking = finger(event, event.getActionIndex(), LET_GO, 0, 0);
                break;
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_CANCEL:
                float speedX = 0, speedY = 0;
                if (handSpeed != null) {
                    handSpeed.computeCurrentVelocity(1000);
                    speedX = handSpeed.getXVelocity() / density;
                    speedY = handSpeed.getYVelocity() / density;
                    handSpeed.recycle();
                    handSpeed = null;
                }
                int phase = action == MotionEvent.ACTION_UP ? LET_GO : TAKEN;
                for (int index = 0; index < event.getPointerCount(); index++) {
                    handTaking = finger(event, index, phase, speedX, speedY);
                }
                break;
            default:
                return;
        }
        if (handTaking && !had) {
            ViewParent parent = host.getParent();
            if (parent != null) parent.requestDisallowInterceptTouchEvent(true);
            cancelOwn(event);
        }
    }

    /** The finger of `event` at `index`, at `phase`, lifting at a speed: whether the layout has the hand now. */
    private boolean finger(MotionEvent event, int index, int phase, float speedX, float speedY) {
        float offsetX = event.getRawX() - event.getX(), offsetY = event.getRawY() - event.getY();
        return StateUIHost.finger(
            view, phase, event.getPointerId(index), (event.getX(index) + offsetX) / density,
            (event.getY(index) + offsetY) / density, event.getX(index) / density, event.getY(index) / density, speedX,
            speedY);
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
     * A tap, told with its time in milliseconds from the listener's own start and where it lands on the screen in
     * points: Swift counts its run (TapRun).
     */
    private void tap(MotionEvent event) {
        report(TAPPED, (int) (event.getEventTime() - madeAt), event.getRawX() / density, event.getRawY() / density, 0);
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
        pinched = true;
        if (pressing) {
            press(TAKEN, 0, 0);
            pressing = false;
            dragging = false;
        }
        pinched(BEGAN, 1, detector);
        return true;
    }

    @Override
    public boolean onScale(ScaleGestureDetector detector) {
        pinched(CHANGED, detector.getScaleFactor(), detector);
        return true;
    }

    @Override
    public void onScaleEnd(ScaleGestureDetector detector) {
        pinching = false;
        report(PINCHED, cancelling ? CANCELLED : ENDED, 1, pinchX, pinchY);
    }

    /**
     * A pinch's phase, its scale since the last report, and where it is centered in points of the view. It ends
     * where it was last centered: as a finger lifts, Android centers it on the finger left.
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
