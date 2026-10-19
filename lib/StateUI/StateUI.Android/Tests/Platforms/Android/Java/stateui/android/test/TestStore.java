// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.content.Context;

/** What a test does to the application's kept values: forgets them all, before a case writes its own. */
public final class TestStore {
    private TestStore() {}

    /** Forgets every value kept in the preferences the host keeps them in, at once. */
    public static void forget(Context context) {
        context.getSharedPreferences("stateui", Context.MODE_PRIVATE).edit().clear().commit();
    }
}
