// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.content.Context;
import android.content.res.TypedArray;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.PopupMenu;

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

    private static int colour(CharSequence words) {
        if (!(words instanceof Spanned)) return 0;
        ForegroundColorSpan[] spans = ((Spanned) words).getSpans(0, words.length(), ForegroundColorSpan.class);
        return spans.length == 0 ? 0 : spans[0].getForegroundColor();
    }
}
