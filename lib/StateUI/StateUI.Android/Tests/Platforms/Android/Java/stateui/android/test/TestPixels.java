// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.app.Activity;
import android.content.Context;
import android.content.ContextWrapper;
import android.graphics.Bitmap;
import android.graphics.Rect;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.os.HandlerThread;
import android.view.PixelCopy;
import android.view.View;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** What a view shows, read back as a test asks it: a pixel of it on the screen, and the colour behind it. */
public final class TestPixels {
    private TestPixels() {}

    /** The colour behind every view of a test's window: where it shows, the views draw nothing. */
    public static final int NOTHING = 0xFF010203;

    /** Paints the window behind its views in `NOTHING`. */
    public static void paintNothing(Activity activity) {
        activity.getWindow().setBackgroundDrawable(new ColorDrawable(NOTHING));
    }

    /** Where a window's pixels are copied to, off the UI thread, which waits for them. */
    private static final HandlerThread copying = new HandlerThread("StateUI pixels");
    static {
        copying.start();
    }

    /**
     * The colour the window shows at (`x`, `y`) of the view's pixels, as ARGB - what the user sees, the render
     * thread's clips and outlines included - once the window has drawn what stands now; 0 where the window's own
     * `NOTHING` shows, where it lies outside the view, or where the window could not be read.
     */
    public static int color(View view, int x, int y) {
        return colors(view, new int[] {x, y})[0];
    }

    /**
     * The colours the window shows at each point of the view's pixels - `points` holds x, y, x, y and on - as
     * `color` reads one, every one from a single copy of the window: one frame waited for, however many points.
     */
    public static int[] colors(View view, int[] points) {
        int[] colors = new int[points.length / 2];
        Activity activity = activity(view.getContext());
        if (activity == null) return colors;
        // The one rectangle holding every point inside the view, which one copy reads.
        int left = Integer.MAX_VALUE, top = Integer.MAX_VALUE, right = -1, bottom = -1;
        for (int i = 0; i + 1 < points.length; i += 2) {
            if (!inside(view, points[i], points[i + 1])) continue;
            left = Math.min(left, points[i]);
            top = Math.min(top, points[i + 1]);
            right = Math.max(right, points[i]);
            bottom = Math.max(bottom, points[i + 1]);
        }
        if (right < 0) return colors;
        // The window draws on the display's next frames, which come as the thread's messages run.
        view.getRootView().invalidate();
        TestLooper.run(100);

        int[] corner = new int[2];
        view.getLocationInWindow(corner);
        Bitmap drawn = Bitmap.createBitmap(right - left + 1, bottom - top + 1, Bitmap.Config.ARGB_8888);
        Rect source = new Rect(corner[0] + left, corner[1] + top, corner[0] + right + 1, corner[1] + bottom + 1);
        CountDownLatch copied = new CountDownLatch(1);
        int[] result = {PixelCopy.ERROR_UNKNOWN};
        PixelCopy.request(activity.getWindow(), source, drawn, done -> {
            result[0] = done;
            copied.countDown();
        }, new Handler(copying.getLooper()));
        try {
            copied.await(2, TimeUnit.SECONDS);
        } catch (InterruptedException interrupted) {
            drawn.recycle();
            return colors;
        }
        if (result[0] == PixelCopy.SUCCESS) {
            for (int i = 0; i + 1 < points.length; i += 2) {
                if (!inside(view, points[i], points[i + 1])) continue;
                int color = drawn.getPixel(points[i] - left, points[i + 1] - top);
                colors[i / 2] = color == NOTHING ? 0 : color;
            }
        }
        drawn.recycle();
        return colors;
    }

    private static boolean inside(View view, int x, int y) {
        return x >= 0 && y >= 0 && x < view.getWidth() && y < view.getHeight();
    }

    private static Activity activity(Context context) {
        while (context instanceof ContextWrapper) {
            if (context instanceof Activity) return (Activity) context;
            context = ((ContextWrapper) context).getBaseContext();
        }
        return null;
    }

    /** The one colour behind the view, as ARGB, and whether it is one: 0 and false for any other background. */
    public static long background(View view) {
        Drawable drawn = view.getBackground();
        if (!(drawn instanceof ColorDrawable)) return 0;
        return (1L << 32) | (((ColorDrawable) drawn).getColor() & 0xFFFFFFFFL);
    }
}
