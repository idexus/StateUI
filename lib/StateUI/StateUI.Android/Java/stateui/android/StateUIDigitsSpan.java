// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.text.TextPaint;
import android.text.style.MetricAffectingSpan;

/** A run whose digits are all as wide as one another: the font's tabular figures, beside the features it has. */
public final class StateUIDigitsSpan extends MetricAffectingSpan {
    /** The font feature drawing every digit as wide as the others. */
    static final String FEATURE = "tnum";

    @Override
    public void updateDrawState(TextPaint paint) {
        monospace(paint);
    }

    @Override
    public void updateMeasureState(TextPaint paint) {
        monospace(paint);
    }

    private static void monospace(TextPaint paint) {
        String features = paint.getFontFeatureSettings();
        if (features == null || features.isEmpty()) paint.setFontFeatureSettings(FEATURE);
        else if (!features.contains(FEATURE)) paint.setFontFeatureSettings(features + ", " + FEATURE);
    }
}
