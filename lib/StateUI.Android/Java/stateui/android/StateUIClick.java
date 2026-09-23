// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.View;

/** A click, forwarded to the Swift view it belongs to. */
final class StateUIClick implements View.OnClickListener {
    private final long view;

    StateUIClick(long view) {
        this.view = view;
    }

    @Override
    public void onClick(View clicked) {
        StateUIHost.clicked(view);
    }
}
