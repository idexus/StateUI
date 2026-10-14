// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.widget.Adapter;
import android.widget.RadioButton;
import android.widget.RadioGroup;
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

    /** A radio group's buttons' words, in order. */
    public static String[] radios(RadioGroup group) {
        String[] words = new String[group.getChildCount()];
        for (int index = 0; index < words.length; index++) words[index] = ((RadioButton) group.getChildAt(index)).getText().toString();
        return words;
    }

    /** The place of the radio button checked; -1 for none. */
    public static int checked(RadioGroup group) {
        for (int index = 0; index < group.getChildCount(); index++) {
            if (((RadioButton) group.getChildAt(index)).isChecked()) return index;
        }
        return -1;
    }

    /** Checks the radio button at `index` as the user's tap does. */
    public static void chooseRadio(RadioGroup group, int index) {
        group.getChildAt(index).performClick();
    }
}
