// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.view.MotionEvent;
import android.view.View;
import java.util.ArrayDeque;

/**
 * A canvas: StateUI's drawing instructions replayed in the order they were written, inside the view's own
 * bounds, in points. The Swift host sends the whole drawing in one call - each instruction's kind, colours,
 * flags and text as ints, its numbers as floats, its text as strings - and a finger's press, drag and
 * release come back in points.
 */
final class StateUICanvasView extends View {
    /** The instructions' kinds, as StateUI numbers them. */
    private static final int FILL_COLOR = 0, STROKE_COLOR = 1, TEXT_COLOR = 2, STROKE_WIDTH = 3, FONT_SIZE = 4,
            ALPHA = 5, DRAW_LINE = 6, DRAW_RECTANGLE = 7, DRAW_ROUNDED_RECTANGLE = 8, DRAW_ELLIPSE = 9,
            DRAW_ARC = 10, DRAW_PATH = 11, FILL_RECTANGLE = 12, FILL_ROUNDED_RECTANGLE = 13, FILL_ELLIPSE = 14,
            FILL_ARC = 15, FILL_PATH = 16, DRAW_TEXT = 17, TRANSLATE = 18, ROTATE = 19, SCALE = 20, SAVE = 21,
            RESTORE = 22;

    /** A path command's kinds, as the Swift host numbers them, each followed by its points. */
    private static final int MOVE = 0, LINE = 1, CUBIC = 2, QUADRATIC = 3;

    private final long view;
    private final float density;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final TextPaint words = new TextPaint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final RectF box = new RectF();

    private int[] ints = new int[0];
    private float[] numbers = new float[0];
    private String[] strings = new String[0];

    /** What an instruction may change, kept and put back by `saveState` and `restoreState`. */
    private static final class State {
        int fill = 0xFF000000, stroke = 0xFF000000, text = 0xFF000000;
        float strokeWidth = 1, fontSize = 14, alpha = 1;

        State copy() {
            State copy = new State();
            copy.fill = fill; copy.stroke = stroke; copy.text = text;
            copy.strokeWidth = strokeWidth; copy.fontSize = fontSize; copy.alpha = alpha;
            return copy;
        }
    }

    StateUICanvasView(Context context, long view, float density) {
        super(context);
        this.view = view;
        this.density = density;
    }

    /** The drawing: its instructions' ints, numbers and strings, in the order the host wrote them. */
    void setDrawing(int[] kindsAndInts, float[] values, String[] texts) {
        ints = kindsAndInts;
        numbers = values;
        strings = texts;
        invalidate();
    }

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        setMeasuredDimension(resolveSize(0, widthSpec), resolveSize(0, heightSpec));
    }

    @Override
    protected void onDraw(Canvas canvas) {
        canvas.save();
        canvas.clipRect(0, 0, getWidth(), getHeight());
        canvas.scale(density, density);

        State state = new State();
        ArrayDeque<State> saved = new ArrayDeque<>();
        int at = 0;
        int number = 0;
        while (at < ints.length) {
            int kind = ints[at++];
            switch (kind) {
                case FILL_COLOR: state.fill = ints[at++]; break;
                case STROKE_COLOR: state.stroke = ints[at++]; break;
                case TEXT_COLOR: state.text = ints[at++]; break;
                case STROKE_WIDTH: state.strokeWidth = Math.max(0, numbers[number++]); break;
                case FONT_SIZE: state.fontSize = Math.max(0, numbers[number++]); break;
                case ALPHA: state.alpha = Math.min(Math.max(numbers[number++], 0), 1); break;
                case DRAW_LINE:
                    if (stroking(state)) {
                        canvas.drawLine(numbers[number], numbers[number + 1], numbers[number + 2], numbers[number + 3], paint);
                    }
                    number += 4;
                    break;
                case DRAW_RECTANGLE: case FILL_RECTANGLE:
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    number += 4;
                    if (kind == FILL_RECTANGLE ? filling(state) : stroking(state)) canvas.drawRect(box, paint);
                    break;
                case DRAW_ROUNDED_RECTANGLE: case FILL_ROUNDED_RECTANGLE: {
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    float radius = Math.max(0, numbers[number + 4]);
                    number += 5;
                    if (kind == FILL_ROUNDED_RECTANGLE ? filling(state) : stroking(state)) {
                        canvas.drawRoundRect(box, radius, radius, paint);
                    }
                    break;
                }
                case DRAW_ELLIPSE: case FILL_ELLIPSE:
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    number += 4;
                    if (kind == FILL_ELLIPSE ? filling(state) : stroking(state)) canvas.drawOval(box, paint);
                    break;
                case DRAW_ARC: case FILL_ARC: {
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    float start = numbers[number + 4];
                    float end = numbers[number + 5];
                    number += 6;
                    boolean clockwise = ints[at++] != 0;
                    boolean closed = kind == FILL_ARC || ints[at++] != 0;
                    arc(start, end, clockwise, closed, kind == FILL_ARC);
                    if (kind == FILL_ARC ? filling(state) : stroking(state)) canvas.drawPath(path, paint);
                    break;
                }
                case DRAW_PATH: case FILL_PATH: {
                    int count = ints[at++];
                    number = path(number, count);
                    if (kind == FILL_PATH ? filling(state) : stroking(state)) canvas.drawPath(path, paint);
                    break;
                }
                case DRAW_TEXT: {
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    number += 4;
                    int horizontal = ints[at++];
                    int vertical = ints[at++];
                    text(canvas, strings[ints[at++]], horizontal, vertical, state);
                    break;
                }
                case TRANSLATE: canvas.translate(numbers[number], numbers[number + 1]); number += 2; break;
                case ROTATE: canvas.rotate(numbers[number++]); break;
                case SCALE: canvas.scale(numbers[number], numbers[number + 1]); number += 2; break;
                case SAVE:
                    saved.push(state.copy());
                    canvas.save();
                    break;
                case RESTORE:
                    if (!saved.isEmpty()) {
                        state = saved.pop();
                        canvas.restore();
                    }
                    break;
                default: return;
            }
        }
        while (!saved.isEmpty()) {
            saved.pop();
            canvas.restore();
        }
        canvas.restore();
    }

    private boolean filling(State state) {
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(state.fill);
        paint.setAlpha(Math.round(((state.fill >>> 24) & 0xFF) * state.alpha));
        return true;
    }

    private boolean stroking(State state) {
        if (state.strokeWidth <= 0) return false;
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(state.strokeWidth);
        paint.setColor(state.stroke);
        paint.setAlpha(Math.round(((state.stroke >>> 24) & 0xFF) * state.alpha));
        return true;
    }

    /** An arc of the ellipse in `box`, from `start` to `end` degrees the way it turns; a wedge from its middle. */
    private void arc(float start, float end, boolean clockwise, boolean closed, boolean wedge) {
        if (clockwise) {
            while (end < start) end += 360;
        } else {
            while (end > start) end -= 360;
        }
        path.rewind();
        if (wedge) path.moveTo(box.centerX(), box.centerY());
        path.arcTo(box, start, end - start, !wedge);
        if (closed) path.close();
    }

    /** `count` path commands read from `numbers` at `number`; answers where the next instruction's start. */
    private int path(int number, int count) {
        path.rewind();
        for (int command = 0; command < count; command++) {
            switch ((int) numbers[number]) {
                case MOVE: path.moveTo(numbers[number + 1], numbers[number + 2]); number += 3; break;
                case LINE: path.lineTo(numbers[number + 1], numbers[number + 2]); number += 3; break;
                case CUBIC:
                    path.cubicTo(numbers[number + 1], numbers[number + 2], numbers[number + 3],
                            numbers[number + 4], numbers[number + 5], numbers[number + 6]);
                    number += 7;
                    break;
                case QUADRATIC:
                    path.quadTo(numbers[number + 1], numbers[number + 2], numbers[number + 3], numbers[number + 4]);
                    number += 5;
                    break;
                default: path.close(); number += 1;
            }
        }
        return number;
    }

    /** `text` wrapped in `box`, across it and down it as the instruction says, cut at its edges. */
    private void text(Canvas canvas, String text, int horizontal, int vertical, State state) {
        words.setTextSize(state.fontSize);
        words.setColor(state.text);
        words.setAlpha(Math.round(((state.text >>> 24) & 0xFF) * state.alpha));
        Layout.Alignment across = horizontal == 1 ? Layout.Alignment.ALIGN_CENTER
                : horizontal == 2 ? Layout.Alignment.ALIGN_OPPOSITE : Layout.Alignment.ALIGN_NORMAL;
        StaticLayout lines = StaticLayout.Builder
                .obtain(text, 0, text.length(), words, Math.max(1, (int) Math.ceil(box.width())))
                .setAlignment(across)
                .build();
        float height = lines.getHeight();
        float top = vertical == 1 ? box.centerY() - height / 2 : vertical == 2 ? box.bottom - height : box.top;
        canvas.save();
        canvas.clipRect(box);
        canvas.translate(box.left, top);
        lines.draw(canvas);
        canvas.restore();
    }

    /** A finger's press, drag and release, reported in points. */
    @Override
    public boolean onTouchEvent(MotionEvent event) {
        float x = event.getX() / density;
        float y = event.getY() / density;
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN: StateUIHost.canvasTouched(view, 0, x, y); return true;
            case MotionEvent.ACTION_MOVE: StateUIHost.canvasTouched(view, 1, x, y); return true;
            case MotionEvent.ACTION_UP: case MotionEvent.ACTION_CANCEL:
                StateUIHost.canvasTouched(view, 2, x, y);
                return true;
            default: return super.onTouchEvent(event);
        }
    }
}
