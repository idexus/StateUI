// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.ClipData;
import android.content.ClipDescription;
import android.view.DragEvent;
import android.view.View;

/**
 * A view's drag between views, as Android's own drag and drop: a long press starts a drag carrying the view's words
 * as plain text, its shadow the view; a view that takes drops hears a drag of plain text come, stay, go and be let
 * go. One drag listener a view tells the host each, by the view's number.
 */
final class StateUIDrags {
    private StateUIDrags() {}

    static final int STARTED = 0;
    static final int ENDED = 1;
    static final int OVER = 2;
    static final int LEFT = 3;
    static final int DROPPED = 4;

    /** The view's drag carries `words` - null where it cannot be dragged - and it takes drops where `takesDrops`. */
    static void offer(View view, long number, String words, boolean takesDrops) {
        if (words != null) {
            view.setOnLongClickListener(held -> {
                ClipData carried = ClipData.newPlainText("StateUI", words);
                boolean started = held.startDragAndDrop(carried, new View.DragShadowBuilder(held), number, 0);
                if (started) StateUIHost.dragHeard(number, STARTED, null);
                return started;
            });
        } else {
            view.setOnLongClickListener(null);
            view.setLongClickable(false);
        }
        boolean source = words != null;
        view.setOnDragListener(!source && !takesDrops ? null : (target, event) -> heard(number, source, takesDrops, event));
    }

    private static boolean heard(long number, boolean source, boolean takes, DragEvent event) {
        boolean own = event.getLocalState() instanceof Long && (Long) event.getLocalState() == number;
        switch (event.getAction()) {
            case DragEvent.ACTION_DRAG_STARTED: {
                // The view hears the end of its own drag, and takes a drag of plain text where it takes drops.
                ClipDescription carried = event.getClipDescription();
                return (source && own) || (takes && carried != null && carried.hasMimeType(ClipDescription.MIMETYPE_TEXT_PLAIN));
            }
            case DragEvent.ACTION_DRAG_ENTERED:
            case DragEvent.ACTION_DRAG_LOCATION:
                if (takes) StateUIHost.dragHeard(number, OVER, null);
                return true;
            case DragEvent.ACTION_DRAG_EXITED:
                if (takes) StateUIHost.dragHeard(number, LEFT, null);
                return true;
            case DragEvent.ACTION_DROP: {
                if (!takes) return false;
                ClipData carried = event.getClipData();
                CharSequence words = carried != null && carried.getItemCount() > 0 ? carried.getItemAt(0).getText() : null;
                StateUIHost.dragHeard(number, DROPPED, words == null ? "" : words.toString());
                return true;
            }
            case DragEvent.ACTION_DRAG_ENDED:
                if (source && own) StateUIHost.dragHeard(number, ENDED, null);
                return true;
            default:
                return false;
        }
    }
}
