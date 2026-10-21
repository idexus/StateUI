// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.animation.ValueAnimator;
import android.app.Activity;
import android.app.ActivityManager;
import android.app.UiModeManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
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
import android.provider.Settings;
import android.text.TextUtils;
import android.text.format.DateFormat;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Display;
import android.view.View;
import android.view.accessibility.AccessibilityManager;
import android.view.inputmethod.InputMethodManager;
import java.util.Calendar;
import java.util.Locale;
import java.util.TimeZone;

/** What the device, its display and the application are, each read in one call for the Swift host. */
final class StateUIEnvironment {
    private StateUIEnvironment() {}

    /**
     * The model, the maker, the device's name - the one its user gave it in Settings, else the model's code name -
     * Android's version, and "1" on an emulator.
     */
    static String[] device(Context context) {
        boolean emulator = Build.FINGERPRINT.startsWith("generic") || Build.HARDWARE.contains("ranchu")
                || Build.HARDWARE.contains("goldfish") || Build.PRODUCT.contains("sdk");
        String named = Settings.Global.getString(context.getContentResolver(), Settings.Global.DEVICE_NAME);
        return new String[] { Build.MODEL, Build.MANUFACTURER, named == null || named.isEmpty() ? Build.DEVICE : named,
                Build.VERSION.RELEASE, emulator ? "1" : "0" };
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

    /** Pixels a density-independent pixel, as `context`'s resources stand now. */
    static float density(Context context) {
        return context.getResources().getDisplayMetrics().density;
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
     * The language, the region, the locale's tag, the zone, "1" for a 24-hour clock, the week's first day from
     * Sunday's 0, "1" for metric units, and "1" where the language is written right to left.
     */
    static String[] locale(Context context) {
        Locale locale = context.getResources().getConfiguration().getLocales().get(0);
        boolean metric = LocaleData.getMeasurementSystem(ULocale.forLocale(locale)) != LocaleData.MeasurementSystem.US;
        boolean rightToLeft = TextUtils.getLayoutDirectionFromLocale(locale) == View.LAYOUT_DIRECTION_RTL;
        return new String[] {
            locale.getLanguage(), locale.getCountry(), locale.toLanguageTag(), TimeZone.getDefault().getID(),
            DateFormat.is24HourFormat(context) ? "1" : "0",
            Integer.toString(Calendar.getInstance(locale).getFirstDayOfWeek() - Calendar.SUNDAY),
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
     * The user's accessibility settings: 1 where the system's animations are off, 1 where the user asked for more
     * contrast - which Android says from 14 - 1 while TalkBack explores by touch, and the scale of the system's
     * words.
     */
    static float[] accessibility(Context context) {
        float contrast = 0;
        if (Build.VERSION.SDK_INT >= 34) {
            UiModeManager mode = context.getSystemService(UiModeManager.class);
            contrast = mode != null && mode.getContrast() > 0 ? 1 : 0;
        }
        AccessibilityManager manager = context.getSystemService(AccessibilityManager.class);
        return new float[] {
            ValueAnimator.areAnimatorsEnabled() ? 0 : 1, contrast,
            manager != null && manager.isTouchExplorationEnabled() ? 1 : 0,
            context.getResources().getConfiguration().fontScale,
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
     * Tells the Swift host whenever the zone, the clock, the battery, its saver, the network, TalkBack, the
     * animations or the contrast changes, until {@link #unwatch} is handed what this answers.
     */
    static Object[] watch(Context context) {
        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context sender, Intent intent) {
                changed();
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
                changed();
            }

            @Override
            public void onLost(Network lost) {
                changed();
            }
        };
        ConnectivityManager manager = context.getSystemService(ConnectivityManager.class);
        try {
            manager.registerDefaultNetworkCallback(network, new Handler(Looper.getMainLooper()));
        } catch (SecurityException notAllowed) {
            network = null;
        }

        AccessibilityManager.TouchExplorationStateChangeListener reader = on -> changed();
        AccessibilityManager accessibility = context.getSystemService(AccessibilityManager.class);
        if (accessibility != null) accessibility.addTouchExplorationStateChangeListener(reader);
        Object animations = null;
        if (Build.VERSION.SDK_INT >= 33) {
            ValueAnimator.DurationScaleChangeListener scale = changed -> changed();
            ValueAnimator.registerDurationScaleChangeListener(scale);
            animations = scale;
        }
        Object contrast = null;
        if (Build.VERSION.SDK_INT >= 34) {
            UiModeManager.ContrastChangeListener changed = level -> changed();
            context.getSystemService(UiModeManager.class).addContrastChangeListener(context.getMainExecutor(), changed);
            contrast = changed;
        }
        return new Object[] { receiver, network, reader, animations, contrast };
    }

    /** The UI thread's queue, which a change told on another thread is handed to. */
    private static final Handler uiThread = new Handler(Looper.getMainLooper());

    /** Tells the Swift host the environment changed, on the UI thread whichever thread Android told it on. */
    private static void changed() {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            StateUIHost.environmentChanged();
        } else {
            uiThread.post(StateUIHost::environmentChanged);
        }
    }

    /** Stops what {@link #watch} started. */
    static void unwatch(Context context, Object[] watch) {
        context.unregisterReceiver((BroadcastReceiver) watch[0]);
        if (watch[1] != null) {
            context.getSystemService(ConnectivityManager.class)
                    .unregisterNetworkCallback((ConnectivityManager.NetworkCallback) watch[1]);
        }
        AccessibilityManager accessibility = context.getSystemService(AccessibilityManager.class);
        if (accessibility != null) {
            accessibility.removeTouchExplorationStateChangeListener(
                    (AccessibilityManager.TouchExplorationStateChangeListener) watch[2]);
        }
        if (Build.VERSION.SDK_INT >= 33 && watch[3] != null) {
            ValueAnimator.unregisterDurationScaleChangeListener((ValueAnimator.DurationScaleChangeListener) watch[3]);
        }
        if (Build.VERSION.SDK_INT >= 34 && watch[4] != null) {
            context.getSystemService(UiModeManager.class)
                    .removeContrastChangeListener((UiModeManager.ContrastChangeListener) watch[4]);
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

    /**
     * How far `zone` - the local one for null - is from UTC at noon of a day - now where year is 0 - in minutes;
     * Integer.MIN_VALUE for a zone the platform does not know, which TimeZone would read as GMT.
     */
    static int utcOffset(String zone, int year, int month, int day) {
        TimeZone timeZone = zone == null ? TimeZone.getDefault() : TimeZone.getTimeZone(zone);
        if (zone != null && !timeZone.getID().equals(zone)) return Integer.MIN_VALUE;
        Calendar noon = Calendar.getInstance(timeZone);
        if (year != 0) noon.set(year, month - 1, day, 12, 0, 0);
        return timeZone.getOffset(noon.getTimeInMillis()) / 60000;
    }

    /** The theme's accent, as ARGB: from Android 12 the color the system draws from the wallpaper. */
    static int accent(Context context) {
        TypedValue value = new TypedValue();
        if (!context.getTheme().resolveAttribute(android.R.attr.colorAccent, value, true)) return 0xFF0A84FF;
        return value.resourceId != 0 ? context.getColor(value.resourceId) : value.data;
    }

    /** Whether the application's night mode was given back to the system as this process began. */
    private static boolean followsSystem;

    /**
     * Gives the application's night mode back to the system once a process, as it begins: the system keeps the
     * mode an application set, and an application holds a theme only while it says so.
     */
    static void followSystemOnce(Context context) {
        if (followsSystem) return;
        followsSystem = true;
        useNightMode(context, 0);
    }

    /**
     * Shows the application in a theme - 1 light, 2 dark, 0 the system's - as its own night mode, which every
     * activity of it takes; from Android 12, before which an application shows the system's.
     */
    static void useNightMode(Context context, int scheme) {
        if (Build.VERSION.SDK_INT < 31) return;
        UiModeManager modes = context.getSystemService(UiModeManager.class);
        if (modes == null) return;
        modes.setApplicationNightMode(scheme == 2 ? UiModeManager.MODE_NIGHT_YES
            : scheme == 1 ? UiModeManager.MODE_NIGHT_NO : UiModeManager.MODE_NIGHT_AUTO);
    }

    /**
     * Paints the activity's window behind its pages in `argb`, or gives it the theme's own back where `written` is
     * false. A context that is no activity takes none.
     */
    static void windowBackground(Context context, int argb, boolean written) {
        if (!(context instanceof Activity)) return;
        Activity activity = (Activity) context;
        if (written) {
            activity.getWindow().setBackgroundDrawable(new ColorDrawable(argb));
            return;
        }
        TypedValue value = new TypedValue();
        boolean found = activity.getTheme().resolveAttribute(android.R.attr.windowBackground, value, true);
        if (found && value.resourceId != 0) activity.getWindow().setBackgroundDrawableResource(value.resourceId);
        else activity.getWindow().setBackgroundDrawable(null);
    }

    /** The plain color the activity's window shows behind its pages, as ARGB; Long.MIN_VALUE where it shows none. */
    static long windowBackground(Activity activity) {
        Drawable drawable = activity.getWindow().getDecorView().getBackground();
        return drawable instanceof ColorDrawable ? ((ColorDrawable) drawable).getColor() & 0xFFFFFFFFL : Long.MIN_VALUE;
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
