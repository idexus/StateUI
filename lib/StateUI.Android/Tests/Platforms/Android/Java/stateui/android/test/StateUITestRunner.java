// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.os.Bundle;

/**
 * Runs the host's Swift tests on the UI thread of the test APK's own process,
 * as {@code am instrument -w} asks, and hands back their report.
 */
public final class StateUITestRunner extends Instrumentation {
    @Override
    public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        start();
    }

    @Override
    public void onStart() {
        super.onStart();

        final String[] report = new String[1];
        runOnMainSync(() -> {
            System.loadLibrary("StateUIAndroidTests");
            report[0] = run(getTargetContext());
        });

        Bundle results = new Bundle();
        results.putString(REPORT_KEY_STREAMRESULT, report[0] + "\n");
        finish(Activity.RESULT_OK, results);
    }

    private static native String run(Context context);
}
