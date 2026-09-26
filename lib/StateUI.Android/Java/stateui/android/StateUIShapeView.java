// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.DashPathEffect;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.RectF;
import android.view.View;

/**
 * A shape: a rectangle or an ellipse filling the view, or drawn geometry - a line, a path, a polygon, a
 * polyline - moved by the six numbers the Swift host places it with; filled with a brush and outlined. It asks
 * for no room of its own.
 */
final class StateUIShapeView extends View {
    /** The shape's kinds, as the Swift host numbers them. */
    static final int RECTANGLE = 0;
    static final int ELLIPSE = 1;
    static final int DRAWN = 2;

    /** A drawn command's kinds, as the Swift host numbers them, each followed by its points. */
    static final int MOVE = 0;
    static final int LINE = 1;
    static final int CUBIC = 2;
    static final int QUADRATIC = 3;
    static final int CLOSE = 4;

    private final StateUIBrush brush = new StateUIBrush();
    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path authored = new Path();
    private final Path shown = new Path();
    /** Where the shape is moved to, as the Swift host places it; none leaves it where it is drawn. */
    private Matrix placing;
    private final RectF box = new RectF();
    private final Rect bounds = new Rect();

    private int kind = RECTANGLE;
    private final float[] radii = new float[8];
    private float strokeWidth;

    StateUIShapeView(Context context) {
        super(context);
        fill.setStyle(Paint.Style.FILL);
        stroke.setStyle(Paint.Style.STROKE);
    }

    /**
     * The shape: its kind, a rectangle's corners' radii in pixels - top left, top right, bottom right, bottom
     * left - and drawn geometry as commands in pixels, filled even-odd or not.
     */
    void setGeometry(int shape, float[] corners, float[] commands, boolean evenOdd) {
        kind = shape;
        for (int corner = 0; corner < 4 && corner < corners.length; corner++) {
            radii[corner * 2] = corners[corner];
            radii[corner * 2 + 1] = corners[corner];
        }
        authored.rewind();
        int index = 0;
        while (index < commands.length) {
            switch ((int) commands[index]) {
                case MOVE: authored.moveTo(commands[index + 1], commands[index + 2]); index += 3; break;
                case LINE: authored.lineTo(commands[index + 1], commands[index + 2]); index += 3; break;
                case CUBIC:
                    authored.cubicTo(commands[index + 1], commands[index + 2], commands[index + 3],
                            commands[index + 4], commands[index + 5], commands[index + 6]);
                    index += 7;
                    break;
                case QUADRATIC:
                    authored.quadTo(commands[index + 1], commands[index + 2], commands[index + 3], commands[index + 4]);
                    index += 5;
                    break;
                default: authored.close(); index += 1;
            }
        }
        authored.setFillType(evenOdd ? Path.FillType.EVEN_ODD : Path.FillType.WINDING);
        invalidate();
    }

    /** The brush: its kind, its stops' colours and offsets, and its geometry in fractions of the view. */
    void setFill(int kind, int[] stopColors, float[] stopOffsets, float[] fractions) {
        brush.set(kind, stopColors, stopOffsets, fractions);
        invalidate();
    }

    /**
     * The outline: its colour, its width in pixels - none at zero - its dashes and their offset in pixels,
     * its caps and joins as StateUI numbers them, and the miter limit.
     */
    void setStroke(int color, float width, float[] dashes, float dashOffset, int cap, int join, float miterLimit) {
        stroke.setColor(color);
        strokeWidth = width;
        stroke.setStrokeWidth(width);
        stroke.setPathEffect(dashes.length >= 2 ? new DashPathEffect(dashes, dashOffset) : null);
        stroke.setStrokeCap(cap == 1 ? Paint.Cap.ROUND : cap == 2 ? Paint.Cap.SQUARE : Paint.Cap.BUTT);
        stroke.setStrokeJoin(join == 1 ? Paint.Join.BEVEL : join == 2 ? Paint.Join.ROUND : Paint.Join.MITER);
        stroke.setStrokeMiter(miterLimit);
        invalidate();
    }

    /**
     * The six numbers - a, b, c, d, tx, ty in pixels - that move what the shape draws, a point (x, y) going to
     * (a x + c y + tx, b x + d y + ty); none leaves it where it is drawn.
     */
    void setPlacing(float[] affine) {
        if (affine.length >= 6) {
            placing = new Matrix();
            placing.setValues(new float[] {affine[0], affine[2], affine[4], affine[1], affine[3], affine[5], 0, 0, 1});
        } else {
            placing = null;
        }
        invalidate();
    }

    /** Where the drawn geometry stands before it is moved, in pixels: left, top, width, height. */
    float[] geometryBounds() {
        authored.computeBounds(box, true);
        return new float[] {box.left, box.top, box.width(), box.height()};
    }

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        setMeasuredDimension(resolveSize(0, widthSpec), resolveSize(0, heightSpec));
    }

    @Override
    protected void onDraw(Canvas canvas) {
        bounds.set(0, 0, getWidth(), getHeight());
        float inset = strokeWidth / 2;
        shown.rewind();
        switch (kind) {
            case RECTANGLE:
                box.set(inset, inset, getWidth() - inset, getHeight() - inset);
                shown.addRoundRect(box, radii, Path.Direction.CW);
                break;
            case ELLIPSE:
                box.set(inset, inset, getWidth() - inset, getHeight() - inset);
                shown.addOval(box, Path.Direction.CW);
                break;
            default:
                shown.set(authored);
        }
        if (placing != null) shown.transform(placing);

        if (brush.paint(fill, bounds)) canvas.drawPath(shown, fill);
        if (strokeWidth > 0) canvas.drawPath(shown, stroke);
    }
}
