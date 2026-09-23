// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.os.Build;
import android.util.DisplayMetrics;
import android.view.Display;

/** What the device, its display and the application are, each read in one call for the Swift host. */
final class StateUIEnvironment {
    private StateUIEnvironment() {}

    /** The model, the maker, the device's name, Android's version, and "1" on an emulator. */
    static String[] device() {
        boolean emulator = Build.FINGERPRINT.startsWith("generic") || Build.HARDWARE.contains("ranchu")
                || Build.HARDWARE.contains("goldfish") || Build.PRODUCT.contains("sdk");
        return new String[] { Build.MODEL, Build.MANUFACTURER, Build.DEVICE, Build.VERSION.RELEASE,
                emulator ? "1" : "0" };
    }

    /**
     * The display in pixels, its density, its rotation in quarter turns, its refresh rate, the smallest width
     * in density-independent pixels, and 1 where the system's theme is dark.
     */
    @SuppressWarnings("deprecation")
    static float[] display(Activity activity) {
        DisplayMetrics metrics = activity.getResources().getDisplayMetrics();
        Configuration configuration = activity.getResources().getConfiguration();
        Display display = Build.VERSION.SDK_INT >= 30
                ? activity.getDisplay()
                : activity.getWindowManager().getDefaultDisplay();
        boolean night = (configuration.uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        return new float[] {
            metrics.widthPixels, metrics.heightPixels, metrics.density,
            display == null ? 0 : display.getRotation(), display == null ? 60 : display.getRefreshRate(),
            configuration.smallestScreenWidthDp, night ? 1 : 0,
        };
    }

    /** The application's name, its package, and its version's name and number. */
    static String[] application(Context context) {
        String version = "";
        String build = "";
        try {
            PackageInfo info = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            version = info.versionName == null ? "" : info.versionName;
            build = Long.toString(info.getLongVersionCode());
        } catch (PackageManager.NameNotFoundException missing) {
            // The package reading itself is always found.
        }
        CharSequence label = context.getApplicationInfo().loadLabel(context.getPackageManager());
        return new String[] { label.toString(), context.getPackageName(), version, build };
    }

    /** Whether the system's theme is dark. */
    static boolean night(Context context) {
        int mode = context.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
        return mode == Configuration.UI_MODE_NIGHT_YES;
    }
}
