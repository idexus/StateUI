// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.graphics.Typeface;
import android.view.View;
import android.widget.RadioButton;
import android.widget.RadioGroup;

/**
 * A Picker offered as radio buttons: Android's RadioGroup, a column of them - or, offered as segments, which
 * Android has no control for, the same group in a row. A check is told as a choice; the program's own, which Swift
 * writes, Swift drops.
 */
final class StateUIChoices extends RadioGroup implements StateUIChoosing, RadioGroup.OnCheckedChangeListener {
    private final long view;

    /** Each option's button's id, in order. */
    private int[] ids = new int[0];

    StateUIChoices(Context context, long view, boolean row) {
        super(context);
        this.view = view;
        setOrientation(row ? HORIZONTAL : VERTICAL);
        setOnCheckedChangeListener(this);
    }

    @Override
    public void setChoices(String[] options, String title, int chosen, boolean writesChoice) {
        if (options != null) {
            removeAllViews();
            ids = new int[options.length];
            for (int index = 0; index < options.length; index++) {
                RadioButton button = new RadioButton(getContext());
                ids[index] = View.generateViewId();
                button.setId(ids[index]);
                // StateUI holds the choice: Android restores none of its own.
                button.setSaveEnabled(false);
                button.setText(options[index]);
                button.setEnabled(isEnabled());
                addView(button);
            }
        }
        if (!writesChoice) return;
        if (chosen >= 0 && chosen < ids.length) check(ids[chosen]);
        else clearCheck();
    }

    @Override
    public void setLook(float size, int unit, int color, Typeface face, String features, int alignment) {
        for (int index = 0; index < getChildCount(); index++) {
            RadioButton button = (RadioButton) getChildAt(index);
            if (size > 0) button.setTextSize(unit, size);
            if (color != 0) button.setTextColor(color);
            button.setTypeface(face);
            button.setFontFeatureSettings(features);
        }
        setGravity(alignment);
    }

    /** A group turned off turns its buttons off: a RadioGroup's own state reaches none of them. */
    @Override
    public void setEnabled(boolean enabled) {
        super.setEnabled(enabled);
        for (int index = 0; index < getChildCount(); index++) getChildAt(index).setEnabled(enabled);
    }

    /** The place of the option checked; -1 for none. */
    int checked() {
        int id = getCheckedRadioButtonId();
        for (int index = 0; index < ids.length; index++) if (ids[index] == id) return index;
        return -1;
    }

    @Override
    public void onCheckedChanged(RadioGroup group, int checkedId) {
        int place = checked();
        if (place >= 0) StateUIHost.chose(view, place);
    }
}
