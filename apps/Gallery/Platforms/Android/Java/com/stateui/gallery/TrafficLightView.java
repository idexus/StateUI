// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package com.stateui.gallery;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.MotionEvent;
import android.view.View;

// listing: InteropControlSample.Android.java
/** Three lamps in a dark housing, one lit; a tap on a lamp is told, and lights nothing by itself. */
final class TrafficLightView extends View {
    private static final int[] LAMPS = {0xFFE5484D, 0xFFF5B546, 0xFF46B45F};
    private static final float LAMP = 44, SPACING = 10, PADDING = 12;

    private final long control;
    private final float density;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF housing = new RectF();
    private int signal = -1;

    TrafficLightView(Context context, long control) {
        super(context);
        this.control = control;
        density = context.getResources().getDisplayMetrics().density;
        setClickable(true);
    }

    /** Which lamp is lit, from the top; none for any other number. */
    void setSignal(int lamp) {
        if (lamp == signal) return;
        signal = lamp;
        invalidate();
    }

    /** How big it is, which the host asks by measuring it as Android measures any view. */
    @Override
    protected void onMeasure(int width, int height) {
        setMeasuredDimension(
                resolveSize(Math.round((PADDING * 2 + LAMP) * density), width),
                resolveSize(Math.round((PADDING * 2 + LAMP * 3 + SPACING * 2) * density), height));
    }

    @Override
    protected void onDraw(Canvas canvas) {
        housing.set(0, 0, getWidth(), getHeight());
        paint.setColor(0xFF1A1725);
        canvas.drawRoundRect(housing, 18 * density, 18 * density, paint);
        for (int lamp = 0; lamp < 3; lamp++) {
            paint.setColor(lamp == signal ? LAMPS[lamp] : (LAMPS[lamp] & 0x00FFFFFF) | 0x2E000000);
            canvas.drawCircle(getWidth() / 2f, centre(lamp), LAMP / 2 * density, paint);
        }
    }

    /** Tells a tapped lamp to the Swift half by the number it made this view with; whoever owns the state decides. */
    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (event.getActionMasked() == MotionEvent.ACTION_UP) {
            for (int lamp = 0; lamp < 3; lamp++) {
                if (Math.abs(event.getY() - centre(lamp)) <= LAMP / 2 * density) {
                    GalleryNatives.lampTapped(control, lamp);
                    break;
                }
            }
        }
        return true;
    }

    private float centre(int lamp) {
        return (PADDING + LAMP / 2 + lamp * (LAMP + SPACING)) * density;
    }
}
// listing: end
