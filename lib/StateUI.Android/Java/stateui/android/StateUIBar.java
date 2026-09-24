// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.view.Menu;
import android.view.View;
import android.widget.Toolbar;

/**
 * A navigation stack's bar: Android's own toolbar, told by the Swift host what
 * it says, the way back or to the sidebar, and the visible page's actions.
 */
final class StateUIBar extends Toolbar implements View.OnClickListener {
    /** What the navigation button does, as the Swift host numbers it. */
    static final int NONE = 0;
    static final int BACK = 1;
    static final int SIDEBAR = 2;

    private final long view;

    StateUIBar(Context context, long view) {
        super(context);
        this.view = view;
    }

    /** The title and the bar's colours; a colour of 0 leaves Android's own. */
    void show(String title, int background, int foreground) {
        setTitle(title);
        if (background != 0) setBackgroundColor(background); else setBackground(null);
        if (foreground != 0) {
            setTitleTextColor(foreground);
            Drawable overflow = getOverflowIcon();
            if (overflow != null) overflow.mutate().setTint(foreground);
        }
    }

    /** The navigation button: none, the way back in `tint`, or the sidebar's own picture. */
    void setNavigation(int kind, Bitmap picture, int tint, String description) {
        Drawable icon = null;
        if (kind == BACK) {
            TypedArray attributes = getContext().obtainStyledAttributes(new int[] { android.R.attr.homeAsUpIndicator });
            icon = attributes.getDrawable(0);
            attributes.recycle();
            if (icon != null && tint != 0) icon.mutate().setTint(tint);
        } else if (kind == SIDEBAR && picture != null) {
            icon = new BitmapDrawable(getResources(), picture);
        }
        setNavigationIcon(icon);
        setNavigationContentDescription(icon == null ? null : description);
        setNavigationOnClickListener(icon == null ? null : this);
    }

    /** The visible page's actions, in the order they show, as `StateUIMenus` writes a menu's entries. */
    void setActions(int[] entries, String[] texts, Bitmap[] pictures) {
        Menu menu = getMenu();
        menu.clear();
        StateUIMenus.fill(getContext(), menu, view, entries, texts, pictures);
    }

    @Override
    public void onClick(View clicked) {
        StateUIHost.clicked(view);
    }
}
