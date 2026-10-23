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
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.SubMenu;
import android.view.View;
import android.widget.PopupMenu;
import java.util.ArrayDeque;

/**
 * A menu's entries - a bar's actions, a view's context menu - written into Android's own menu in one call
 * from the Swift host's description. Each entry is an int - its kind and its flags - and each item and
 * submenu takes the next text and picture; an item chosen is reported by its place among the items, and
 * its id is that place plus one - a submenu's is none.
 */
final class StateUIMenus {
    /** An entry's kind, in its lowest bits - the bits `KIND` masks. */
    // Swift: AndroidMenuEntry
    static final int ITEM = 0, MENU = 1, END = 2, SEPARATOR = 3;
    // Swift: none
    static final int KIND = 3;

    /**
     * An entry's flags: not enabled, destructive, standing on the bar beside the title where room allows, showing
     * its words there beside its picture where room allows, standing checked or not, and checked.
     */
    // Swift: AndroidMenuMark
    static final int DISABLED = 4, DESTRUCTIVE = 8, ON_BAR = 16, WITH_TEXT = 32, CHECKABLE = 64, CHECKED = 128;

    /** An item's shortcut: the modifiers held with its key, whose character stands in the entry's upper half. */
    // Swift: AndroidMenuModifier
    static final int CONTROL = 256, SHIFT = 512, ALT = 1024;

    private StateUIMenus() {}

    /** A menu popping up at `anchor`, its entries written before it shows: a button's menu. */
    static PopupMenu popUp(View anchor) {
        return new PopupMenu(anchor.getContext(), anchor);
    }

    /**
     * Adds the entries to `menu`: a submenu's entries follow it up to its END, and a separator starts a new
     * group, a line drawn between groups. `pictures` may be null; the picture of an item that cannot be chosen
     * is dimmed as the theme dims what is disabled, which Android does not do for a menu's picture. A bar's
     * actions standing on it take `bar`, the bar's words' color, for their pictures; 0 leaves them as drawn.
     */
    static void fill(Context context, Menu menu, long view, int[] entries, String[] texts, Bitmap[] pictures, int bar) {
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
                        BitmapDrawable drawable = StateUIViews.glyph(context, picture);
                        boolean destructive = (entry & DESTRUCTIVE) != 0 && (entry & DISABLED) == 0;
                        if (destructive) {
                            drawable.setTint(error);
                        } else if (bar != 0 && (entry & ON_BAR) != 0) {
                            drawable.setTint(bar);
                        }
                        if ((entry & DISABLED) != 0) drawable.setAlpha(dimmed);
                        added.setIcon(drawable);
                    }
                    added.setEnabled((entry & DISABLED) == 0);
                    if ((entry & CHECKABLE) != 0) {
                        added.setCheckable(true);
                        added.setChecked((entry & CHECKED) != 0);
                    }
                    showShortcut(added, entry);
                    int withText = (entry & WITH_TEXT) != 0 ? MenuItem.SHOW_AS_ACTION_WITH_TEXT : 0;
                    added.setShowAsAction(
                            (entry & ON_BAR) != 0 ? MenuItem.SHOW_AS_ACTION_IF_ROOM | withText : MenuItem.SHOW_AS_ACTION_NEVER);
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
     * Shows the item's shortcut beside its words, as Android does while a keyboard is attached: a digit's on the
     * numeric keys, any other character's on the letters. The host hears the key itself; the menu only shows it.
     */
    private static void showShortcut(MenuItem item, int entry) {
        char key = (char) (entry >>> 16);
        if (key == 0) return;
        int meta = ((entry & CONTROL) != 0 ? KeyEvent.META_CTRL_ON : 0)
                | ((entry & SHIFT) != 0 ? KeyEvent.META_SHIFT_ON : 0)
                | ((entry & ALT) != 0 ? KeyEvent.META_ALT_ON : 0);
        if (Character.isDigit(key)) {
            item.setNumericShortcut(key, meta);
        } else {
            item.setAlphabeticShortcut(key, meta);
        }
    }

    /**
     * The entry's words, in the theme's error color where it is destructive and can be chosen: one that cannot
     * keeps the platform's disabled color, which a color of its own would hide.
     */
    private static CharSequence words(String text, int entry, int error) {
        if ((entry & DESTRUCTIVE) == 0 || (entry & DISABLED) != 0) return text;
        SpannableString colored = new SpannableString(text);
        colored.setSpan(new ForegroundColorSpan(error), 0, text.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        return colored;
    }

    /**
     * A line between groups, where Android draws one above the group's first row - from Android 10. Android 9
     * lays it beside the row's words, which it pushes out of the row.
     */
    private static void divideGroups(Menu menu) {
        if (Build.VERSION.SDK_INT >= 29) menu.setGroupDividerEnabled(true);
    }

    /** The theme's color for what cannot be undone. */
    private static int errorColor(Context context) {
        TypedArray attributes = context.obtainStyledAttributes(new int[] { android.R.attr.colorError });
        int color = attributes.getColor(0, 0xFFB3261E);
        attributes.recycle();
        return color;
    }
}
