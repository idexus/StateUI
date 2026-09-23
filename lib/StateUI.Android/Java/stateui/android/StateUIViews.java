// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.View;

/** What the Swift host does to a view in one call where Android asks for several. */
final class StateUIViews {
    private StateUIViews() {}

    /** Measures the view for the two specs; its width in the high half, its height in the low one. */
    static long measure(View view, int widthSpec, int heightSpec) {
        view.measure(widthSpec, heightSpec);
        return ((long) view.getMeasuredWidth() << 32) | (view.getMeasuredHeight() & 0xFFFFFFFFL);
    }

    /**
     * Measures the view at exactly its place, then lays it out there. A view laid out at that size, with nothing
     * in it asking to be laid out again, is only moved: its drawing, and a layer holding it, stay as they are.
     */
    static void place(View view, int left, int top, int right, int bottom) {
        if (view.isLaidOut() && !view.isLayoutRequested()
                && view.getWidth() == right - left && view.getHeight() == bottom - top) {
            view.offsetLeftAndRight(left - view.getLeft());
            view.offsetTopAndBottom(top - view.getTop());
            return;
        }

        view.measure(
                View.MeasureSpec.makeMeasureSpec(right - left, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(bottom - top, View.MeasureSpec.EXACTLY));
        view.layout(left, top, right, bottom);
    }

    /** Moves, turns and scales the view about its pivot, in pixels; a pivot of NaN is its centre. */
    static void transform(View view, float translationX, float translationY, float rotation,
            float rotationX, float rotationY, float scaleX, float scaleY, float pivotX, float pivotY) {
        view.setTranslationX(translationX);
        view.setTranslationY(translationY);
        view.setRotation(rotation);
        view.setRotationX(rotationX);
        view.setRotationY(rotationY);
        view.setScaleX(scaleX);
        view.setScaleY(scaleY);
        if (Float.isNaN(pivotX)) {
            view.resetPivot();
        } else {
            view.setPivotX(pivotX);
            view.setPivotY(pivotY);
        }
    }
}
