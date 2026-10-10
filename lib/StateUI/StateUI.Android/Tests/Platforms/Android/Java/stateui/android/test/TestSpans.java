// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.graphics.Paint;
import android.graphics.Typeface;
import android.text.Spanned;
import android.text.style.AbsoluteSizeSpan;
import android.text.style.BackgroundColorSpan;
import android.text.style.ForegroundColorSpan;
import android.text.style.StrikethroughSpan;
import android.text.style.StyleSpan;
import android.text.style.UnderlineSpan;
import android.util.TypedValue;
import android.widget.TextView;

/**
 * A run of a text view's words, read as a test asks it: its words, and the look the spans over its first letter give
 * it - the view's own where none does.
 */
public final class TestSpans {
    private TestSpans() {}

    /** The words from `start` to `end`. */
    public static String words(TextView view, int start, int end) {
        CharSequence text = view.getText();
        return text.subSequence(Math.min(start, text.length()), Math.min(end, text.length())).toString();
    }

    /** The size at `at`, in the scaled points the host sets it in. */
    public static float points(TextView view, int at) {
        AbsoluteSizeSpan size = span(view, at, AbsoluteSizeSpan.class);
        float one = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 1, view.getResources().getDisplayMetrics());
        return (size != null ? size.getSize() : view.getTextSize()) / one;
    }

    /**
     * Whether the size at `at` follows the user's font scale: 1 where it does, 0 where it stands in density-independent
     * points, -1 unread - the view's own where no span sizes the words there.
     */
    public static int scales(TextView view, int at) {
        AbsoluteSizeSpan size = span(view, at, AbsoluteSizeSpan.class);
        return size != null ? (size.getDip() ? 0 : 1) : TestText.scales(view);
    }

    /** The colour at `at`, as ARGB. */
    public static int color(TextView view, int at) {
        ForegroundColorSpan color = span(view, at, ForegroundColorSpan.class);
        return color != null ? color.getForegroundColor() : view.getCurrentTextColor();
    }

    /** Bold and italic at `at`, in the bits `Typeface` numbers them by. */
    public static int style(TextView view, int at) {
        StyleSpan style = span(view, at, StyleSpan.class);
        if (style != null) return style.getStyle();
        Typeface face = view.getTypeface();
        return face == null ? Typeface.NORMAL : face.getStyle();
    }

    /** The lines at `at`: 1 under the words, 2 through them. */
    public static int lines(TextView view, int at) {
        int flags = view.getPaintFlags();
        int lines = (flags & Paint.UNDERLINE_TEXT_FLAG) != 0 ? 1 : 0;
        if ((flags & Paint.STRIKE_THRU_TEXT_FLAG) != 0) lines |= 2;
        if (span(view, at, UnderlineSpan.class) != null) lines |= 1;
        if (span(view, at, StrikethroughSpan.class) != null) lines |= 2;
        return lines;
    }

    /** The colour behind the words at `at`, as ARGB; 0 for none. */
    public static int background(TextView view, int at) {
        BackgroundColorSpan background = span(view, at, BackgroundColorSpan.class);
        return background != null ? background.getBackgroundColor() : 0;
    }

    /** The last span of `kind` over the letter at `at`; null where none is. */
    private static <T> T span(TextView view, int at, Class<T> kind) {
        if (!(view.getText() instanceof Spanned)) return null;
        T[] spans = ((Spanned) view.getText()).getSpans(at, at + 1, kind);
        return spans.length == 0 ? null : spans[spans.length - 1];
    }
}
