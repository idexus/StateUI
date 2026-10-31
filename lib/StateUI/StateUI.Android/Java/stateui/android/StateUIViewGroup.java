// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.graphics.Matrix;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;

/**
 * A StateUI layout: Android asks it to measure and place, and the Swift host
 * answers. It draws its children past its edges, as every StateUI layout does.
 */
class StateUIViewGroup extends ViewGroup {
    private final long view;

    StateUIViewGroup(Context context, long view) {
        super(context);
        this.view = view;
        setClipChildren(false);
        setClipToPadding(false);
    }

    /** The number the Swift view answers to. */
    final long number() {
        return view;
    }

    /** Whether the layout was measured since it last arranged its children, and the size it arranged them in. */
    private boolean measured = true;
    private int arrangedWidth = -1;
    private int arrangedHeight = -1;

    /** The order the children are drawn and touched in, back to front, by index; null for their own. */
    private int[] drawingOrder;

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        long size = StateUIHost.measure(view, widthSpec, heightSpec);
        setMeasuredDimension((int) (size >>> 32), (int) size);
        measured = true;
    }

    /** A layout moved but not resized, with nothing in it asking to be measured again, leaves its children be. */
    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        int width = right - left;
        int height = bottom - top;
        if (!measured && width == arrangedWidth && height == arrangedHeight) return;

        measured = false;
        arrangedWidth = width;
        arrangedHeight = height;
        StateUIHost.arrange(view, width, height);
    }

    /** Draws the children, and hands them touches, in `order` - back to front, by index; null for their own order. */
    void setDrawingOrder(int[] order) {
        drawingOrder = order;
        setChildrenDrawingOrderEnabled(order != null);
        invalidate();
    }

    @Override
    protected int getChildDrawingOrder(int childCount, int drawingPosition) {
        int[] order = drawingOrder;
        return order != null && order.length == childCount ? order[drawingPosition] : drawingPosition;
    }

    /** Whether the layout and everything in it take no touch: it goes to whatever is behind. */
    private boolean ignoresInput;

    void setIgnoresInput(boolean ignores) {
        ignoresInput = ignores;
    }

    /** Whether the layout's own empty area lets a touch through to whatever is behind it; its children take theirs. */
    private boolean letsInputThrough;

    void setLetsInputThrough(boolean lets) {
        letsInputThrough = lets;
    }

    /** The listener hearing the touches no child takes, where the layout's element listens after its children. */
    private View.OnTouchListener ownListener;

    /** Where the touch under way goes: the child it landed on, or the layout itself. */
    private View touched;
    private boolean touchedItself;

    /** Whether the layout keeps a touch under way nothing in it took, from a parent of Android's own. */
    private boolean keeps;

    private final Matrix inverse = new Matrix();

    /** Where the last point `frontChildUnder` found a child at stands in that child. */
    private final float[] local = new float[2];

    /** The layout's gestures seeing the touches its children get, before they get them, where a hand moves it. */
    private final StateUIWatch watch = new StateUIWatch();

    /**
     * Lets `listener` see the layout's touches and its hovering pointer: before its children get them where a hand
     * moves the layout - a finger on a child answering a tap is the hand's once it moves along - else those no
     * child takes.
     */
    void watch(StateUIListener listener, boolean beforeChildren) {
        watch.watch(beforeChildren ? listener : null);
        ownListener = beforeChildren ? null : listener;
        setOnTouchListener(ownListener);
        setOnHoverListener(beforeChildren ? null : listener);
    }

    /**
     * A touch landing on the layout that nothing in it takes stays in it where its parent is a container of
     * Android's own holding another view under it, to which Android would hand it next - a page under an overlay;
     * any other parent hears it untaken, for its own handling.
     */
    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        boolean taken = !ignoresInput && watch.touch(this, event, this::reach);
        if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
            keeps = !taken && landsAt(event.getX(), event.getY()) && anotherBehind(event.getX(), event.getY());
        }
        return taken || keeps;
    }

    /** Whether a parent of Android's own holds another view under `x`, `y` of the layout. */
    private boolean anotherBehind(float x, float y) {
        if (!(getParent() instanceof ViewGroup) || getParent() instanceof StateUIViewGroup) return false;
        ViewGroup parent = (ViewGroup) getParent();
        float px = x + getX() - parent.getScrollX();
        float py = y + getY() - parent.getScrollY();
        for (int index = 0; index < parent.getChildCount(); index++) {
            View child = parent.getChildAt(index);
            if (child == this || child.getVisibility() != VISIBLE) continue;
            if (px >= child.getX() && py >= child.getY() && px < child.getX() + child.getWidth()
                    && py < child.getY() + child.getHeight()) return true;
        }
        return false;
    }

    /**
     * Hands a touch to the frontmost child under it alone, and to the layout's own handling where that child takes
     * none - never to a child behind it - as every platform hands a touch to the view under it and those around it.
     * Where it lands on no child, the layout's own area has it, unless it lets input through.
     */
    private boolean reach(MotionEvent event) {
        int action = event.getActionMasked();
        if (action == MotionEvent.ACTION_DOWN) {
            touched = frontChildUnder(event.getX(), event.getY());
            if (touched != null && toChild(touched, event)) return true;
            touched = null;
            touchedItself = ownTouch(event);
            return touchedItself;
        }
        boolean taken = touched != null ? toChild(touched, event) : touchedItself && ownTouch(event);
        if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
            touched = null;
            touchedItself = false;
        }
        return taken;
    }

    /** Whether a touch at `x`, `y` of the layout lands on it: on a child that takes it there, or its own area. */
    boolean landsAt(float x, float y) {
        return !ignoresInput && (frontChildUnder(x, y) != null || !letsInputThrough);
    }

    /** The deepest view a touch at `x`, `y` of the layout lands on, by the rule it hands touches by; null for none. */
    View hit(float x, float y) {
        if (ignoresInput) return null;
        View child = frontChildUnder(x, y);
        if (child == null) return letsInputThrough ? null : this;
        return child instanceof StateUIViewGroup ? ((StateUIViewGroup) child).hit(local[0], local[1]) : child;
    }

    /**
     * The deepest view a touch at `x`, `y` of `root` lands on: by the layouts' rule in a layout, front to back
     * through Android's own containers, where a view that is no container takes it; null for none.
     */
    static View hitIn(View root, float x, float y) {
        if (root instanceof StateUIViewGroup) return ((StateUIViewGroup) root).hit(x, y);
        if (!(root instanceof ViewGroup)) return root;
        ViewGroup group = (ViewGroup) root;
        Matrix inverse = new Matrix();
        for (int index = group.getChildCount() - 1; index >= 0; index--) {
            View child = group.getChildAt(index);
            if (child.getVisibility() != VISIBLE) continue;
            float[] point = {x + group.getScrollX() - child.getLeft(), y + group.getScrollY() - child.getTop()};
            if (!child.getMatrix().isIdentity()) {
                child.getMatrix().invert(inverse);
                inverse.mapPoints(point);
            }
            if (point[0] < 0 || point[1] < 0 || point[0] >= child.getWidth() || point[1] >= child.getHeight()) continue;
            View hit = hitIn(child, point[0], point[1]);
            if (hit != null) return hit;
        }
        return null;
    }

    /** Whether a touch at `x`, `y` of `root` reaches `target` or what stands in it - what a driver reads. */
    static boolean reaches(View root, float x, float y, View target) {
        View each = hitIn(root, x, y);
        while (each != null) {
            if (each == target) return true;
            each = each.getParent() instanceof View ? (View) each.getParent() : null;
        }
        return false;
    }

    /**
     * The child drawn frontmost under `x`, `y` of the layout that a touch there lands on; null for none. A child
     * hidden or clear is passed by, and so is a plain view answering no tap - a shade, an edge - which only draws.
     */
    private View frontChildUnder(float x, float y) {
        int count = getChildCount();
        boolean ordered = isChildrenDrawingOrderEnabled();
        float[] point = local;
        for (int position = count - 1; position >= 0; position--) {
            View child = getChildAt(ordered ? getChildDrawingOrder(count, position) : position);
            if (child.getVisibility() != VISIBLE || child.getAlpha() < 0.01f) continue;
            if (child.getClass() == View.class && !child.isClickable()) continue;
            point[0] = x + getScrollX() - child.getLeft();
            point[1] = y + getScrollY() - child.getTop();
            if (!child.getMatrix().isIdentity()) {
                child.getMatrix().invert(inverse);
                inverse.mapPoints(point);
            }
            if (point[0] < 0 || point[1] < 0 || point[0] >= child.getWidth() || point[1] >= child.getHeight()) continue;
            if (child instanceof StateUIViewGroup && !((StateUIViewGroup) child).landsAt(point[0], point[1])) continue;
            return child;
        }
        return null;
    }

    /** Hands `event` to `child` in its own coordinates; whether it takes it. */
    private boolean toChild(View child, MotionEvent event) {
        MotionEvent local = MotionEvent.obtain(event);
        local.offsetLocation(getScrollX() - child.getLeft(), getScrollY() - child.getTop());
        if (!child.getMatrix().isIdentity()) {
            child.getMatrix().invert(inverse);
            local.transform(inverse);
        }
        boolean taken = child.dispatchTouchEvent(local);
        local.recycle();
        return taken;
    }

    /** The layout's own handling of a touch: its listener, then its own click. */
    private boolean ownTouch(MotionEvent event) {
        if (ownListener != null && isEnabled() && ownListener.onTouch(this, event)) return true;
        return onTouchEvent(event);
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        return watch.hover(this, event, super::dispatchGenericMotionEvent);
    }

    /** A layout that does not scroll lets its children show a press at once. */
    @Override
    public boolean shouldDelayChildPressedState() {
        return false;
    }

    /**
     * Holds exactly {@code children}, in order, moving only what moved. A child moved within stays attached, as
     * removing it would take the keyboard from it.
     */
    void setChildren(View[] children) {
        for (int index = getChildCount() - 1; index >= 0; index--) {
            if (!holds(children, getChildAt(index))) removeViewAt(index);
        }

        boolean moved = false;
        for (int index = 0; index < children.length; index++) {
            View child = children[index];
            if (index < getChildCount() && getChildAt(index) == child) continue;

            ViewParent parent = child.getParent();
            if (parent == this) {
                detachViewFromParent(child);
                attachViewToParent(child, index, child.getLayoutParams());
                moved = true;
                continue;
            }
            if (parent instanceof ViewGroup) ((ViewGroup) parent).removeView(child);
            addView(child, index);
        }
        if (moved) {
            requestLayout();
            invalidate();
        }
    }

    private static boolean holds(View[] children, View child) {
        for (View each : children) {
            if (each == child) return true;
        }
        return false;
    }
}
