// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.graphics.Typeface;
import android.util.TypedValue;
import android.widget.TextView;

/** How a text view draws its words, read back as a test asks it: in the units the host writes them in. */
public final class TestText {
    private TestText() {}

    /** The words' size in points the user's font scale applies to - scaled pixels - as the host sets it. */
    public static float points(TextView view) {
        float one = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP, 1, view.getResources().getDisplayMetrics());
        return view.getTextSize() / one;
    }

    /** Bold and italic, in the bits `Typeface` numbers them by. */
    public static int style(TextView view) {
        Typeface face = view.getTypeface();
        return face == null ? Typeface.NORMAL : face.getStyle();
    }
}
