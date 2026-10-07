// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.content.res.ColorStateList;
import android.text.TextUtils;
import android.view.View;
import android.widget.CompoundButton;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.Spinner;
import android.widget.TextView;

/** What a view holds of a property, read back as the driver names it: in words, in the units Android keeps. */
public final class TestRead {
    private TestRead() {}

    /** What `view` holds of `what`; null where it holds nothing of it. */
    public static String read(View view, String what) {
        if (view instanceof TextView) {
            String held = text((TextView) view, what);
            if (held != null) return held;
        }
        switch (what) {
            case "padding":
                return view.getPaddingLeft() + "," + view.getPaddingTop() + ","
                        + view.getPaddingRight() + "," + view.getPaddingBottom();
            case "clipToOutline": return view.getClipToOutline() ? "1" : "0";
            case "verticalBar":
                return bar(view.isVerticalScrollBarEnabled(), view.isScrollbarFadingEnabled());
            case "horizontalBar":
                return bar(view.isHorizontalScrollBarEnabled(), view.isScrollbarFadingEnabled());
            case "scaleType": return view instanceof ImageView ? ((ImageView) view).getScaleType().name() : null;
            case "tint": return tint(view);
            default: return null;
        }
    }

    /** A text view's lines, breaking, gravity, spacing, decorations, hint, selection and kind of input. */
    private static String text(TextView view, String what) {
        switch (what) {
            case "maxLines": return String.valueOf(view.getMaxLines());
            case "ellipsize":
                TextUtils.TruncateAt at = view.getEllipsize();
                return at == null ? "" : at.name();
            case "scrollsAcross": return view.isHorizontallyScrollable() ? "1" : "0";
            case "gravity": return String.valueOf(view.getGravity());
            case "letterSpacing": return String.valueOf(view.getLetterSpacing() * view.getTextSize());
            case "lineHeight": return String.valueOf(view.getLineSpacingMultiplier());
            case "paintFlags": return String.valueOf(view.getPaintFlags());
            case "hint":
                CharSequence hint = view.getHint();
                return hint == null ? "" : hint.toString();
            case "hintColor": return String.valueOf(view.getCurrentHintTextColor());
            case "selectionStart": return String.valueOf(view.getSelectionStart());
            case "selectionEnd": return String.valueOf(view.getSelectionEnd());
            case "inputType": return String.valueOf(view.getInputType());
            default: return null;
        }
    }

    /** A scroll bar's showing: none, always, or while the user scrolls. */
    private static String bar(boolean enabled, boolean fades) {
        return !enabled ? "never" : fades ? "default" : "always";
    }

    /** The colour a control's own part is tinted: a check's box, a bar's progress, a spinner's ring, a picker's arrow. */
    private static String tint(View view) {
        ColorStateList tint = null;
        if (view instanceof CompoundButton) tint = ((CompoundButton) view).getButtonTintList();
        else if (view instanceof ProgressBar) {
            ProgressBar bar = (ProgressBar) view;
            tint = bar.isIndeterminate() ? bar.getIndeterminateTintList() : bar.getProgressTintList();
        } else if (view instanceof Spinner) tint = view.getBackgroundTintList();
        return tint == null ? null : String.valueOf(tint.getDefaultColor());
    }
}
