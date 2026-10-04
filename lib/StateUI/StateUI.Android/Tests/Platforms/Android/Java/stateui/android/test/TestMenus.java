// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ActionMenuView;
import android.widget.PopupMenu;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.List;

/** A menu read back as words, and an item chosen by its words - what a test of the host's menus asks. */
public final class TestMenus {
    private TestMenus() {}

    /** An empty menu of Android's own, as a context menu is before its view writes it. */
    public static Menu empty(Context context) {
        return new PopupMenu(context, new View(context)).getMenu();
    }

    /**
     * The menu's entries: each item's words, a submenu's entries in brackets after its own, ", " within a
     * group and " | " between groups; " (off)" where it cannot be chosen, " (red)" where its words are in the
     * theme's error colour, " (picture)" where it has one - " (dimmed picture)" where it is drawn translucent.
     */
    public static String describe(Context context, Menu menu) {
        TypedArray attributes = context.obtainStyledAttributes(new int[] { android.R.attr.colorError });
        int error = attributes.getColor(0, 0);
        attributes.recycle();

        StringBuilder words = new StringBuilder();
        for (int index = 0; index < menu.size(); index++) {
            MenuItem item = menu.getItem(index);
            if (index > 0) words.append(item.getGroupId() == menu.getItem(index - 1).getGroupId() ? ", " : " | ");
            CharSequence title = item.getTitle();
            words.append(title);
            if (!item.isEnabled()) words.append(" (off)");
            if (colour(title) == error) words.append(" (red)");
            if (item.getIcon() != null) {
                words.append(item.getIcon().getAlpha() < 255 ? " (dimmed picture)" : " (picture)");
            }
            if (item.hasSubMenu()) words.append(" [").append(describe(context, item.getSubMenu())).append("]");
        }
        return words.toString();
    }

    /**
     * The menu as the conformance suite writes it: each entry by its words, "!" before one that cannot be chosen,
     * "-" between two groups, a submenu's entries in brackets after its words, ";" between. `menusOnly` says the
     * submenus at its top alone - a bar's menus, apart from its actions.
     */
    public static String said(Menu menu, boolean menusOnly) {
        List<String> parts = new ArrayList<>();
        Integer group = null;
        for (int index = 0; index < menu.size(); index++) {
            MenuItem item = menu.getItem(index);
            if (menusOnly && !item.hasSubMenu()) continue;
            if (group != null && item.getGroupId() != group) parts.add("-");
            group = item.getGroupId();
            String part = (item.isEnabled() ? "" : "!") + item.getTitle();
            if (item.hasSubMenu()) part += "[" + said(item.getSubMenu(), false) + "]";
            parts.add(part);
        }
        return String.join(";", parts);
    }

    /** Chooses the item of `id`, in `menu` or a submenu of it, as a touch does; whether it ran. */
    public static boolean choose(Menu menu, int id) {
        return menu.performIdentifierAction(id, 0);
    }

    /**
     * What the item of `id` holds, a line each: its words, then 1 or 0 for whether it can be chosen, whether its
     * words are in the theme's error colour and whether it has a picture; null where the menu holds no such item.
     */
    public static String held(Context context, Menu menu, int id) {
        MenuItem item = menu.findItem(id);
        if (item == null) return null;
        TypedArray attributes = context.obtainStyledAttributes(new int[] { android.R.attr.colorError });
        int error = attributes.getColor(0, 0);
        attributes.recycle();
        CharSequence title = item.getTitle();
        return title + "\n" + (item.isEnabled() ? 1 : 0) + "\n" + (colour(title) == error ? 1 : 0)
                + "\n" + (item.getIcon() != null ? 1 : 0);
    }

    /** Chooses the item whose words are `text`, in `menu` or a submenu of it, as a touch does; whether it ran. */
    public static boolean choose(Menu menu, String text) {
        for (int index = 0; index < menu.size(); index++) {
            MenuItem item = menu.getItem(index);
            if (item.hasSubMenu()) {
                if (choose(item.getSubMenu(), text)) return true;
            } else if (item.getTitle().toString().equals(text)) {
                return menu.performIdentifierAction(item.getItemId(), 0);
            }
        }
        return false;
    }

    /**
     * The actions standing on `bar`, as it lays them out: each one's words and whether they are drawn "light" or
     * "dark", or "picture" and the colour at the middle of its picture as drawn - ARGB in hexadecimal - ", "
     * between them.
     */
    public static String onBar(ViewGroup bar) {
        StringBuilder words = new StringBuilder();
        for (int index = 0; index < bar.getChildCount(); index++) {
            if (!(bar.getChildAt(index) instanceof ActionMenuView)) continue;
            ActionMenuView actions = (ActionMenuView) bar.getChildAt(index);
            for (int place = 0; place < actions.getChildCount(); place++) {
                if (!(actions.getChildAt(place) instanceof TextView)) continue;
                TextView action = (TextView) actions.getChildAt(place);
                Drawable picture = action.getCompoundDrawables()[0];
                if (words.length() > 0) words.append(", ");
                if (action.getText().length() > 0) {
                    int colour = action.getCurrentTextColor();
                    double luminance = 0.2126 * Color.red(colour) + 0.7152 * Color.green(colour) + 0.0722 * Color.blue(colour);
                    words.append(action.getText()).append(luminance / 255 < 0.5 ? " dark" : " light");
                } else if (picture != null) {
                    words.append("picture #").append(Integer.toHexString(middle(picture)));
                }
            }
        }
        return words.toString();
    }

    /** The colour `picture` draws at its middle. */
    private static int middle(Drawable picture) {
        int width = Math.max(1, picture.getIntrinsicWidth());
        int height = Math.max(1, picture.getIntrinsicHeight());
        Bitmap drawn = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Rect bounds = picture.copyBounds();
        picture.setBounds(0, 0, width, height);
        picture.draw(new Canvas(drawn));
        picture.setBounds(bounds);
        return drawn.getPixel(width / 2, height / 2);
    }

    private static int colour(CharSequence words) {
        if (!(words instanceof Spanned)) return 0;
        ForegroundColorSpan[] spans = ((Spanned) words).getSpans(0, words.length(), ForegroundColorSpan.class);
        return spans.length == 0 ? 0 : spans[0].getForegroundColor();
    }
}
