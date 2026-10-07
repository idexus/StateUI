// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

/** A tabbed view's row of tabs as a test reads it and taps it: each tab by its place. */
public final class TestTabs {
    private TestTabs() {}

    /** The words the tab at `place` shows; null where there is no such tab. */
    public static String title(ViewGroup row, int place) {
        View tab = row.getChildAt(place);
        return tab instanceof TextView ? ((TextView) tab).getText().toString() : null;
    }

    /** Whether the tab at `place` shows `picture` over its words: the very pixels of it. */
    public static boolean shows(ViewGroup row, int place, Bitmap picture) {
        View tab = row.getChildAt(place);
        if (!(tab instanceof TextView)) return false;
        Drawable over = ((TextView) tab).getCompoundDrawables()[1];
        return over instanceof BitmapDrawable && ((BitmapDrawable) over).getBitmap().sameAs(picture);
    }

    /** The place of the tab marked selected; -1 for none. */
    public static int selected(ViewGroup row) {
        for (int place = 0; place < row.getChildCount(); place++) {
            if (row.getChildAt(place).isSelected()) return place;
        }
        return -1;
    }

    /** Taps the tab at `place`, as the user does; false where there is no such tab. */
    public static boolean tap(ViewGroup row, int place) {
        View tab = row.getChildAt(place);
        return tab != null && tab.performClick();
    }
}
