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

    /** One of the words assistive technology meets of the view - "label", "hint", "id", "kind" or "value" - or none. */
    public static String word(View view, String name) {
        AccessibilityNodeInfo info = view.createAccessibilityNodeInfo();
        CharSequence word;
        switch (name) {
            case "label": word = view.getContentDescription(); break;
            case "hint": word = info.getHintText(); break;
            case "id": word = info.getViewIdResourceName(); break;
            case "kind": word = info.getClassName(); break;
            case "value": word = Build.VERSION.SDK_INT >= 30 ? view.getStateDescription() : null; break;
            default: word = null; break;
        }
        return word == null ? null : word.toString();
    }

    /** Performs the action of the view's node named `label`, as TalkBack does: whether the view took it. */
    public static boolean perform(View view, String label) {
        for (AccessibilityNodeInfo.AccessibilityAction action : view.createAccessibilityNodeInfo().getActionList()) {
            CharSequence named = action.getLabel();
            if (named != null && label.contentEquals(named)) return view.performAccessibilityAction(action.getId(), null);
        }
        return false;
    }

    /** How many items the view's node tells TalkBack the user may choose, as `CollectionInfo` numbers it; -1 for none. */
    public static int selectionMode(View view) {
        AccessibilityNodeInfo.CollectionInfo collection = view.createAccessibilityNodeInfo().getCollectionInfo();
        return collection == null ? -1 : collection.getSelectionMode();
    }

    /** Steps the view up or down as TalkBack steps a slider, where its node offers the step: whether it took it. */
    public static boolean step(View view, boolean up) {
        AccessibilityNodeInfo.AccessibilityAction wanted = up
                ? AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD
                : AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD;
        if (!view.createAccessibilityNodeInfo().getActionList().contains(wanted)) return false;
        return view.performAccessibilityAction(wanted.getId(), null);
    }

    /**
     * What TalkBack and a test find of the view: "id", "label" and "hint" and their words, "heading", and "met",
     * "hidden" or "hidden with children" - separated by ", ", none said as nothing. A view in no window makes
     * a node without its own words, so all but the id and the hint are read from the view, those from its node.
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
