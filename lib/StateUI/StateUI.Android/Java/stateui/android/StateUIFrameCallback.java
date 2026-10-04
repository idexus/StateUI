// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.Choreographer;

/** The frame clock's frame: it runs in the display's frame, before the frame lays out and draws. */
final class StateUIFrameCallback implements Choreographer.FrameCallback {
    @Override
    public void doFrame(long time) {
        StateUIHost.frame(time);
    }
}
