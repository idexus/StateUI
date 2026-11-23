// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * The application's pictures read into bitmaps - a file of the assets, or bytes where there is no file - at once, or
 * beside the UI thread for a view that shows what it holds meanwhile.
 */
final class StateUIPictures {
    private static final Handler ui = new Handler(Looper.getMainLooper());
    private static final ExecutorService readers = Executors.newFixedThreadPool(2);

    private StateUIPictures() {}

    /** The picture's size in pixels, read from its header alone; null where it is no picture. */
    static int[] size(AssetManager assets, String path, byte[] bytes) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        decode(assets, path, bytes, options);
        return options.outWidth > 0 && options.outHeight > 0 ? new int[] {options.outWidth, options.outHeight} : null;
    }

    /**
     * The picture drawn at `density` pixels per inch, read at one pixel in `sample` across and down and scaled to
     * `target` as it is read; null where it is no picture. The bitmap says the density a whole one would have, so it
     * is drawn at the picture's own size.
     */
    static Bitmap read(AssetManager assets, String path, byte[] bytes, int sample, int density, int target) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = sample;
        options.inDensity = density;
        options.inTargetDensity = target;
        options.inScaled = true;
        Bitmap bitmap = decode(assets, path, bytes, options);
        if (bitmap != null) bitmap.setDensity(Math.max(1, target / sample));
        return bitmap;
    }

    /** The same reading beside the UI thread, its bitmap - null for none - handed to the host under `ticket` there. */
    static void readLater(
            long ticket, AssetManager assets, String path, byte[] bytes, int sample, int density, int target) {
        readers.execute(() -> {
            Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND);
            Bitmap bitmap = read(assets, path, bytes, sample, density, target);
            ui.post(() -> StateUIHost.pictureRead(ticket, bitmap));
        });
    }

    private static Bitmap decode(AssetManager assets, String path, byte[] bytes, BitmapFactory.Options options) {
        if (path == null) return BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);
        try (InputStream stream = assets.open(path)) {
            return BitmapFactory.decodeStream(stream, null, options);
        } catch (IOException missing) {
            return null;
        }
    }
}
