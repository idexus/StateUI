// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.os.Build;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.Menu;
import android.view.MenuItem;
import android.view.SubMenu;
import java.util.ArrayDeque;

/**
 * A menu's entries - a bar's actions, a view's context menu - written into Android's own menu in one call
 * from the Swift host's description. Each entry is an int - its kind and its flags - and each item and
 * submenu takes the next text and picture; an item chosen is reported by its place among the items, and
 * its id is that place plus one - a submenu's is none.
 */
final class StateUIMenus {
    /** An entry's kind, in its lowest bits. */
    static final int ITEM = 0, MENU = 1, END = 2, SEPARATOR = 3, KIND = 3;

    /** An entry's flags: not enabled, destructive, and standing on the bar beside the title where room allows. */
    static final int DISABLED = 4, DESTRUCTIVE = 8, ON_BAR = 16;

    private StateUIMenus() {}

    /**
     * Adds the entries to `menu`: a submenu's entries follow it up to its END, and a separator starts a new
     * group, a line drawn between groups. `pictures` may be null; the picture of an item that cannot be chosen
     * is dimmed as the theme dims what is disabled, which Android does not do for a menu's picture.
     */
    static void fill(Context context, Menu menu, long view, int[] entries, String[] texts, Bitmap[] pictures) {
        int error = errorColor(context);
        int dimmed = Math.round(255 * StateUIViews.disabledAlpha(context));
        ArrayDeque<Menu> outerMenus = new ArrayDeque<>();
        ArrayDeque<Integer> outerGroups = new ArrayDeque<>();
        Menu current = menu;
        int group = 0;
        int text = 0;
        int item = 0;
        divideGroups(menu);

        for (int entry : entries) {
            switch (entry & KIND) {
                case ITEM: {
                    MenuItem added = current.add(group, item + 1, Menu.NONE, words(texts[text], entry, error));
                    Bitmap picture = pictures == null ? null : pictures[text];
                    text++;
                    if (picture != null) {
                        BitmapDrawable drawable = new BitmapDrawable(context.getResources(), picture);
                        if ((entry & DISABLED) != 0) {
                            drawable.setAlpha(dimmed);
                        } else if ((entry & DESTRUCTIVE) != 0) {
                            drawable.setTint(error);
                        }
                        added.setIcon(drawable);
                    }
                    added.setEnabled((entry & DISABLED) == 0);
                    added.setShowAsAction(
                            (entry & ON_BAR) != 0 ? MenuItem.SHOW_AS_ACTION_IF_ROOM : MenuItem.SHOW_AS_ACTION_NEVER);
                    int chosen = item++;
                    added.setOnMenuItemClickListener(clicked -> {
                        StateUIHost.menuChose(view, chosen);
                        return true;
                    });
                    break;
                }
                case MENU: {
                    SubMenu inner = current.addSubMenu(group, Menu.NONE, Menu.NONE, words(texts[text++], entry, error));
                    inner.getItem().setEnabled((entry & DISABLED) == 0);
                    divideGroups(inner);
                    outerMenus.push(current);
                    outerGroups.push(group);
                    current = inner;
                    group = 0;
                    break;
                }
                case END:
                    current = outerMenus.pop();
                    group = outerGroups.pop();
                    break;
                default:
                    group++;
            }
        }
    }

    /**
     * The entry's words, in the theme's error colour where it is destructive and can be chosen: one that cannot
     * keeps the platform's disabled colour, which a colour of its own would hide.
     */
    private static CharSequence words(String text, int entry, int error) {
        if ((entry & DESTRUCTIVE) == 0 || (entry & DISABLED) != 0) return text;
        SpannableString coloured = new SpannableString(text);
        coloured.setSpan(new ForegroundColorSpan(error), 0, text.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        return coloured;
    }

    /** A line between groups, where Android draws one - from Android 9. */
    private static void divideGroups(Menu menu) {
        if (Build.VERSION.SDK_INT >= 28) menu.setGroupDividerEnabled(true);
    }

    /** The theme's colour for what cannot be undone. */
    private static int errorColor(Context context) {
        TypedArray attributes = context.obtainStyledAttributes(new int[] { android.R.attr.colorError });
        int color = attributes.getColor(0, 0xFFB3261E);
        attributes.recycle();
        return color;
    }
}
