// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package com.stateui.gallery;

import android.content.BroadcastReceiver;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.BatteryManager;
import android.os.Build;

/** What the gallery's own acts and events ask of the device: its clipboard and its battery. */
final class GalleryDevice {
    private GalleryDevice() {}

    /** Puts `text` on the clipboard. */
    static void copy(Context context, String text) {
        context.getSystemService(ClipboardManager.class).setPrimaryClip(ClipData.newPlainText("StateUI Gallery", text));
    }

    /** The clipboard's text; empty where it holds none. */
    static String paste(Context context) {
        ClipData clip = context.getSystemService(ClipboardManager.class).getPrimaryClip();
        if (clip == null || clip.getItemCount() == 0) return "";
        CharSequence text = clip.getItemAt(0).coerceToText(context);
        return text == null ? "" : text.toString();
    }

    /** The battery's level, 0 to 1 - 0 where the device has none - and 1 where it charges, else 0. */
    static double[] battery(Context context) {
        return reading(context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED)));
    }

    /** Tells each change of the battery - the one standing first - until the receiver is unregistered. */
    static BroadcastReceiver watchBattery(Context context) {
        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                double[] battery = reading(intent);
                GalleryNatives.batteryChanged(battery[0], battery[1] != 0);
            }
        };
        IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(receiver, filter);
        }
        return receiver;
    }

    private static double[] reading(Intent status) {
        if (status == null) return new double[] {0, 0};
        int level = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        int scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
        int state = status.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
        boolean charging = state == BatteryManager.BATTERY_STATUS_CHARGING || state == BatteryManager.BATTERY_STATUS_FULL;
        return new double[] {level >= 0 && scale > 0 ? (double) level / scale : 0, charging ? 1 : 0};
    }
}
