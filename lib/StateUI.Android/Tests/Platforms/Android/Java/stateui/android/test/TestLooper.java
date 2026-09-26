// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.os.Handler;
import android.os.Looper;

/**
 * Runs the UI thread's own messages for a moment from inside a test the thread is running: what a web page's client,
 * a choreographer's frame or a posted callback tells arrives as it does in an application, whose thread returns to
 * its looper between turns.
 */
public final class TestLooper {
    /** Ends the moment: thrown from a message posted for its end, out of the looper and caught here. */
    private static final class Over extends RuntimeException {}

    private TestLooper() {}

    /** Runs the thread's messages for `millis` milliseconds, then returns. */
    public static void run(long millis) {
        new Handler(Looper.myLooper()).postDelayed(() -> { throw new Over(); }, millis);
        try {
            Looper.loop();
        } catch (Over over) {
            // The moment is over; the test goes on.
        }
    }
}
