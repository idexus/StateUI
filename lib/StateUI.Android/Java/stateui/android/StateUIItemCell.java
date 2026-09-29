// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Build;
import android.view.accessibility.AccessibilityNodeInfo;

/**
 * A cell of an ItemsView: a StateUI layout holding one entry. An item's cell shows a touch as the platform's rows do,
 * and the user's choice on a band of the accent colour; assistive technology hears it chosen - checked where many
 * may be.
 */
final class StateUIItemCell extends StateUIViewGroup {
    /** Whether many items may be chosen: a chosen item is then checked rather than selected. */
    private boolean many;

    StateUIItemCell(Context context, long view, boolean item) {
        super(context, view);
        if (!item) return;

        TypedArray theme = context.obtainStyledAttributes(
                new int[] {android.R.attr.selectableItemBackground, android.R.attr.colorAccent});
        setForeground(theme.getDrawable(0));
        int accent = theme.getColor(1, 0xFF6200EE);
        theme.recycle();

        StateListDrawable band = new StateListDrawable();
        band.addState(new int[] {android.R.attr.state_activated}, new ColorDrawable(accent & 0x00FFFFFF | 0x33000000));
        setBackground(band);
    }

    /** Shows the item chosen or not, `many` saying whether many may be. */
    void setChosen(boolean chosen, boolean many) {
        this.many = many;
        setActivated(chosen);
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onInitializeAccessibilityNodeInfo(AccessibilityNodeInfo info) {
        super.onInitializeAccessibilityNodeInfo(info);
        if (!many) {
            info.setSelected(isActivated());
            return;
        }
        info.setCheckable(true);
        if (Build.VERSION.SDK_INT >= 36) {
            info.setChecked(isActivated()
                    ? AccessibilityNodeInfo.CHECKED_STATE_TRUE : AccessibilityNodeInfo.CHECKED_STATE_FALSE);
        } else {
            info.setChecked(isActivated());
        }
    }
}
