// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Outline;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;

/**
 * A shape filled with a brush and outlined: a layout's own box, a ColorBox's,
 * or a background painted with a gradient. The Swift host says every part.
 */
final class StateUIShapeDrawable extends Drawable {
    /** The shape's kinds, as the Swift host numbers them. */
    static final int RECTANGLE = 0;
    static final int ROUNDED = 1;
    static final int ELLIPSE = 2;

    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final RectF box = new RectF();

    private int shape = RECTANGLE;
    private float[] radii = new float[8];
    private final StateUIBrush brush = new StateUIBrush();
    private float strokeWidth;
    private int strokeColor;

    /** How opaque the drawing is, 0 to 255, as the drawable was told. */
    private int alpha = 255;

    /** How opaque the drawing is while its view is disabled; at 1 it never dims. */
    private float disabledAlpha = 1;
    private boolean enabled = true;

    StateUIShapeDrawable() {
        fill.setStyle(Paint.Style.FILL);
        stroke.setStyle(Paint.Style.STROKE);
    }

    /**
     * The shape: a rectangle, one with rounded corners - each corner's width and height in pixels, clockwise
     * from the top left, as the Swift host fitted them - or an ellipse.
     */
    void setShape(int kind, float[] corners) {
        shape = kind;
        System.arraycopy(corners, 0, radii, 0, Math.min(corners.length, radii.length));
        invalidateSelf();
    }

    /**
     * The brush: its kind, its stops' colours and offsets, its points in fractions of the shape and a radial
     * one's reach in pixels.
     */
    void setFill(int kind, int[] stopColors, float[] stopOffsets, float[] fractions) {
        brush.set(kind, stopColors, stopOffsets, fractions);
        invalidateSelf();
    }

    /** The outline's colour, and its width in pixels; none at zero. */
    void setStroke(int color, float width) {
        strokeColor = color;
        strokeWidth = width;
        stroke.setStrokeWidth(width);
        invalidateSelf();
    }

    @Override
    public void draw(Canvas canvas) {
        Rect bounds = getBounds();
        float inset = strokeWidth / 2;
        box.set(bounds.left + inset, bounds.top + inset, bounds.right - inset, bounds.bottom - inset);
        path.rewind();
        switch (shape) {
            case ROUNDED: path.addRoundRect(box, radii, Path.Direction.CW); break;
            case ELLIPSE: path.addOval(box, Path.Direction.CW); break;
            default: path.addRect(box, Path.Direction.CW);
        }

        float opacity = alpha / 255f * (enabled ? 1 : disabledAlpha);
        if (brush.paint(fill, bounds)) {
            fill.setAlpha(Math.round(fill.getAlpha() * opacity));
            canvas.drawPath(path, fill);
        }
        if (strokeWidth > 0) {
            stroke.setColor(strokeColor);
            stroke.setAlpha(Math.round(stroke.getAlpha() * opacity));
            canvas.drawPath(path, stroke);
        }
    }

    /** Dims the drawing to `value` while its view is disabled, as the theme's controls dim. */
    void setDisabledAlpha(float value) {
        disabledAlpha = value;
        invalidateSelf();
    }

    @Override
    public boolean isStateful() {
        return disabledAlpha < 1;
    }

    @Override
    protected boolean onStateChange(int[] state) {
        boolean now = false;
        for (int one : state) now |= one == android.R.attr.state_enabled;
        if (now == enabled) return false;
        enabled = now;
        invalidateSelf();
        return true;
    }

    /**
     * The shape as the view's outline, which is what a view clipping its content cuts to: one radius for every
     * corner, the top left's narrower way, as an outline takes it.
     */
    @Override
    public void getOutline(Outline outline) {
        Rect bounds = getBounds();
        switch (shape) {
            case ROUNDED:
                outline.setRoundRect(bounds, Math.min(radii[0], radii[1]));
                break;
            case ELLIPSE:
                outline.setOval(bounds);
                break;
            default:
                outline.setRect(bounds);
        }
    }

    @Override
    public void setAlpha(int value) {
        alpha = value;
        invalidateSelf();
    }

    @Override
    public int getAlpha() {
        return alpha;
    }

    @Override
    public void setColorFilter(ColorFilter filter) {}

    /** Deprecated since API 29, and still abstract: every drawable answers it. */
    @Override
    @SuppressWarnings("deprecation")
    public int getOpacity() {
        return PixelFormat.TRANSLUCENT;
    }
}
