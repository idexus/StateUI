// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.view.View;
import android.view.ViewGroup;
import android.widget.PopupWindow;

/**
 * A view's popover: Android's popup window, drawn as the theme draws one, holding the popover's view below its
 * anchor - above it where there is no room below. A dismissal the host did not ask for - a touch beside it, Back -
 * is told to the host as the closing of the view `view`.
 */
final class StateUIPopover extends PopupWindow implements PopupWindow.OnDismissListener {
    private final long view;
    private boolean wanted;
    private boolean closing;

    StateUIPopover(View content, long view) {
        super(content.getContext());
        this.view = view;
        setContentView(content);
        setWidth(ViewGroup.LayoutParams.WRAP_CONTENT);
        setHeight(ViewGroup.LayoutParams.WRAP_CONTENT);
        setFocusable(true);
        setOnDismissListener(this);
    }

    /** Shows the popover by `anchor`, once the anchor stands in a window. */
    void show(View anchor) {
        wanted = true;
        if (isShowing()) return;
        if (anchor.isAttachedToWindow()) {
            showAsDropDown(anchor);
            return;
        }
        anchor.addOnAttachStateChangeListener(new View.OnAttachStateChangeListener() {
            @Override
            public void onViewAttachedToWindow(View attached) {
                attached.removeOnAttachStateChangeListener(this);
                attached.post(() -> {
                    if (wanted && !isShowing() && attached.isAttachedToWindow()) showAsDropDown(attached);
                });
            }

            @Override
            public void onViewDetachedFromWindow(View detached) {}
        });
    }

    /** Takes the popover away as the host asks: nobody hears it. */
    void close() {
        wanted = false;
        closing = true;
        dismiss();
        closing = false;
    }

    @Override
    public void onDismiss() {
        if (closing) return;
        wanted = false;
        StateUIHost.closed(view);
    }
}
