// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.View;
import android.view.ViewTreeObserver;

/**
 * The root's drawing: before each frame is drawn, what reads a frame says where it stands, and what that changes is
 * laid out again at once - a room Android alone narrowed places its layout in the frame that measured it, not a
 * display frame later.
 */
final class StateUIDrawing implements ViewTreeObserver.OnPreDrawListener {
    private final View root;

    private StateUIDrawing(View root) {
        this.root = root;
    }

    /** Follows the drawing of `root`'s window. */
    static void follow(View root) {
        root.getViewTreeObserver().addOnPreDrawListener(new StateUIDrawing(root));
    }

    @Override
    public boolean onPreDraw() {
        if (!StateUIHost.reportLaidOut() || !root.isLayoutRequested()) return true;
        root.measure(
            View.MeasureSpec.makeMeasureSpec(root.getWidth(), View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(root.getHeight(), View.MeasureSpec.EXACTLY));
        root.layout(root.getLeft(), root.getTop(), root.getRight(), root.getBottom());
        return true;
    }
}
