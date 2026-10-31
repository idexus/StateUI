// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.app.Activity;
import android.os.Build;
import android.view.View;
import android.view.Window;

/** The activity's window beside the system's bars, as a test leaves it for the next one. */
public final class TestSystemBars {
    private TestSystemBars() {}

    /** Fits `activity`'s window inside the system's bars again after a test drew `root` edge to edge in it. */
    public static void fitted(Activity activity, View root) {
        root.setOnApplyWindowInsetsListener(null);
        Window window = activity.getWindow();
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(true);
        } else {
            window.getDecorView().setSystemUiVisibility(0);
        }
    }
}
