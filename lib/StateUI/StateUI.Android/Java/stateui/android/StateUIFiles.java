// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;

/**
 * The files the user opens and saves in the system's document picker, and what the system launches. Each answers
 * once, by its ticket: a picker with the documents' addresses and names, a save once its contents stand written; a
 * read with the document's bytes; a launch with whether an application took it. A document is read and written
 * beside the UI thread, and every answer reaches the host on it.
 */
final class StateUIFiles {
    private StateUIFiles() {}

    /** What a picker asked: its ticket, and what a save writes - null for an open. */
    private static final class Asked {
        final long ticket;
        final byte[] contents;

        Asked(long ticket, byte[] contents) {
            this.ticket = ticket;
            this.contents = contents;
        }
    }

    /** The pickers waiting for their result, by their request's code. */
    private static final HashMap<Integer, Asked> waiting = new HashMap<>();
    private static int nextRequest = 0x5F00;

    private static final Handler ui = new Handler(Looper.getMainLooper());

    /** Whether a picker and a launch are only held, never handed to the system: a test's. */
    private static boolean holds;
    private static Asked held;
    private static Intent heldIntent;
    private static final ArrayList<String> launched = new ArrayList<>();

    /** Asks the user for one document to open, or several, of the types the extensions name - any where none. */
    static void open(Context context, long ticket, String[] extensions, boolean several) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("*/*")
                .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, several);
        LinkedHashSet<String> types = new LinkedHashSet<>();
        for (String extension : extensions) types.add(type(extension));
        if (!types.isEmpty()) intent.putExtra(Intent.EXTRA_MIME_TYPES, types.toArray(new String[0]));
        ask(context, intent, new Asked(ticket, null));
    }

    /** Asks the user where to save `contents`, suggesting `name` - the platform's own where it is empty. */
    static void save(Context context, long ticket, String name, String extension, byte[] contents) {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType(type(extension));
        if (!name.isEmpty()) intent.putExtra(Intent.EXTRA_TITLE, name);
        ask(context, intent, new Asked(ticket, contents));
    }

    private static void ask(Context context, Intent intent, Asked asked) {
        if (holds) {
            held = asked;
            heldIntent = intent;
            return;
        }
        if (!(context instanceof Activity)) {
            answer(asked.ticket, new String[0], new String[0], "there is no activity to ask the user in");
            return;
        }
        Activity activity = (Activity) context;
        int request = nextRequest++;
        if (nextRequest > 0x5FFF) nextRequest = 0x5F00;
        waiting.put(request, asked);
        try {
            activity.startActivityForResult(intent, request);
        } catch (ActivityNotFoundException missing) {
            waiting.remove(request);
            answer(asked.ticket, new String[0], new String[0], "no application picks documents");
        }
    }

    /** The MIME type of the files ending in `extension`; any where none is known. */
    private static String type(String extension) {
        String type = extension == null ? null : MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
        return type == null ? "application/octet-stream" : type;
    }

    /** The activity's result came: whether it was a picker's, which is answered. */
    static boolean result(Context context, int request, int result, Intent data) {
        Asked asked = waiting.remove(request);
        if (asked == null) return false;
        ArrayList<Uri> chosen = new ArrayList<>();
        if (result == Activity.RESULT_OK && data != null) {
            ClipData several = data.getClipData();
            if (several != null) {
                for (int index = 0; index < several.getItemCount(); index++) chosen.add(several.getItemAt(index).getUri());
            } else if (data.getData() != null) {
                chosen.add(data.getData());
            }
        }
        chose(context, asked, chosen);
        return true;
    }

    /** The user chose `chosen` - none cancels: an open answers them, a save writes its contents to the first. */
    private static void chose(Context context, Asked asked, ArrayList<Uri> chosen) {
        ContentResolver resolver = context.getContentResolver();
        String[] addresses = new String[chosen.size()];
        String[] names = new String[chosen.size()];
        for (int index = 0; index < chosen.size(); index++) {
            addresses[index] = chosen.get(index).toString();
            names[index] = name(resolver, chosen.get(index));
        }
        if (asked.contents == null || chosen.isEmpty()) {
            answer(asked.ticket, addresses, names, null);
            return;
        }
        Uri place = chosen.get(0);
        new Thread(() -> {
            String failure = null;
            try (OutputStream stream = resolver.openOutputStream(place, "wt")) {
                if (stream == null) throw new java.io.IOException("the document cannot be written");
                stream.write(asked.contents);
            } catch (Exception failed) {
                failure = String.valueOf(failed.getMessage());
            }
            answer(asked.ticket, addresses, names, failure);
        }).start();
    }

    /** The name the document shows, its extension included. */
    private static String name(ContentResolver resolver, Uri document) {
        try (Cursor cursor = resolver.query(document, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst() && !cursor.isNull(0)) return cursor.getString(0);
        } catch (Exception unnamed) {
            // A document no provider names is named by its address.
        }
        String last = document.getLastPathSegment();
        return last == null ? "" : last;
    }

    private static void answer(long ticket, String[] addresses, String[] names, String failure) {
        ui.post(() -> StateUIHost.filesChosen(ticket, addresses, names, failure));
    }

    /** Reads the document at `address` whole, beside the UI thread. */
    static void read(Context context, long ticket, String address) {
        ContentResolver resolver = context.getContentResolver();
        new Thread(() -> {
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            String failure = null;
            try (InputStream stream = resolver.openInputStream(Uri.parse(address))) {
                if (stream == null) throw new java.io.IOException("the document cannot be read");
                byte[] run = new byte[64 * 1024];
                for (int count; (count = stream.read(run)) > 0; ) bytes.write(run, 0, count);
            } catch (Exception failed) {
                failure = String.valueOf(failed.getMessage());
            }
            byte[] read = bytes.toByteArray();
            String why = failure;
            ui.post(() -> StateUIHost.fileRead(ticket, read, why));
        }).start();
    }

    /**
     * Hands the document or the address to the application the system gives it - a document with leave to read it;
     * answers whether one took it.
     */
    static void launch(Context context, long ticket, String address, boolean document) {
        Uri uri = Uri.parse(address);
        boolean taken = uri.getScheme() != null;
        if (taken) launched.add(document ? name(context.getContentResolver(), uri) : address);
        if (taken && !holds) {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            if (document) {
                String type = context.getContentResolver().getType(uri);
                intent.setDataAndType(uri, type == null ? "*/*" : type).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } else {
                intent.setData(uri);
            }
            if (!(context instanceof Activity)) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            try {
                context.startActivity(intent);
            } catch (ActivityNotFoundException | SecurityException refused) {
                taken = false;
            }
        }
        boolean answer = taken;
        ui.post(() -> StateUIHost.launched(ticket, answer));
    }

    /** Holds every picker and launch from now on, as a test does, forgetting what was held or launched. */
    static void holdForTesting() {
        holds = true;
        held = null;
        launched.clear();
    }

    /** The picker held: 0 one that opens, 1 one that saves, -1 none. */
    static int heldForTesting() {
        if (held == null) return -1;
        return held.contents == null ? 0 : 1;
    }

    /** The intent of the picker held; null where none is. */
    static Intent heldIntentForTesting() {
        return held == null ? null : heldIntent;
    }

    /** Answers the picker held as the user does, by the documents at `addresses` - none cancels it. */
    static boolean answerForTesting(Context context, String[] addresses) {
        Asked asked = held;
        if (asked == null) return false;
        held = null;
        ArrayList<Uri> chosen = new ArrayList<>();
        for (String address : addresses) chosen.add(Uri.parse(address));
        chose(context, asked, chosen);
        return true;
    }

    /**
     * What was handed to the system to launch, in order, since the test held launches: an address as written, a
     * document by its name.
     */
    static String[] launchedForTesting() {
        return launched.toArray(new String[0]);
    }
}
