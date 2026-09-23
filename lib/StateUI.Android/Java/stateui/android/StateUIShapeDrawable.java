// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.LinearGradient;
import android.graphics.Outline;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.RadialGradient;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.drawable.Drawable;

/**
 * A shape filled with a brush and outlined: a Border's drawing, a ColorBox's,
 * or a background painted with a gradient. The Swift host says every part.
 */
final class StateUIShapeDrawable extends Drawable {
    /** The shape's kinds, as the Swift host numbers them. */
    static final int RECTANGLE = 0;
    static final int ROUNDED = 1;
    static final int ELLIPSE = 2;

    /** The brush's kinds, as StateUI numbers them. */
    static final int NONE = 0;
    static final int SOLID = 1;
    static final int LINEAR = 2;
    static final int RADIAL = 3;

    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final RectF box = new RectF();

    private int shape = RECTANGLE;
    private float[] radii = new float[8];
    private int brush = NONE;
    private int[] colors = new int[0];
    private float[] offsets = new float[0];
    private float[] geometry = new float[0];
    private float strokeWidth;

    StateUIShapeDrawable() {
        fill.setStyle(Paint.Style.FILL);
        stroke.setStyle(Paint.Style.STROKE);
    }

    /** The shape: a rectangle, one with the corners' radii in pixels - top left, top right, bottom right, bottom left - or an ellipse. */
    void setShape(int kind, float[] corners) {
        shape = kind;
        for (int corner = 0; corner < 4; corner++) {
            radii[corner * 2] = corners[corner];
            radii[corner * 2 + 1] = corners[corner];
        }
        invalidateSelf();
    }

    /** The brush: its kind, its stops' colours and offsets, and its geometry in fractions of the shape. */
    void setFill(int kind, int[] stopColors, float[] stopOffsets, float[] fractions) {
        brush = kind;
        colors = stopColors;
        offsets = stopOffsets;
        geometry = fractions;
        invalidateSelf();
    }

    /** The outline's colour, and its width in pixels; none at zero. */
    void setStroke(int color, float width) {
        stroke.setColor(color);
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
            case ROUNDED: path.addRoundRect(box, fitted(box), Path.Direction.CW); break;
            case ELLIPSE: path.addOval(box, Path.Direction.CW); break;
            default: path.addRect(box, Path.Direction.CW);
        }

        if (paint(bounds)) canvas.drawPath(path, fill);
        if (strokeWidth > 0) canvas.drawPath(path, stroke);
    }

    /** Sets the fill's colour or shader for `bounds`; false when there is nothing to fill. */
    private boolean paint(Rect bounds) {
        fill.setShader(null);
        if (brush == SOLID && colors.length > 0) {
            fill.setColor(colors[0]);
            return true;
        }
        if (colors.length == 0) return false;

        float width = bounds.width();
        float height = bounds.height();
        int[] stops = colors.length == 1 ? new int[] { colors[0], colors[0] } : colors;
        float[] at = colors.length == 1 ? null : offsets;
        Shader shader = null;
        if (brush == LINEAR && geometry.length >= 4) {
            shader = new LinearGradient(
                    bounds.left + width * geometry[0], bounds.top + height * geometry[1],
                    bounds.left + width * geometry[2], bounds.top + height * geometry[3],
                    stops, at, Shader.TileMode.CLAMP);
        } else if (brush == RADIAL && geometry.length >= 3) {
            float radius = Math.max(Math.max(width, height) * geometry[2], 0.001f);
            shader = new RadialGradient(
                    bounds.left + width * geometry[0], bounds.top + height * geometry[1],
                    radius, stops, at, Shader.TileMode.CLAMP);
        }
        if (shader == null) return false;

        fill.setColor(0xFF000000);
        fill.setShader(shader);
        return true;
    }

    /** The corners' radii, shrunk together where two meeting on one side would overlap. */
    private float[] fitted(RectF rect) {
        float factor = 1;
        factor = Math.min(factor, share(rect.width(), radii[0] + radii[2]));
        factor = Math.min(factor, share(rect.width(), radii[4] + radii[6]));
        factor = Math.min(factor, share(rect.height(), radii[0] + radii[6]));
        factor = Math.min(factor, share(rect.height(), radii[2] + radii[4]));
        if (factor >= 1) return radii;

        float[] scaled = new float[8];
        for (int index = 0; index < 8; index++) scaled[index] = radii[index] * factor;
        return scaled;
    }

    private static float share(float length, float taken) {
        return taken > 0 ? Math.max(0, length) / taken : 1;
    }

    /** The shape as the view's outline, which is what a view clipping its content cuts to. */
    @Override
    public void getOutline(Outline outline) {
        Rect bounds = getBounds();
        switch (shape) {
            case ROUNDED:
                box.set(bounds);
                outline.setRoundRect(bounds, fitted(box)[0]);
                break;
            case ELLIPSE:
                outline.setOval(bounds);
                break;
            default:
                outline.setRect(bounds);
        }
    }

    @Override
    public void setAlpha(int alpha) {}

    @Override
    public void setColorFilter(ColorFilter filter) {}

    @Override
    public int getOpacity() {
        return PixelFormat.TRANSLUCENT;
    }
}
