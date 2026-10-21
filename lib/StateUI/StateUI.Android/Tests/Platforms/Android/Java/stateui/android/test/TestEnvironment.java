// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.animation.ValueAnimator;
import android.app.UiModeManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.os.Build;
import android.view.accessibility.AccessibilityManager;

/** What a test does to the host's watch on the environment: tells each of its listeners from a thread of its own. */
public final class TestEnvironment {
    private TestEnvironment() {}

    /**
     * Tells every listener in `watch` - what the host's environment watch answers - that what it hears changed, from
     * a thread of its own, as Android tells several, and waits until each was told.
     */
    public static void tellOffTheUIThread(Context context, Object[] watch) throws InterruptedException {
        Thread teller = new Thread(() -> {
            ((BroadcastReceiver) watch[0]).onReceive(context, new Intent(Intent.ACTION_TIME_CHANGED));
            if (watch[1] != null) ((ConnectivityManager.NetworkCallback) watch[1]).onLost(null);
            ((AccessibilityManager.TouchExplorationStateChangeListener) watch[2]).onTouchExplorationStateChanged(false);
            if (Build.VERSION.SDK_INT >= 33 && watch[3] != null) {
                ((ValueAnimator.DurationScaleChangeListener) watch[3]).onChanged(1f);
            }
            if (Build.VERSION.SDK_INT >= 34 && watch[4] != null) {
                ((UiModeManager.ContrastChangeListener) watch[4]).onContrastChanged(0f);
            }
        });
        teller.start();
        teller.join();
    }
}
