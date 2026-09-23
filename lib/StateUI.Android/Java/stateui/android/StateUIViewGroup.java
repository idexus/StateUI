// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;

/** A StateUI layout: Android asks it to measure and place, and the Swift host answers. */
final class StateUIViewGroup extends ViewGroup {
    private final long view;

    StateUIViewGroup(Context context, long view) {
        super(context);
        this.view = view;
    }

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        long size = StateUIHost.measure(view, widthSpec, heightSpec);
        setMeasuredDimension((int) (size >>> 32), (int) size);
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        StateUIHost.arrange(view, right - left, bottom - top);
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
