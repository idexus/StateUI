// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Path;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.ShapeDrawable;
import android.graphics.drawable.shapes.PathShape;
import android.view.Gravity;
import android.view.Menu;
import android.view.View;
import android.view.ViewGroup;
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

    /** The page's title, shown while no view stands in for it. */
    private String title = "";
    private View titleView;

    StateUIBar(Context context, long view) {
        super(context);
        this.view = view;
    }

    /** The title and the bar's colours; a colour of 0 leaves Android's own. */
    void show(String title, int background, int foreground) {
        this.title = title;
        setTitle(titleView == null ? title : null);
        if (background != 0) setBackgroundColor(background); else setBackground(null);
        if (foreground != 0) {
            setTitleTextColor(foreground);
            Drawable overflow = getOverflowIcon();
            if (overflow != null) overflow.mutate().setTint(foreground);
        }
    }

    /**
     * The view standing in for the title, across the room between the navigation button and the actions - or
     * none, and the title shows again. The view leaves whatever held it before.
     */
    void setTitleView(View standing) {
        if (standing == titleView) return;
        if (titleView != null && titleView.getParent() == this) removeView(titleView);
        titleView = standing;
        if (standing != null) {
            if (standing.getParent() instanceof ViewGroup) ((ViewGroup) standing.getParent()).removeView(standing);
            addView(standing, new Toolbar.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER_VERTICAL));
        }
        setTitle(standing == null ? title : null);
    }

    /**
     * The navigation button: none, the way back in `tint`, or the sidebar's own picture - Android's menu glyph in
     * `tint` where it has none.
     */
    void setNavigation(int kind, Bitmap picture, int tint, String description) {
        Drawable icon = null;
        if (kind == BACK) {
            TypedArray attributes = getContext().obtainStyledAttributes(new int[] { android.R.attr.homeAsUpIndicator });
            icon = attributes.getDrawable(0);
            attributes.recycle();
            if (icon != null && tint != 0) icon.mutate().setTint(tint);
        } else if (kind == SIDEBAR) {
            icon = picture != null ? StateUIViews.glyph(getResources(), picture) : menuGlyph(tint);
        }
        setNavigationIcon(icon);
        setNavigationContentDescription(icon == null ? null : description);
        setNavigationOnClickListener(icon == null ? null : this);
    }

    /** Android's menu glyph - three lines on its 24 dp icon grid - in `tint`, or at 0 the theme's for controls. */
    private Drawable menuGlyph(int tint) {
        Path lines = new Path();
        for (int top : new int[] {6, 11, 16}) lines.addRect(3, top, 21, top + 2, Path.Direction.CW);
        ShapeDrawable glyph = new ShapeDrawable(new PathShape(lines, 24, 24));
        int size = Math.round(24 * getResources().getDisplayMetrics().density);
        glyph.setIntrinsicWidth(size);
        glyph.setIntrinsicHeight(size);
        if (tint != 0) {
            glyph.setTint(tint);
        } else {
            TypedArray theme = getContext().obtainStyledAttributes(new int[] { android.R.attr.colorControlNormal });
            glyph.setTintList(theme.getColorStateList(0));
            theme.recycle();
        }
        return glyph;
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
