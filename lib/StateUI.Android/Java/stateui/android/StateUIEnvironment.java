// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.os.Build;
import android.util.DisplayMetrics;
import android.view.Display;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import java.util.Calendar;
import java.util.TimeZone;

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

    /** The local time of day: hour, minute, second and millisecond. */
    static int[] clock() {
        Calendar now = Calendar.getInstance();
        return new int[] {
            now.get(Calendar.HOUR_OF_DAY), now.get(Calendar.MINUTE), now.get(Calendar.SECOND),
            now.get(Calendar.MILLISECOND),
        };
    }

    /** The IANA identifier of the local time zone. */
    static String zone() {
        return TimeZone.getDefault().getID();
    }

    /** How far `zone` - the local one for null - is from UTC at noon of a day - today where year is 0 - in minutes. */
    static int utcOffset(String zone, int year, int month, int day) {
        TimeZone timeZone = zone == null ? TimeZone.getDefault() : TimeZone.getTimeZone(zone);
        Calendar noon = Calendar.getInstance(timeZone);
        if (year != 0) noon.set(year, month - 1, day, 12, 0, 0);
        return timeZone.getOffset(noon.getTimeInMillis()) / 60000;
    }

    /**
     * The window's title: the activity's, and the label its task shows among the recent ones - none gives back
     * the application's own. A context that is no activity takes none.
     */
    static void title(Context context, String title) {
        if (!(context instanceof Activity)) return;
        Activity activity = (Activity) context;
        activity.setTitle(title);
        activity.setTaskDescription(task(title));
    }

    @SuppressWarnings("deprecation")
    private static ActivityManager.TaskDescription task(String label) {
        if (Build.VERSION.SDK_INT >= 33) return new ActivityManager.TaskDescription.Builder().setLabel(label).build();
        return new ActivityManager.TaskDescription(label);
    }

    /** Takes the keyboard down from whatever holds the focus under `root`; whether anything did. */
    static boolean hideKeyboard(View root) {
        View holder = root.findFocus();
        if (holder == null) return false;
        InputMethodManager keyboard = root.getContext().getSystemService(InputMethodManager.class);
        if (keyboard != null) keyboard.hideSoftInputFromWindow(holder.getWindowToken(), 0);
        holder.clearFocus();
        return true;
    }
}
