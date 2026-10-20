// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.content.SharedPreferences;

/** The application's kept values, each as the words it was written in, in the platform's preferences. */
final class StateUIStore {
    private StateUIStore() {}

    private static SharedPreferences preferences(Context context) {
        return context.getSharedPreferences("stateui", Context.MODE_PRIVATE);
    }

    /** The words kept under `name`; null where nothing is. */
    static String read(Context context, String name) {
        return preferences(context).getString(name, null);
    }

    /** Keeps `value` under `name`. */
    static void write(Context context, String name, String value) {
        preferences(context).edit().putString(name, value).apply();
    }
}
