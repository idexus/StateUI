// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.app.Activity;
import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.LayerDrawable;
import android.os.Build;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.view.inspector.WindowInspector;
import android.widget.ActionMenuView;
import android.widget.ListView;
import android.widget.PopupMenu;
import android.widget.TextView;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;

/** A menu read back as words, and an item chosen by its words - what a test of the host's menus asks. */
public final class TestMenus {
    private TestMenus() {}

    /** The layer a button's foreground draws the arrow after its words in: StateUIViews' MARK_LAYER. */
    private static final int MARK_LAYER = 2;

    /** Whether `button` shows the arrow saying its click opens its menu, among the layers of its foreground. */
    public static boolean showsMenuArrow(View button) {
        Drawable foreground = button.getForeground();
        return foreground instanceof LayerDrawable && ((LayerDrawable) foreground).findDrawableByLayerId(MARK_LAYER) != null;
    }

    /** An empty menu of Android's own, as a context menu is before its view writes it. */
    public static Menu empty(Context context) {
        return new PopupMenu(context, new View(context)).getMenu();
    }

    /** A menu popping up below the top corner of `activity`'s window, empty until a test writes it. */
    public static PopupMenu over(Activity activity) {
        View corner = new View(activity);
        ((ViewGroup) activity.getWindow().getDecorView()).addView(corner, new ViewGroup.LayoutParams(1, 1));
        PopupMenu menu = new PopupMenu(activity, corner);
        menu.setOnDismissListener(gone -> ((ViewGroup) corner.getParent()).removeView(corner));
        return menu;
    }

    /**
     * The words each row of the menu showing in a window of its own shows within the row, as the user reads them -
     * ", " between rows, "(none)" for a row showing none, "(no menu)" where none shows - after which the menu goes.
     */
    public static String shownRows(PopupMenu shown) throws ReflectiveOperationException {
        ListView rows = null;
        for (View window : windows()) {
            ListView found = listIn(window);
            if (found != null) rows = found;
        }
        if (rows == null) return "(no menu)";
        List<String> words = new ArrayList<>();
        for (int index = 0; index < rows.getChildCount(); index++) {
            String row = wordsShown(rows.getChildAt(index));
            words.add(row.isEmpty() ? "(none)" : row);
        }
        shown.dismiss();
        return String.join(", ", words);
    }

    /** The root view of every window the process shows: Android's own list from Android 10, its manager's before. */
    @SuppressWarnings("unchecked")
    private static List<View> windows() throws ReflectiveOperationException {
        if (Build.VERSION.SDK_INT >= 29) return WindowInspector.getGlobalWindowViews();
        Class<?> global = Class.forName("android.view.WindowManagerGlobal");
        Object manager = global.getMethod("getInstance").invoke(null);
        Field views = global.getDeclaredField("mViews");
        views.setAccessible(true);
        return new ArrayList<>((List<View>) views.get(manager));
    }

    private static ListView listIn(View view) {
        if (view instanceof ListView) return (ListView) view;
        if (!(view instanceof ViewGroup)) return null;
        ViewGroup group = (ViewGroup) view;
        for (int index = 0; index < group.getChildCount(); index++) {
            ListView found = listIn(group.getChildAt(index));
            if (found != null) return found;
        }
        return null;
    }

    /** The words of the text views `view` shows on screen, some of each standing in its own bounds. */
    private static String wordsShown(View view) {
        if (view instanceof TextView) {
            TextView text = (TextView) view;
            return text.isShown() && text.getText().length() > 0 && text.getGlobalVisibleRect(new Rect())
                    ? text.getText().toString() : "";
        }
        if (!(view instanceof ViewGroup)) return "";
        ViewGroup group = (ViewGroup) view;
        StringBuilder words = new StringBuilder();
        for (int index = 0; index < group.getChildCount(); index++) {
            String inner = wordsShown(group.getChildAt(index));
            if (!inner.isEmpty() && words.length() > 0) words.append(' ');
            words.append(inner);
        }
        return words.toString();
    }

    /**
     * The menu's entries: each item's words, a submenu's entries in brackets after its own, ", " within a
     * group and " | " between groups; " (off)" where it cannot be chosen, " (red)" where its words are in the
     * theme's error color, " (picture)" where it has one - " (dimmed picture)" where it is drawn translucent.
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
            if (color(title) == error) words.append(" (red)");
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
     * words are in the theme's error color, whether it has a picture and whether it stands checked, then the
     * character of the shortcut it shows - 0 for none - and the modifiers held with it; null where the menu holds
     * no such item.
     */
    public static String held(Context context, Menu menu, int id) {
        MenuItem item = menu.findItem(id);
        if (item == null) return null;
        TypedArray attributes = context.obtainStyledAttributes(new int[] { android.R.attr.colorError });
        int error = attributes.getColor(0, 0);
        attributes.recycle();
        CharSequence title = item.getTitle();
        boolean letter = item.getAlphabeticShortcut() != 0;
        char key = letter ? item.getAlphabeticShortcut() : item.getNumericShortcut();
        int modifiers = letter ? item.getAlphabeticModifiers() : item.getNumericModifiers();
        return title + "\n" + (item.isEnabled() ? 1 : 0) + "\n" + (color(title) == error ? 1 : 0)
                + "\n" + (item.getIcon() != null ? 1 : 0) + "\n" + (item.isChecked() ? 1 : 0)
                + "\n" + (int) key + "\n" + (key == 0 ? 0 : modifiers);
    }

    /** Whether the item of `id` shows `picture`: the very pixels of it. */
    public static boolean shows(Menu menu, int id, Bitmap picture) {
        MenuItem item = menu.findItem(id);
        Drawable icon = item == null ? null : item.getIcon();
        return icon instanceof BitmapDrawable && ((BitmapDrawable) icon).getBitmap().sameAs(picture);
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
     * "dark", or "picture" and the color at the middle of its picture as drawn - ARGB in hexadecimal - ", "
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
                    int color = action.getCurrentTextColor();
                    double luminance = 0.2126 * Color.red(color) + 0.7152 * Color.green(color) + 0.0722 * Color.blue(color);
                    words.append(action.getText()).append(luminance / 255 < 0.5 ? " dark" : " light");
                } else if (picture != null) {
                    words.append("picture #").append(Integer.toHexString(middle(picture)));
                }
            }
        }
        return words.toString();
    }

    /**
     * The bar's entries as it lays them out, a line each in its menu's order: its id, its group, whether it stands
     * on the bar as an action, whether its words show there, and whether it can be chosen - numbers, spaces between.
     */
    public static String laidOut(ViewGroup bar, Menu menu) {
        List<TextView> actions = new ArrayList<>();
        for (int index = 0; index < bar.getChildCount(); index++) {
            if (!(bar.getChildAt(index) instanceof ActionMenuView)) continue;
            ActionMenuView row = (ActionMenuView) bar.getChildAt(index);
            for (int place = 0; place < row.getChildCount(); place++) {
                if (row.getChildAt(place) instanceof TextView) actions.add((TextView) row.getChildAt(place));
            }
        }
        StringBuilder lines = new StringBuilder();
        for (int index = 0; index < menu.size(); index++) {
            MenuItem item = menu.getItem(index);
            if (!item.isVisible()) continue;
            String title = String.valueOf(item.getTitle());
            TextView action = null;
            for (TextView each : actions) {
                if (title.equals(String.valueOf(each.getText())) || title.equals(String.valueOf(each.getContentDescription()))) {
                    action = each;
                }
            }
            lines.append(item.getItemId()).append(' ').append(item.getGroupId()).append(' ')
                    .append(action != null ? 1 : 0).append(' ').append(action != null && action.getText().length() > 0 ? 1 : 0)
                    .append(' ').append(item.isEnabled() ? 1 : 0).append('\n');
        }
        return lines.toString();
    }

    /** The color `picture` draws at its middle. */
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

    private static int color(CharSequence words) {
        if (!(words instanceof Spanned)) return 0;
        ForegroundColorSpan[] spans = ((Spanned) words).getSpans(0, words.length(), ForegroundColorSpan.class);
        return spans.length == 0 ? 0 : spans[0].getForegroundColor();
    }
}
