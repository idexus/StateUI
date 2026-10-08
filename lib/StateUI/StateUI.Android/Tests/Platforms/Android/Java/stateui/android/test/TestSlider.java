// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.os.Bundle;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.SeekBar;

/** A slider moved as a test moves it. */
public final class TestSlider {
    private TestSlider() {}

    /**
     * Moves the thumb to `progress` as TalkBack's user moves it: the slider's own action setting its progress, which
     * it says came from the user.
     */
    public static boolean slide(SeekBar bar, int progress) {
        Bundle arguments = new Bundle();
        arguments.putFloat(AccessibilityNodeInfo.ACTION_ARGUMENT_PROGRESS_VALUE, progress);
        return bar.performAccessibilityAction(
                AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_PROGRESS.getId(), arguments);
    }
}
