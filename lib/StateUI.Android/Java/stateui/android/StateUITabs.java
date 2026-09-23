// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * A tabbed view's tabs along the bottom: one button each, its picture over its
 * title, the chosen one in its own colour. A tap goes to the Swift view by its
 * number.
 */
final class StateUITabs extends LinearLayout implements View.OnClickListener {
    private final long view;

    StateUITabs(Context context, long view) {
        super(context);
        this.view = view;
        setOrientation(HORIZONTAL);
    }

    /**
     * The tabs, in order, the one chosen, the bar's colour (0 for Android's own) and the colours of a tab
     * and of the chosen one (0 for the text's own).
     */
    void setTabs(String[] titles, Bitmap[] pictures, int chosen, int background, int color, int chosenColor) {
        removeAllViews();
        if (background != 0) setBackgroundColor(background); else setBackground(null);
        float density = getResources().getDisplayMetrics().density;
        for (int index = 0; index < titles.length; index++) {
            TextView tab = new TextView(getContext());
            tab.setText(titles[index]);
            tab.setGravity(Gravity.CENTER);
            tab.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
            tab.setPadding(0, (int) (8 * density), 0, (int) (8 * density));
            int tint = index == chosen ? chosenColor : color;
            if (tint != 0) tab.setTextColor(tint);
            if (pictures[index] != null) {
                BitmapDrawable picture = new BitmapDrawable(getResources(), pictures[index]);
                tab.setCompoundDrawablesWithIntrinsicBounds(null, picture, null, null);
                tab.setCompoundDrawablePadding((int) (2 * density));
                if (tint != 0) tab.setCompoundDrawableTintList(ColorStateList.valueOf(tint));
            }
            tab.setAlpha(index == chosen || tint != 0 ? 1f : 0.6f);
            tab.setTag(index);
            tab.setOnClickListener(this);
            addView(tab, new LayoutParams(0, LayoutParams.WRAP_CONTENT, 1));
        }
    }

    @Override
    public void onClick(View tab) {
        StateUIHost.tabSelected(view, (Integer) tab.getTag());
    }
}
