// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.Spinner;
import android.widget.TextView;

/**
 * A Picker: Android's dropdown spinner. Its first row is the title, which the closed field shows while
 * nothing is chosen and the open list leaves out, so a choice is the row after its index.
 */
final class StateUIPicker extends Spinner implements AdapterView.OnItemSelectedListener {
    private final long view;
    private final Rows rows = new Rows();

    private String[] options = new String[0];
    private String title = "";

    /**
     * The row the program's choice stands on. Android reports a selection as it measures or lays the spinner
     * out - the row it starts on first, then the program's - so a report of this row is an echo.
     */
    private int chosenRow;

    private boolean open;

    private float textSize;
    private int textUnit = TypedValue.COMPLEX_UNIT_SP;
    private int textColor;
    private Typeface typeface;
    private int gravity = Gravity.START | Gravity.CENTER_VERTICAL;

    StateUIPicker(Context context, long view) {
        super(context, Spinner.MODE_DROPDOWN);
        this.view = view;
        setAdapter(rows);
        setOnItemSelectedListener(this);
    }

    /**
     * The options - null where they stay - the title shown while nothing is chosen, and, where `writesChoice`,
     * the chosen index, -1 for none.
     */
    void setChoices(String[] options, String title, int chosen, boolean writesChoice) {
        if (options != null) this.options = options;
        this.title = title;
        rows.notifyDataSetChanged();
        if (!writesChoice) return;

        chosenRow = chosen + 1;
        if (getSelectedItemPosition() != chosenRow) setSelection(chosenRow);
    }

    /**
     * The words' size in points - 0 for the theme's - and their unit, `TypedValue`'s scaled pixels where the user's
     * font scale applies to them and its density-independent ones where not; their colour - 0 for the theme's -
     * their face, and where they stand.
     */
    void setLook(float size, int unit, int color, Typeface face, int alignment) {
        textSize = size;
        textUnit = unit;
        textColor = color;
        typeface = face;
        gravity = alignment | Gravity.CENTER_VERTICAL;
        rows.notifyDataSetChanged();
    }

    /** Opens the list for the program; Swift tells whose the opening was. */
    void openList() {
        performClick();
    }

    @Override
    public boolean performClick() {
        boolean handled = super.performClick();
        if (!open) {
            open = true;
            StateUIHost.opened(view);
        }
        return handled;
    }

    /** The list takes the window's focus while it shows; the focus coming back is the list closing. */
    @Override
    public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        if (focused && open) {
            open = false;
            StateUIHost.closed(view);
        }
    }

    @Override
    public void onItemSelected(AdapterView<?> parent, View row, int position, long id) {
        if (position == chosenRow || position == 0) return;
        chosenRow = position;
        StateUIHost.chose(view, position - 1);
    }

    @Override
    public void onNothingSelected(AdapterView<?> parent) {}

    /** The title, then the options, all of one kind of row as a spinner asks. */
    private final class Rows extends BaseAdapter {
        /** A row's words' colours and an open list's row height, as the theme made them. */
        private ColorStateList madeColors;

        /** The theme's size of a row of each layout, in scaled points, read from the first one made. */
        private final java.util.HashMap<Integer, Float> madeSizes = new java.util.HashMap<>();
        private int madeHeight = ViewGroup.LayoutParams.WRAP_CONTENT;

        @Override
        public int getCount() {
            return options.length + 1;
        }

        @Override
        public Object getItem(int position) {
            return position == 0 ? title : options[position - 1];
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public View getView(int position, View reuse, ViewGroup parent) {
            TextView field = words(reuse, parent, android.R.layout.simple_spinner_item, position);
            if (position == 0) field.setTextColor(field.getHintTextColors());
            return field;
        }

        /**
         * The title's row is there, and none tall: the open list leaves it out. A list measures a row asking
         * for no height by its words, so the words are held to none.
         */
        @Override
        public View getDropDownView(int position, View reuse, ViewGroup parent) {
            TextView row = words(reuse, parent, android.R.layout.simple_spinner_dropdown_item, position);
            boolean title = position == 0;
            row.setLayoutParams(new AbsListView.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, title ? ViewGroup.LayoutParams.WRAP_CONTENT : madeHeight));
            row.setMinHeight(0);
            row.setMaxHeight(title ? 0 : Integer.MAX_VALUE);
            return row;
        }

        private TextView words(View reuse, ViewGroup parent, int layout, int position) {
            TextView row;
            if (reuse instanceof TextView) {
                row = (TextView) reuse;
            } else {
                row = (TextView) LayoutInflater.from(parent.getContext()).inflate(layout, parent, false);
                if (madeColors == null) madeColors = row.getTextColors();
                if (!madeSizes.containsKey(layout)) {
                    float one = TypedValue.applyDimension(
                            TypedValue.COMPLEX_UNIT_SP, 1, row.getResources().getDisplayMetrics());
                    madeSizes.put(layout, row.getTextSize() / one);
                }
                if (layout == android.R.layout.simple_spinner_dropdown_item && row.getLayoutParams() != null) {
                    madeHeight = row.getLayoutParams().height;
                }
            }
            row.setText((String) getItem(position));
            row.setTextSize(textUnit, textSize > 0 ? textSize : madeSizes.get(layout));
            row.setTextColor(textColor != 0 ? ColorStateList.valueOf(textColor) : madeColors);
            row.setTypeface(typeface);
            row.setGravity(gravity);
            return row;
        }
    }
}
