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
import android.text.TextDirectionHeuristics;
import android.text.TextPaint;
import android.view.MotionEvent;
import android.view.View;
import java.util.ArrayDeque;

/**
 * A canvas: StateUI's drawing instructions replayed in the order they were written, inside the view's own
 * bounds, in points. The Swift host sends the whole drawing in one call - each instruction's kind and colors,
 * a text's alignments and index and a path's count of curves as ints, its numbers as floats, its text as
 * strings, an arc as the curves it runs along - and a finger's press, drag and release come back in points.
 */
final class StateUICanvasView extends View {
    /** The instructions' kinds, as StateUI numbers them. */
    // Swift: HostDrawing.Kind
    private static final int FILL_COLOR = 0, STROKE_COLOR = 1, TEXT_COLOR = 2, LINE_WIDTH = 3, FONT_SIZE = 4,
            OPACITY = 5, STROKE_LINE = 6, STROKE_RECTANGLE = 7, STROKE_ROUNDED_RECTANGLE = 8, STROKE_ELLIPSE = 9,
            STROKE_PATH = 11, FILL_RECTANGLE = 12, FILL_ROUNDED_RECTANGLE = 13, FILL_ELLIPSE = 14,
            FILL_PATH = 16, TEXT = 17, TRANSLATE = 18, ROTATE = 19, SCALE = 20, SAVE_STATE = 21,
            RESTORE_STATE = 22;

    /** A path command's kinds, as the Swift host numbers them, each followed by its points. */
    /** A finger's touch on the canvas, as the Swift host numbers it. */
    // Swift: AndroidCanvasTouch
    private static final int PRESSED = 0, DRAGGED = 1, RELEASED = 2;

    // Swift: HostCurveCommand.Kind
    private static final int MOVE = 0, LINE = 1, CUBIC = 2, QUADRATIC = 3, CLOSE = 4;

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
        // The words' size until a drawing sets one: the drawing's first record, the host's own body text.
        float strokeWidth = 1, fontSize = 0, alpha = 1;

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
        // A record running past the end of its lists stops the drawing there: what stands before it is drawn.
        try {
            draw(canvas, state, saved, at, number);
        } catch (ArrayIndexOutOfBoundsException runsPast) {
            // Nothing past the cut is read.
        }
        while (!saved.isEmpty()) {
            saved.pop();
            canvas.restore();
        }
        canvas.restore();
    }

    /** Draws the records from `at` and `number` on: ints and numbers as the host laid them out. */
    private void draw(Canvas canvas, State state, ArrayDeque<State> saved, int at, int number) {
        while (at < ints.length) {
            int kind = ints[at++];
            switch (kind) {
                case FILL_COLOR: state.fill = ints[at++]; break;
                case STROKE_COLOR: state.stroke = ints[at++]; break;
                case TEXT_COLOR: state.text = ints[at++]; break;
                case LINE_WIDTH: state.strokeWidth = Math.max(0, numbers[number++]); break;
                case FONT_SIZE: state.fontSize = Math.max(0, numbers[number++]); break;
                case OPACITY: state.alpha = Math.min(Math.max(numbers[number++], 0), 1); break;
                case STROKE_LINE:
                    if (stroking(state)) {
                        canvas.drawLine(numbers[number], numbers[number + 1], numbers[number + 2], numbers[number + 3], paint);
                    }
                    number += 4;
                    break;
                case STROKE_RECTANGLE: case FILL_RECTANGLE:
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    number += 4;
                    if (kind == FILL_RECTANGLE ? filling(state) : stroking(state)) canvas.drawRect(box, paint);
                    break;
                case STROKE_ROUNDED_RECTANGLE: case FILL_ROUNDED_RECTANGLE: {
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    float radius = Math.max(0, numbers[number + 4]);
                    number += 5;
                    if (kind == FILL_ROUNDED_RECTANGLE ? filling(state) : stroking(state)) {
                        canvas.drawRoundRect(box, radius, radius, paint);
                    }
                    break;
                }
                case STROKE_ELLIPSE: case FILL_ELLIPSE:
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    number += 4;
                    if (kind == FILL_ELLIPSE ? filling(state) : stroking(state)) canvas.drawOval(box, paint);
                    break;
                case STROKE_PATH: case FILL_PATH: {
                    int count = ints[at++];
                    number = path(number, count);
                    if (kind == FILL_PATH ? filling(state) : stroking(state)) canvas.drawPath(path, paint);
                    break;
                }
                case TEXT: {
                    box.set(numbers[number], numbers[number + 1],
                            numbers[number] + numbers[number + 2], numbers[number + 1] + numbers[number + 3]);
                    number += 4;
                    int edge = ints[at++];
                    int vertical = ints[at++];
                    text(canvas, strings[ints[at++]], edge, vertical, state);
                    break;
                }
                case TRANSLATE: canvas.translate(numbers[number], numbers[number + 1]); number += 2; break;
                case ROTATE: canvas.rotate(numbers[number++]); break;
                case SCALE: canvas.scale(numbers[number], numbers[number + 1]); number += 2; break;
                case SAVE_STATE:
                    saved.push(state.copy());
                    canvas.save();
                    break;
                case RESTORE_STATE:
                    if (!saved.isEmpty()) {
                        state = saved.pop();
                        canvas.restore();
                    }
                    break;
                default: return;
            }
        }
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
                case CLOSE: default: path.close(); number += 1;
            }
        }
        return number;
    }

    /**
     * `text` wrapped in `box` - at its left, middle or right `edge`, whichever way the words read, and down it as
     * the instruction says - cut at its edges.
     */
    private void text(Canvas canvas, String text, int edge, int vertical, State state) {
        words.setTextSize(state.fontSize);
        words.setColor(state.text);
        words.setAlpha(Math.round(((state.text >>> 24) & 0xFF) * state.alpha));
        Layout.Alignment across = edge == 1 ? Layout.Alignment.ALIGN_CENTER
                : edge == 2 ? Layout.Alignment.ALIGN_OPPOSITE : Layout.Alignment.ALIGN_NORMAL;
        StaticLayout lines = StaticLayout.Builder
                .obtain(text, 0, text.length(), words, Math.max(1, (int) Math.ceil(box.width())))
                .setAlignment(across)
                .setTextDirection(TextDirectionHeuristics.LTR)
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
            case MotionEvent.ACTION_DOWN: StateUIHost.canvasTouched(view, PRESSED, x, y); return true;
            case MotionEvent.ACTION_MOVE: StateUIHost.canvasTouched(view, DRAGGED, x, y); return true;
            case MotionEvent.ACTION_UP: case MotionEvent.ACTION_CANCEL:
                StateUIHost.canvasTouched(view, RELEASED, x, y);
                return true;
            default: return super.onTouchEvent(event);
        }
    }
}
