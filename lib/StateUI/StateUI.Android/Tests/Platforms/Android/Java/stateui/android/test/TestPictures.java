// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;
import android.view.Menu;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.List;

/** The pictures a bar and a row of tabs stand at, read back as "width x height" pixels. */
public final class TestPictures {
    private TestPictures() {}

    /** Each tab's picture - the one above its words - in order, separated by ", ". */
    public static String tabs(ViewGroup row) {
        List<String> sizes = new ArrayList<>();
        for (int index = 0; index < row.getChildCount(); index++) {
            Drawable picture = ((TextView) row.getChildAt(index)).getCompoundDrawablesRelative()[1];
            sizes.add(size(picture));
        }
        return String.join(", ", sizes);
    }

    /** Each menu item's picture, in order, separated by ", ". */
    public static String menu(Menu menu) {
        List<String> sizes = new ArrayList<>();
        for (int index = 0; index < menu.size(); index++) sizes.add(size(menu.getItem(index).getIcon()));
        return String.join(", ", sizes);
    }

    /** `points` density-independent pixels, in this device's pixels. */
    public static int pixels(Context context, float points) {
        return Math.round(points * context.getResources().getDisplayMetrics().density);
    }

    /** A square `side` pixels across, one color, as a PNG's bytes. */
    public static byte[] square(int side) {
        Bitmap drawn = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888);
        drawn.eraseColor(Color.BLUE);
        java.io.ByteArrayOutputStream bytes = new java.io.ByteArrayOutputStream();
        drawn.compress(Bitmap.CompressFormat.PNG, 100, bytes);
        drawn.recycle();
        return bytes.toByteArray();
    }

    /** The image view's picture drawn alone at its own size: its most opaque pixel, as ARGB; 0 for none. */
    public static int imageInk(ImageView view) {
        return ink(view.getDrawable());
    }

    /** The picture before a button's words, drawn alone at its own size: its most opaque pixel; 0 for none. */
    public static int iconInk(TextView view) {
        return ink(view.getCompoundDrawablesRelative()[0]);
    }

    /** The picture a button with no words shows in its middle, drawn alone at its own size: its most opaque pixel. */
    public static int aloneInk(TextView view) {
        return ink(view.getForeground());
    }

    private static int ink(Drawable picture) {
        if (picture == null) return 0;
        int width = Math.max(1, picture.getIntrinsicWidth());
        int height = Math.max(1, picture.getIntrinsicHeight());
        Bitmap drawn = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Rect bounds = picture.copyBounds();
        picture.setBounds(0, 0, width, height);
        picture.draw(new Canvas(drawn));
        picture.setBounds(bounds);
        int ink = 0;
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int pixel = drawn.getPixel(x, y);
                if (Color.alpha(pixel) > Color.alpha(ink)) ink = pixel;
            }
        }
        drawn.recycle();
        return ink;
    }

    private static String size(Drawable picture) {
        return picture == null ? "none" : picture.getIntrinsicWidth() + "x" + picture.getIntrinsicHeight();
    }
}
