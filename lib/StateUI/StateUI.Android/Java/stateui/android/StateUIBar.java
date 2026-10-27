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
import android.view.ContextThemeWrapper;
import android.view.Gravity;
import android.view.Menu;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toolbar;

/**
 * A navigation stack's bar: Android's own toolbar, told by the Swift host what
 * it says, the way back or to the sidebar, and the visible page's actions.
 */
final class StateUIBar extends Toolbar implements View.OnClickListener {
    /** What the navigation button does, as the Swift host numbers it. */
    // Swift: AndroidBarNavigation
    static final int NONE = 0, BACK = 1, SIDEBAR = 2, CLOSE = 3;

    private final long view;

    /** The page's title, shown while no view stands in for it; null for none. */
    private String title;

    /** The line under the title, shown with it; null for none. */
    private String subtitle;

    /** The color the bar's words and its actions' pictures stand in; 0 for Android's own. */
    private int foreground;
    private View titleView;

    /** The theme the bar's actions take their words from: the activity's, light words, or dark words. */
    // Swift: AndroidBarView.Words
    static final int PLATFORM = 0, LIGHT = 1, DARK = 2;

    /** The bar's own buttons apart from its navigation button, by the place each tells the host. */
    // Swift: AndroidBarButton
    static final int AFTER_NAVIGATION = 0, AT_END = 1;

    /** The button after the navigation button - the way back where the sidebar's toggle takes that button. */
    private ImageButton afterNavigation;

    /**
     * The row after the navigation button while a button follows it: that button, then the title or the view
     * standing in for it - the toolbar lays its own title out before any view it holds.
     */
    private LinearLayout titleRow;

    /** The toolbar's own room before its title beside a navigation button, kept for when the row goes. */
    private final int insetWithNavigation;

    /** A bar whose actions take their words from `words`: Android's overlay for a dark bar or a light one. */
    StateUIBar(Context context, long view, int words) {
        super(words == PLATFORM ? context : new ContextThemeWrapper(context, words == LIGHT
                ? android.R.style.ThemeOverlay_Material_Dark_ActionBar
                : android.R.style.ThemeOverlay_Material_ActionBar));
        this.view = view;
        insetWithNavigation = getContentInsetStartWithNavigation();
    }

    /**
     * The bar stands at least its style's height - the theme's bar height - under what it reaches beneath, actions
     * or none, so a split view's two bars stand as one: the toolbar counts that least height with its padding, and
     * aligns its title within it.
     */
    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        super.onMeasure(widthSpec, heightSpec);
        int least = getMinimumHeight() + getPaddingTop() + getPaddingBottom();
        if (MeasureSpec.getMode(heightSpec) != MeasureSpec.EXACTLY && getMeasuredHeight() < least) {
            setMeasuredDimension(getMeasuredWidth(), least);
        }
    }

    /**
     * The title, the line under it - null for none - and the color of what stands on the bar; 0 leaves Android's
     * own. The host paints the bar's background as a view's.
     */
    void show(String title, String subtitle, int foreground) {
        this.title = title;
        this.subtitle = subtitle;
        this.foreground = foreground;
        if (foreground != 0) {
            setTitleTextColor(foreground);
            setSubtitleTextColor(foreground);
            Drawable overflow = getOverflowIcon();
            if (overflow != null) overflow.mutate().setTint(foreground);
        }
        standTitle();
    }

    /**
     * The view standing in for the title, across the room between the navigation button and the actions - or
     * none, and the title shows again. The view leaves whatever held it before.
     */
    void setTitleView(View standing) {
        if (standing == titleView) return;
        if (titleView != null && titleView.getParent() instanceof ViewGroup) {
            ((ViewGroup) titleView.getParent()).removeView(titleView);
        }
        titleView = standing;
        if (standing != null && standing.getParent() instanceof ViewGroup) {
            ((ViewGroup) standing.getParent()).removeView(standing);
        }
        standTitle();
    }

    /**
     * The button after the navigation button: none, or the way back - Android's up arrow or Material's cross - in
     * `tint`, named `description`; pressing it tells the host its place.
     */
    void setAfterNavigation(int kind, int tint, String description) {
        if (kind == NONE) {
            afterNavigation = null;
        } else {
            if (afterNavigation == null) afterNavigation = ownButton(AFTER_NAVIGATION);
            afterNavigation.setImageDrawable(kind == CLOSE ? closeGlyph(tint) : upArrow(tint));
            afterNavigation.setContentDescription(description);
        }
        standTitle();
    }

    /**
     * Stands the title where the bar's buttons leave room for it: the toolbar's own after its navigation button,
     * or, while a button follows that one, in the row after it - its words in the appearances the toolbar's style
     * names for its own, or the view standing in for them.
     */
    private void standTitle() {
        boolean row = afterNavigation != null;
        setTitle(row || titleView != null ? null : title);
        setSubtitle(row || titleView != null ? null : subtitle);
        if (titleRow != null) {
            titleRow.removeAllViews();
            removeView(titleRow);
            titleRow = null;
        }
        if (titleView != null && titleView.getParent() == this) removeView(titleView);
        setContentInsetStartWithNavigation(row ? 0 : insetWithNavigation);
        if (!row) {
            if (titleView != null) {
                addView(titleView, new Toolbar.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER_VERTICAL));
            }
            return;
        }
        titleRow = new LinearLayout(getContext());
        titleRow.setGravity(Gravity.CENTER_VERTICAL);
        titleRow.addView(afterNavigation);
        View words = titleView != null ? titleView : titleWords();
        LinearLayout.LayoutParams place = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        place.setMarginStart(getTitleMarginStart());
        titleRow.addView(words, place);
        addView(titleRow, new Toolbar.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.START | Gravity.CENTER_VERTICAL));
    }

    /** The title and the line under it, as the toolbar writes its own: in the appearances its style names. */
    private View titleWords() {
        LinearLayout words = new LinearLayout(getContext());
        words.setOrientation(LinearLayout.VERTICAL);
        words.addView(line(title, android.R.attr.titleTextAppearance));
        if (subtitle != null) words.addView(line(subtitle, android.R.attr.subtitleTextAppearance));
        return words;
    }

    private TextView line(String words, int appearance) {
        TypedArray style = getContext().obtainStyledAttributes(
                null, new int[] { appearance }, android.R.attr.toolbarStyle, 0);
        TextView line = new TextView(getContext());
        line.setTextAppearance(style.getResourceId(0, 0));
        style.recycle();
        line.setSingleLine(true);
        line.setEllipsize(android.text.TextUtils.TruncateAt.END);
        line.setText(words);
        if (foreground != 0) line.setTextColor(foreground);
        return line;
    }

    /** A button of the bar's own, in the style of its action buttons, telling the host its place when pressed. */
    private ImageButton ownButton(int place) {
        ImageButton button = new ImageButton(getContext(), null, android.R.attr.actionButtonStyle);
        button.setOnClickListener(pressed -> StateUIHost.chose(view, place));
        return button;
    }

    /** Android's up arrow, the theme's own, in `tint` where it is not 0. */
    private Drawable upArrow(int tint) {
        TypedArray attributes = getContext().obtainStyledAttributes(new int[] { android.R.attr.homeAsUpIndicator });
        Drawable icon = attributes.getDrawable(0);
        attributes.recycle();
        if (icon != null && tint != 0) icon.mutate().setTint(tint);
        return icon;
    }

    /** The navigation button - none, the way back, the sidebar's toggle in Android's menu glyph, the close. */
    void setNavigation(int kind, int tint, String description) {
        Drawable icon = null;
        if (kind == BACK) {
            icon = upArrow(tint);
        } else if (kind == SIDEBAR) {
            icon = menuGlyph(tint);
        } else if (kind == CLOSE) {
            icon = closeGlyph(tint);
        }
        setNavigationIcon(icon);
        setNavigationContentDescription(icon == null ? null : description);
        setNavigationOnClickListener(icon == null ? null : this);
    }

    /** The application's mark before the title, at Android's icon size, in its own colors; null for none. */
    void setMark(Bitmap picture) {
        setLogo(picture == null ? null : StateUIViews.glyph(getContext(), picture));
    }

    /** The sidebar's toggle at the bar's end, in the style of the bar's own action buttons; null while none shows. */
    private ImageButton endToggle;

    /**
     * The sidebar's toggle at the bar's end - Android's menu glyph in `tint` - which tells the host its place when
     * pressed; a null `description` takes it away.
     */
    void setEndToggle(int tint, String description) {
        if (description == null) {
            if (endToggle != null) removeView(endToggle);
            endToggle = null;
            return;
        }
        if (endToggle == null) {
            endToggle = ownButton(AT_END);
            addView(endToggle, new Toolbar.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.END | Gravity.CENTER_VERTICAL));
        }
        endToggle.setImageDrawable(menuGlyph(tint));
        endToggle.setContentDescription(description);
    }

    /** Android's menu glyph - three lines on its 24 dp icon grid - in `tint`, or at 0 the theme's for controls. */
    private Drawable menuGlyph(int tint) {
        Path lines = new Path();
        for (int top : new int[] {6, 11, 16}) lines.addRect(3, top, 21, top + 2, Path.Direction.CW);
        return glyph(lines, tint);
    }

    /** Material's close glyph - a cross on its 24 dp icon grid - in `tint`, or at 0 the theme's for controls. */
    private Drawable closeGlyph(int tint) {
        float[] cross = {19, 6.41f, 17.59f, 5, 12, 10.59f, 6.41f, 5, 5, 6.41f, 10.59f, 12, 5, 17.59f, 6.41f, 19,
            12, 13.41f, 17.59f, 19, 19, 17.59f, 13.41f, 12};
        Path path = new Path();
        path.moveTo(cross[0], cross[1]);
        for (int at = 2; at < cross.length; at += 2) path.lineTo(cross[at], cross[at + 1]);
        path.close();
        return glyph(path, tint);
    }

    /** `path` on the 24 dp icon grid as a drawable, in `tint` or at 0 the theme's for controls. */
    private Drawable glyph(Path path, int tint) {
        ShapeDrawable glyph = new ShapeDrawable(new PathShape(path, 24, 24));
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
    void setActions(int[] entries, String[] texts, Bitmap[] pictures, int weight) {
        Menu menu = getMenu();
        menu.clear();
        StateUIMenus.fill(getContext(), menu, view, entries, texts, pictures, foreground, weight);
    }

    @Override
    public void onClick(View clicked) {
        StateUIHost.clicked(view);
    }
}
