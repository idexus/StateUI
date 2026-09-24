// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.content.res.ColorStateList;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.LayerDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.TextView;

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

    /** Slides the view across to `translationX` pixels and fades it to `alpha`, over `duration` milliseconds. */
    static void slide(View view, float translationX, float alpha, long duration) {
        view.animate().cancel();
        if (duration <= 0) {
            view.setTranslationX(translationX);
            view.setAlpha(alpha);
            return;
        }
        view.animate().translationX(translationX).alpha(alpha).setDuration(duration).start();
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

    /**
     * `look` under the platform's pressed ripple, in its theme's colour, kept within `mask`'s shape; the look
     * dims while its view is disabled, as the theme's controls dim.
     */
    static Drawable pressable(Context context, StateUIShapeDrawable look, Drawable mask) {
        TypedArray theme = context.obtainStyledAttributes(new int[] {android.R.attr.colorControlHighlight});
        ColorStateList highlight = theme.getColorStateList(0);
        theme.recycle();
        look.setDisabledAlpha(disabledAlpha(context));
        return new RippleDrawable(
                highlight != null ? highlight : ColorStateList.valueOf(0x33000000), look, mask);
    }

    /** Words in `color`, dimmed while their view is disabled, as the theme's own colours are. */
    static ColorStateList textColors(Context context, int color) {
        int dimmed = (Math.round(Color.alpha(color) * disabledAlpha(context)) << 24) | (color & 0xFFFFFF);
        return new ColorStateList(
                new int[][] {new int[] {-android.R.attr.state_enabled}, new int[0]}, new int[] {dimmed, color});
    }

    /** How opaque the theme draws a disabled control. */
    private static float disabledAlpha(Context context) {
        TypedArray theme = context.obtainStyledAttributes(new int[] {android.R.attr.disabledAlpha});
        float alpha = theme.getFloat(0, 0.38f);
        theme.recycle();
        return alpha;
    }

    /**
     * Puts `picture` beside the view's words - 0 before them, 1 after, 2 above, 3 below - `gap` pixels
     * away, or the platform's gap for -1, at its own size; with no words, alone in the middle of the view
     * at `width` by `height` pixels. A null picture takes it away.
     */
    static void setIcon(TextView view, Bitmap picture, int position, int gap, int width, int height) {
        Drawable icon = picture == null ? null : new BitmapDrawable(view.getResources(), picture);
        boolean alone = view.getText().length() == 0;
        Drawable beside = alone ? null : icon;

        if (gap >= 0) view.setCompoundDrawablePadding(gap);
        view.setCompoundDrawablesRelativeWithIntrinsicBounds(
                position == 0 ? beside : null, position == 2 ? beside : null,
                position == 1 ? beside : null, position == 3 ? beside : null);

        if (!alone || icon == null) {
            view.setForeground(null);
            return;
        }
        LayerDrawable centred = new LayerDrawable(new Drawable[] {icon});
        centred.setLayerGravity(0, Gravity.CENTER);
        centred.setLayerSize(0, width, height);
        view.setForeground(centred);
    }
}
