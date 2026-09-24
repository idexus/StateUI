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
 * polyline - placed in it by its aspect and then moved by its render transform; filled with a brush and
 * outlined. It asks for no room of its own.
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
    private final Matrix placing = new Matrix();
    private final RectF box = new RectF();
    private final Rect bounds = new Rect();

    private int kind = RECTANGLE;
    private final float[] radii = new float[8];
    private float strokeWidth;
    private int aspect;
    private Matrix transform;

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

    /** How drawn geometry is placed - fit, fill, stretch or centre - and the six numbers that then move it. */
    void setPlacement(int placement, float[] affine) {
        aspect = placement;
        if (affine.length >= 6) {
            transform = new Matrix();
            transform.setValues(new float[] {
                    affine[0], affine[2], affine[4], affine[1], affine[3], affine[5], 0, 0, 1});
        } else {
            transform = null;
        }
        invalidate();
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
                placed(shown);
        }

        if (brush.paint(fill, bounds)) canvas.drawPath(shown, fill);
        if (strokeWidth > 0) canvas.drawPath(shown, stroke);
    }

    /** The authored geometry, placed in the view by the aspect, centred, then moved by the render transform. */
    private void placed(Path into) {
        authored.computeBounds(box, true);
        float width = box.width();
        float height = box.height();
        float across = width > 0 ? getWidth() / width : Float.MAX_VALUE;
        float down = height > 0 ? getHeight() / height : Float.MAX_VALUE;
        float scaleX;
        float scaleY;
        switch (aspect) {
            case 2: scaleX = width > 0 ? across : 1; scaleY = height > 0 ? down : 1; break;
            case 3: scaleX = 1; scaleY = 1; break;
            case 1:
                scaleX = Math.max(width > 0 ? across : 0, height > 0 ? down : 0);
                scaleY = scaleX;
                break;
            default:
                scaleX = Math.min(across, down);
                if (scaleX == Float.MAX_VALUE) scaleX = 1;
                scaleY = scaleX;
        }
        if (width <= 0 && height <= 0) {
            scaleX = 1;
            scaleY = 1;
        }
        placing.setScale(scaleX, scaleY);
        placing.postTranslate(
                getWidth() / 2f - (box.left + width / 2) * scaleX, getHeight() / 2f - (box.top + height / 2) * scaleY);
        if (transform != null) placing.postConcat(transform);
        authored.transform(placing, into);
    }
}
