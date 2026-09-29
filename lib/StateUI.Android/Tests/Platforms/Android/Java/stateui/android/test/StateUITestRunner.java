// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

/**
 * Runs the host's Swift tests on the UI thread of the test APK's own process,
 * as {@code am instrument -w} asks, and hands back their report.
 */
public final class StateUITestRunner extends Instrumentation {
    /** The part of the suite asked for: the tests whose "Case.test" name holds it; empty for every test. */
    private String filter = "";

    @Override
    public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        if (arguments != null && arguments.getString("filter") != null) filter = arguments.getString("filter");
        start();
    }

    @Override
    public void onStart() {
        super.onStart();

        // The window the pages stand in, started as an application's activity is, before the tests take the thread.
        Intent window = new Intent(getTargetContext(), TestActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        final Activity activity = startActivitySync(window);

        // The suite runs one item in each message of the UI thread - a test, or a part of a long family - so no
        // message runs long, as a platform that ends an application whose UI thread stops answering requires.
        final String[][] items = new String[1][];
        runOnMainSync(() -> {
            System.loadLibrary("StateUIAndroidTests");
            items[0] = begin(getTargetContext(), activity, filter);
        });
        for (String item : items[0]) runOnMainSync(() -> run(item));
        final String[] report = new String[1];
        runOnMainSync(() -> report[0] = end());
        activity.finish();

        Bundle results = new Bundle();
        results.putString(REPORT_KEY_STREAMRESULT, report[0] + "\n");
        finish(Activity.RESULT_OK, results);
    }

    private static native String[] begin(Context context, Activity window, String filter);

    private static native void run(String item);

    private static native String end();
}
