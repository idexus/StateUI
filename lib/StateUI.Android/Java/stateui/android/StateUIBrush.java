// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.Rect;
import android.graphics.Shader;

/** A brush as StateUI says it - a colour, or a gradient's stops over a shape - put on a paint for the shape's bounds. */
final class StateUIBrush {
    /** The brush's kinds, as StateUI numbers them. */
    static final int NONE = 0;
    static final int SOLID = 1;
    static final int LINEAR = 2;
    static final int RADIAL = 3;

    private int kind = NONE;
    private int[] colors = new int[0];
    private float[] offsets = new float[0];
    private float[] geometry = new float[0];

    /** The brush: its kind, its stops' colours and offsets, and its geometry in fractions of the shape. */
    void set(int brush, int[] stopColors, float[] stopOffsets, float[] fractions) {
        kind = brush;
        colors = stopColors;
        offsets = stopOffsets;
        geometry = fractions;
    }

    /** Puts the brush's colour or shader for `bounds` on `paint`; false when there is nothing to paint. */
    boolean paint(Paint paint, Rect bounds) {
        paint.setShader(null);
        if (kind == SOLID && colors.length > 0) {
            paint.setColor(colors[0]);
            return true;
        }
        if (colors.length == 0) return false;

        float width = bounds.width();
        float height = bounds.height();
        int[] stops = colors.length == 1 ? new int[] {colors[0], colors[0]} : colors;
        float[] at = colors.length == 1 ? null : offsets;
        Shader shader = null;
        if (kind == LINEAR && geometry.length >= 4) {
            shader = new LinearGradient(
                    bounds.left + width * geometry[0], bounds.top + height * geometry[1],
                    bounds.left + width * geometry[2], bounds.top + height * geometry[3],
                    stops, at, Shader.TileMode.CLAMP);
        } else if (kind == RADIAL && geometry.length >= 3) {
            float radius = Math.max(Math.max(width, height) * geometry[2], 0.001f);
            shader = new RadialGradient(
                    bounds.left + width * geometry[0], bounds.top + height * geometry[1],
                    radius, stops, at, Shader.TileMode.CLAMP);
        }
        if (shader == null) return false;

        paint.setColor(0xFF000000);
        paint.setShader(shader);
        return true;
    }
}
