// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package com.stateui.gallery;

import android.content.BroadcastReceiver;
import android.os.Bundle;

import stateui.android.StateUIActivity;

// listing: InteropEventsSample.Android.java
/** The gallery's activity: the host's own, and the battery watched while it lives, for the gallery's own event. */
public final class GalleryActivity extends StateUIActivity {
    private BroadcastReceiver battery;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        battery = GalleryDevice.watchBattery(this);
    }

    @Override
    protected void onDestroy() {
        unregisterReceiver(battery);
        super.onDestroy();
    }
}
// listing: end
