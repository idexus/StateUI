// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package com.stateui.gallery;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.MotionEvent;
import android.view.View;

/** Stars, as many lit as the rating; a tap chooses the star under it and tells it. */
final class RatingBarView extends View {
    private static final int LIT = 0xFFF5B546, EMBER = 0x38F5B546;
    private static final float STAR = 34, SPACING = 6;

    private final long control;
    private final float density;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private double rating;
    private int stars = 5;

    RatingBarView(Context context, long control) {
        super(context);
        this.control = control;
        density = context.getResources().getDisplayMetrics().density;
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setTextSize(STAR * density);
        setClickable(true);
    }

    /** Shows {@code count} stars, {@code value} of them lit: the stars first, so a rating stands within them. */
    void show(double value, int count) {
        int counted = Math.max(count, 1);
        double held = Math.min(Math.max(value, 0), counted);
        if (counted == stars && held == rating) return;
        if (counted != stars) {
            stars = counted;
            requestLayout();
        }
        rating = held;
        invalidate();
    }

    // listing: InteropActsSample.Android.java
    /** Fades the bar out and back, as its act asks. */
    void flash() {
        animate().alpha(0.25f).setDuration(120).withEndAction(() -> animate().alpha(1).setDuration(120));
    }
    // listing: end

    @Override
    protected void onMeasure(int width, int height) {
        Paint.FontMetrics metrics = paint.getFontMetrics();
        setMeasuredDimension(
                resolveSize(Math.round((STAR * stars + SPACING * (stars - 1)) * density), width),
                resolveSize(Math.round(metrics.descent - metrics.ascent), height));
    }

    @Override
    protected void onDraw(Canvas canvas) {
        float width = (getWidth() - SPACING * (stars - 1) * density) / stars;
        Paint.FontMetrics metrics = paint.getFontMetrics();
        float baseline = (getHeight() - metrics.descent - metrics.ascent) / 2;
        for (int star = 0; star < stars; star++) {
            paint.setColor(rating >= star + 1 ? LIT : EMBER);
            canvas.drawText("★", star * (width + SPACING * density) + width / 2, baseline, paint);
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (event.getActionMasked() == MotionEvent.ACTION_UP && getWidth() > 0) {
            int star = (int) (event.getX() / ((float) getWidth() / stars));
            double chosen = Math.min(Math.max(star, 0), stars - 1) + 1;
            show(chosen, stars);
            GalleryNatives.rated(control, chosen);
        }
        return true;
    }
}
