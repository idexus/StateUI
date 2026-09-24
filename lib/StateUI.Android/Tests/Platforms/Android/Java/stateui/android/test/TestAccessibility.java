// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.os.Build;
import android.view.View;
import android.view.accessibility.AccessibilityNodeInfo;
import java.util.ArrayList;
import java.util.List;

/** What assistive technology meets of a view, read back as words - what a test of the host's accessibility asks. */
public final class TestAccessibility {
    private TestAccessibility() {}

    /**
     * What TalkBack and a test find of the view: "id", "label" and "hint" and their words, "heading", and "met",
     * "hidden" or "hidden with children" - separated by ", ", none said as nothing. A view in no window makes
     * a node without its own words, so the label and the heading are read from the view, the rest from its node.
     */
    public static String describe(View view) {
        AccessibilityNodeInfo info = view.createAccessibilityNodeInfo();
        List<String> words = new ArrayList<>();
        if (info.getViewIdResourceName() != null) words.add("id " + info.getViewIdResourceName());
        if (view.getContentDescription() != null) words.add("label " + view.getContentDescription());
        if (info.getHintText() != null) words.add("hint " + info.getHintText());
        if (Build.VERSION.SDK_INT >= 28 && view.isAccessibilityHeading()) words.add("heading");
        switch (view.getImportantForAccessibility()) {
            case View.IMPORTANT_FOR_ACCESSIBILITY_YES: words.add("met"); break;
            case View.IMPORTANT_FOR_ACCESSIBILITY_NO: words.add("hidden"); break;
            case View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS: words.add("hidden with children"); break;
            default: break;
        }
        return String.join(", ", words);
    }
}
