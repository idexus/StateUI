// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.os.Build;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;
import java.util.Arrays;

/** The order Android draws a group's children in, as its own drawing goes. */
public final class TestDrawing {
    private TestDrawing() {}

    /** The positions of `group`'s children in the order it draws them, back to front: by Z, then its drawing order. */
    public static int[] drawingOrder(ViewGroup group) {
        int count = group.getChildCount();
        Integer[] order = new Integer[count];
        for (int position = 0; position < count; position++) {
            order[position] = Build.VERSION.SDK_INT >= 29 ? group.getChildDrawingOrder(position) : position;
        }
        Arrays.sort(order, (one, other) -> Float.compare(group.getChildAt(one).getZ(), group.getChildAt(other).getZ()));
        int[] positions = new int[count];
        for (int index = 0; index < count; index++) positions[index] = order[index];
        return positions;
    }

    /** Whether `view` is `holder` or stands in it. */
    public static boolean isWithin(View view, View holder) {
        for (View current = view; current != null; ) {
            if (current == holder) return true;
            ViewParent parent = current.getParent();
            current = parent instanceof View ? (View) parent : null;
        }
        return false;
    }
}
