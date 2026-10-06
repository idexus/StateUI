// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipDescription;
import android.content.Context;
import android.content.ContextWrapper;
import android.net.Uri;
import android.view.DragAndDropPermissions;
import android.view.DragEvent;
import android.view.View;
import java.util.ArrayList;

/**
 * A view's drags, as Android's own drag and drop: a long press starts a drag carrying the view's words as plain text,
 * its shadow the view; a view that takes drops hears a drag of plain text - or of another application's documents -
 * come, stay, go and be let go. One drag listener a view tells the host each, by the view's number; the leave to read
 * a document dropped lasts while the application runs.
 */
final class StateUIDrags {
    private StateUIDrags() {}

    static final int STARTED = 0;
    static final int ENDED = 1;
    static final int OVER = 2;
    static final int LEFT = 3;
    static final int DROPPED = 4;

    /** The leave to read the documents dropped, kept while the application runs. */
    private static final ArrayList<DragAndDropPermissions> granted = new ArrayList<>();

    /**
     * The view's drag carries `words` - null where it cannot be dragged - and it takes words dropped where `takesWords`,
     * documents where `takesFiles`.
     */
    static void offer(View view, long number, String words, boolean takesWords, boolean takesFiles) {
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
        view.setOnDragListener(!source && !takesWords && !takesFiles ? null
            : (target, event) -> heard(target, number, source, takesWords, takesFiles, event));
    }

    /** Whether a drag holds documents: anything but plain text. */
    private static boolean documents(ClipDescription carried) {
        if (carried == null) return false;
        for (int index = 0; index < carried.getMimeTypeCount(); index++) {
            if (!ClipDescription.MIMETYPE_TEXT_PLAIN.equals(carried.getMimeType(index))) return true;
        }
        return false;
    }

    private static boolean heard(View view, long number, boolean source, boolean takesWords, boolean takesFiles,
                                 DragEvent event) {
        boolean takes = takesWords || takesFiles;
        boolean own = event.getLocalState() instanceof Long && (Long) event.getLocalState() == number;
        switch (event.getAction()) {
            case DragEvent.ACTION_DRAG_STARTED: {
                // The view hears the end of its own drag, takes a drag of plain text where it takes words, and of
                // documents where it takes files.
                ClipDescription carried = event.getClipDescription();
                return (source && own)
                    || (takesWords && carried != null && carried.hasMimeType(ClipDescription.MIMETYPE_TEXT_PLAIN))
                    || (takesFiles && documents(carried));
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
                if (takesFiles && documents(event.getClipDescription()) && carried != null) {
                    dropped(view, number, carried, event);
                    return true;
                }
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

    /** The documents a drop holds, told by their addresses and names once the leave to read them is asked for. */
    private static void dropped(View view, long number, ClipData carried, DragEvent event) {
        Activity activity = activity(view.getContext());
        if (activity != null) {
            DragAndDropPermissions permissions = activity.requestDragAndDropPermissions(event);
            if (permissions != null) granted.add(permissions);
        }
        ArrayList<String> addresses = new ArrayList<>();
        ArrayList<String> names = new ArrayList<>();
        for (int index = 0; index < carried.getItemCount(); index++) {
            Uri document = carried.getItemAt(index).getUri();
            if (document == null) continue;
            addresses.add(document.toString());
            names.add(StateUIFiles.name(view.getContext().getContentResolver(), document));
        }
        StateUIHost.filesDragged(number, addresses.toArray(new String[0]), names.toArray(new String[0]));
    }

    private static Activity activity(Context context) {
        while (context instanceof ContextWrapper && !(context instanceof Activity)) {
            context = ((ContextWrapper) context).getBaseContext();
        }
        return context instanceof Activity ? (Activity) context : null;
    }
}
