// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.content.Context;
import android.graphics.drawable.Drawable;
import android.view.Menu;
import android.view.ViewGroup;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.List;

/** The pictures a bar and a row of tabs stand at, read back as "width x height" pixels. */
public final class TestPictures {
    private TestPictures() {}

    /** Each tab's picture - the one above its words - in order, separated by ", ". */
    public static String tabs(ViewGroup row) {
        List<String> sizes = new ArrayList<>();
        for (int index = 0; index < row.getChildCount(); index++) {
            Drawable picture = ((TextView) row.getChildAt(index)).getCompoundDrawablesRelative()[1];
            sizes.add(size(picture));
        }
        return String.join(", ", sizes);
    }

    /** Each menu item's picture, in order, separated by ", ". */
    public static String menu(Menu menu) {
        List<String> sizes = new ArrayList<>();
        for (int index = 0; index < menu.size(); index++) sizes.add(size(menu.getItem(index).getIcon()));
        return String.join(", ", sizes);
    }

    /** `points` density-independent pixels, in this device's pixels. */
    public static int pixels(Context context, float points) {
        return Math.round(points * context.getResources().getDisplayMetrics().density);
    }

    private static String size(Drawable picture) {
        return picture == null ? "none" : picture.getIntrinsicWidth() + "x" + picture.getIntrinsicHeight();
    }
}
