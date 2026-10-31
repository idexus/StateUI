// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;

/**
 * Android's chooser for what the user shares: words sent as plain text to the target the user picks. The chooser
 * says which target was picked and nothing of a cancel, so the host asks once the activity comes back whether one
 * was ({@link #takeChosen}).
 */
final class StateUIShare {
    private StateUIShare() {}

    private static final String CHOSEN = "stateui.android.SHARE_CHOSEN";
    private static boolean chosen;
    private static BroadcastReceiver receiver;

    /** Shows the chooser for {@code words} over {@code activity}. */
    static void offer(Activity activity, String words) {
        chosen = false;
        forget(activity);
        receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                chosen = true;
            }
        };
        IntentFilter filter = new IntentFilter(CHOSEN);
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            activity.registerReceiver(receiver, filter);
        }
        Intent told = new Intent(CHOSEN).setPackage(activity.getPackageName());
        PendingIntent pending = PendingIntent.getBroadcast(
                activity, 0, told, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_MUTABLE);
        Intent send = new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, words);
        activity.startActivity(Intent.createChooser(send, null, pending.getIntentSender()));
    }

    /** Whether the user picked a target since the chooser showed; the chooser forgotten. */
    static boolean takeChosen(Activity activity) {
        boolean picked = chosen;
        chosen = false;
        forget(activity);
        return picked;
    }

    private static void forget(Activity activity) {
        if (receiver == null) return;
        try {
            activity.unregisterReceiver(receiver);
        } catch (IllegalArgumentException alreadyGone) {
            // An activity made again holds no receiver of the last one's.
        }
        receiver = null;
    }
}
