// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toolbar;

/** What a test reads of a bar as Android holds it. */
public final class TestBars {
    private TestBars() {}

    /** How many views `view` holds - itself not counted - stand shifted across, as a slide moves them. */
    public static int shifted(View view) {
        if (!(view instanceof ViewGroup)) return 0;
        ViewGroup group = (ViewGroup) view;
        int shifted = 0;
        for (int index = 0; index < group.getChildCount(); index++) {
            View child = group.getChildAt(index);
            if (child.getTranslationX() != 0) shifted++;
            shifted += shifted(child);
        }
        return shifted;
    }

    /**
     * The vertical middle, in pixels from the bar's top, of each button and line of words the bar shows - its own and
     * those its rows and its actions hold - commas between them.
     */
    public static String middles(Toolbar bar) {
        StringBuilder middles = new StringBuilder();
        collect(bar, 0, middles);
        return middles.toString();
    }

    private static void collect(View view, int top, StringBuilder middles) {
        if (view.getVisibility() != View.VISIBLE || view.getWidth() == 0) return;
        boolean words = view instanceof TextView && ((TextView) view).getText().length() > 0;
        boolean picture = view instanceof ImageView && ((ImageView) view).getDrawable() != null;
        boolean action = view instanceof TextView && !words && ((TextView) view).getCompoundDrawables()[0] != null;
        if (words || picture || action) {
            if (middles.length() > 0) middles.append(',');
            middles.append(top + view.getTop() + view.getHeight() / 2);
            return;
        }
        if (!(view instanceof ViewGroup)) return;
        ViewGroup group = (ViewGroup) view;
        int inner = view instanceof Toolbar ? 0 : top + view.getTop();
        for (int index = 0; index < group.getChildCount(); index++) collect(group.getChildAt(index), inner, middles);
    }

    /** Whether the bar shows a title, however few its words: it holds one in its title's place. */
    public static boolean titled(Toolbar bar) {
        return bar.getTitle() != null;
    }

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

    /** Presses the bar's navigation button as a touch does; false where it shows none. */
    public static boolean pressNavigation(Toolbar bar) {
        CharSequence words = bar.getNavigationContentDescription();
        for (int at = 0; words != null && at < bar.getChildCount(); at++) {
            View child = bar.getChildAt(at);
            boolean said = words.equals(child.getContentDescription());
            if (child instanceof ImageButton && said) return child.performClick();
        }
        return false;
    }

    /** Whether the bar shows a button of its own at its end - a sidebar's own bar, its toggle. */
    public static boolean endButton(Toolbar bar) {
        for (int at = 0; at < bar.getChildCount(); at++) {
            View child = bar.getChildAt(at);
            ViewGroup.LayoutParams params = child.getLayoutParams();
            if (child instanceof ImageButton && child.getVisibility() == View.VISIBLE
                    && params instanceof Toolbar.LayoutParams
                    && (((Toolbar.LayoutParams) params).gravity & Gravity.END) == Gravity.END) return true;
        }
        return false;
    }

    /** Whether the bar is on screen: shown, and in a window. */
    public static boolean shown(Toolbar bar) {
        return bar.isShown();
    }

    /** The color the bar's title is drawn in, as ARGB: its title's own words among its children; 0 for no title. */
    public static int foreground(Toolbar bar) {
        CharSequence title = bar.getTitle();
        for (int index = 0; title != null && index < bar.getChildCount(); index++) {
            View child = bar.getChildAt(index);
            if (child instanceof TextView && TextUtils.equals(((TextView) child).getText(), title)) {
                return ((TextView) child).getCurrentTextColor();
            }
        }
        return 0;
    }

    /** The color the bar is painted, as ARGB; 0 where it wears no color of its own. */
    public static int background(Toolbar bar) {
        Drawable drawn = bar.getBackground();
        return drawn instanceof ColorDrawable ? ((ColorDrawable) drawn).getColor() : 0;
    }
}
