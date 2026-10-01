// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.webview;

/**
 * What a web view tells its Swift control, by the number the control gave it: the web view's Android backend
 * registers these as it makes its first view.
 */
final class StateUIWebViewNatives {
    private StateUIWebViewNatives() {}

    /** A navigation started: why, as StateUI numbers it, and where it is going. */
    static native void navigating(long view, int cause, String address);

    /** A navigation ended: how and why, as StateUI numbers them, and where it went. */
    static native void navigated(long view, int result, int cause, String address);

    /** Whether there is a page behind and ahead, as the history now stands. */
    static native void history(long view, boolean back, boolean forward);

    /** The web process died, and the view was made again, blank. */
    static native void processGone(long view);

    /** The script waiting under `ticket` answered: its value as text, or null for none. */
    static native void answered(long ticket, String text);
}
