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

    /** The kept words of each name, in order; null where nothing is kept. */
    static String[] read(Context context, String[] names) {
        SharedPreferences preferences = preferences(context);
        String[] values = new String[names.length];
        for (int index = 0; index < names.length; index++) values[index] = preferences.getString(names[index], null);
        return values;
    }

    /** Keeps `value` under `name`. */
    static void write(Context context, String name, String value) {
        preferences(context).edit().putString(name, value).apply();
    }
}
