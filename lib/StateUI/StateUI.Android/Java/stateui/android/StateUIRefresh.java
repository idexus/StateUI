// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

/**
 * A scroller's or a list's pull to refresh: AndroidX's swipe to refresh around it, offered while it is enabled. A pull
 * is told to the host as the view `view`'s, and its spinner goes at once where the host says nothing will end it.
 */
final class StateUIRefresh extends SwipeRefreshLayout {
    private final long view;

    StateUIRefresh(Context context, long view) {
        super(context);
        this.view = view;
        setEnabled(false);
        setOnRefreshListener(this::pulled);
    }

    /** The user pulled far enough: the spinner shows, and the host hears it. */
    void pulled() {
        if (!StateUIHost.refreshPulled(view)) setRefreshing(false);
    }
}
