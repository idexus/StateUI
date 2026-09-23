// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;

/**
 * A StateUI layout: Android asks it to measure and place, and the Swift host
 * answers. It draws its children past its edges, as every StateUI layout does.
 */
final class StateUIViewGroup extends ViewGroup {
    private final long view;

    StateUIViewGroup(Context context, long view) {
        super(context);
        this.view = view;
        setClipChildren(false);
        setClipToPadding(false);
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

    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        return !ignoresInput && super.dispatchTouchEvent(event);
    }

    /** A layout that does not scroll lets its children show a press at once. */
    @Override
    public boolean shouldDelayChildPressedState() {
        return false;
    }

    /** Holds exactly {@code children}, in order, moving only what moved. */
    void setChildren(View[] children) {
        for (int index = getChildCount() - 1; index >= 0; index--) {
            if (!holds(children, getChildAt(index))) removeViewAt(index);
        }

        for (int index = 0; index < children.length; index++) {
            View child = children[index];
            if (index < getChildCount() && getChildAt(index) == child) continue;

            ViewParent parent = child.getParent();
            if (parent instanceof ViewGroup) ((ViewGroup) parent).removeView(child);
            addView(child, index);
        }
    }

    private static boolean holds(View[] children, View child) {
        for (View each : children) {
            if (each == child) return true;
        }
        return false;
    }
}
