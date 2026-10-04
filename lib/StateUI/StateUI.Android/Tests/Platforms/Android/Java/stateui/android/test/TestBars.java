// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.widget.Toolbar;

/** What a test reads of a bar as Android holds it. */
public final class TestBars {
    private TestBars() {}

    /** The line under the bar's title; null for none. */
    public static String subtitle(Toolbar bar) {
        CharSequence words = bar.getSubtitle();
        return words == null ? null : words.toString();
    }

    /** What the bar's navigation button says to TalkBack; null where the bar shows no navigation button. */
    public static String navigation(Toolbar bar) {
        if (bar.getNavigationIcon() == null) return null;
        CharSequence words = bar.getNavigationContentDescription();
        return words == null ? "" : words.toString();
    }

    /** Whether the bar is on screen: shown, and in a window. */
    public static boolean shown(Toolbar bar) {
        return bar.isShown();
    }

    /** The colour the bar is painted, as ARGB; 0 where it wears no colour of its own. */
    public static int background(Toolbar bar) {
        Drawable drawn = bar.getBackground();
        return drawn instanceof ColorDrawable ? ((ColorDrawable) drawn).getColor() : 0;
    }
}
