// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.widget.Adapter;
import android.widget.Spinner;

/** A picker's rows and its choice, read and made as a test asks: its title first, then its options. */
public final class TestPicker {
    private TestPicker() {}

    /** The spinner's rows' words, the title's first. */
    public static String[] rows(Spinner picker) {
        Adapter adapter = picker.getAdapter();
        String[] rows = new String[adapter.getCount()];
        for (int row = 0; row < rows.length; row++) rows[row] = String.valueOf(adapter.getItem(row));
        return rows;
    }

    /** Chooses the row `row` as the user's tap on it in the open list does. */
    public static void choose(Spinner picker, int row) {
        picker.setSelection(row);
    }
}
