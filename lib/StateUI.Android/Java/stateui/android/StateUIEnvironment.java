// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.icu.util.LocaleData;
import android.icu.util.ULocale;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.text.TextUtils;
import android.text.format.DateFormat;
import android.util.DisplayMetrics;
import android.view.Display;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import java.util.Calendar;
import java.util.Locale;
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

    /**
     * The language, the region, the locale's tag, the zone, "1" for a 24-hour clock, the week's first day (1 is
     * Sunday), "1" for metric units, and "1" where the language is written right to left.
     */
    static String[] locale(Context context) {
        Locale locale = context.getResources().getConfiguration().getLocales().get(0);
        boolean metric = LocaleData.getMeasurementSystem(ULocale.forLocale(locale)) != LocaleData.MeasurementSystem.US;
        boolean rightToLeft = TextUtils.getLayoutDirectionFromLocale(locale) == View.LAYOUT_DIRECTION_RTL;
        return new String[] {
            locale.getLanguage(), locale.getCountry(), locale.toLanguageTag(), TimeZone.getDefault().getID(),
            DateFormat.is24HourFormat(context) ? "1" : "0",
            Integer.toString(Calendar.getInstance(locale).getFirstDayOfWeek()),
            metric ? "1" : "0", rightToLeft ? "1" : "0",
        };
    }

    /**
     * The charge from 0 to 1 - -1 with no battery - its {@code BatteryManager} status, what it is plugged into, and
     * 1 while the battery saver is on.
     */
    static float[] battery(Context context) {
        Intent battery = context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        PowerManager power = context.getSystemService(PowerManager.class);
        float saver = power != null && power.isPowerSaveMode() ? 1 : 0;
        if (battery == null || !battery.getBooleanExtra(BatteryManager.EXTRA_PRESENT, true)) {
            return new float[] { -1, 0, 0, saver };
        }
        int level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        int scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
        return new float[] {
            level >= 0 && scale > 0 ? level / (float) scale : -1,
            battery.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN),
            battery.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0), saver,
        };
    }

    /**
     * Whether the internet is reachable - 4, 3 behind a portal or not yet proved, 2 on a local network alone, 1
     * with no network, 0 where the application may not ask - and the connections in use as bits: 1 Bluetooth, 2
     * cellular, 4 ethernet, 8 Wi-Fi.
     */
    static int[] connectivity(Context context) {
        ConnectivityManager manager = context.getSystemService(ConnectivityManager.class);
        try {
            Network network = manager == null ? null : manager.getActiveNetwork();
            NetworkCapabilities capabilities = network == null ? null : manager.getNetworkCapabilities(network);
            if (capabilities == null) return new int[] { 1, 0 };
            int access = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ? 2
                    : capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                            && !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL) ? 4 : 3;
            int kinds = (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) ? 1 : 0)
                    | (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ? 2 : 0)
                    | (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ? 4 : 0)
                    | (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ? 8 : 0);
            return new int[] { access, kinds };
        } catch (SecurityException notAllowed) {
            return new int[] { 0, 0 };
        }
    }

    /**
     * Tells the Swift host whenever the zone, the clock, the battery, its saver or the network changes, until
     * {@link #unwatch} is handed what this answers.
     */
    static Object[] watch(Context context) {
        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context sender, Intent intent) {
                StateUIHost.environmentChanged();
            }
        };
        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_BATTERY_CHANGED);
        filter.addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED);
        filter.addAction(Intent.ACTION_TIMEZONE_CHANGED);
        filter.addAction(Intent.ACTION_TIME_CHANGED);
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(receiver, filter);
        }

        ConnectivityManager.NetworkCallback network = new ConnectivityManager.NetworkCallback() {
            @Override
            public void onCapabilitiesChanged(Network changed, NetworkCapabilities capabilities) {
                StateUIHost.environmentChanged();
            }

            @Override
            public void onLost(Network lost) {
                StateUIHost.environmentChanged();
            }
        };
        ConnectivityManager manager = context.getSystemService(ConnectivityManager.class);
        try {
            manager.registerDefaultNetworkCallback(network, new Handler(Looper.getMainLooper()));
        } catch (SecurityException notAllowed) {
            network = null;
        }
        return new Object[] { receiver, network };
    }

    /** Stops what {@link #watch} started. */
    static void unwatch(Context context, Object[] watch) {
        context.unregisterReceiver((BroadcastReceiver) watch[0]);
        if (watch[1] != null) {
            context.getSystemService(ConnectivityManager.class)
                    .unregisterNetworkCallback((ConnectivityManager.NetworkCallback) watch[1]);
        }
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
