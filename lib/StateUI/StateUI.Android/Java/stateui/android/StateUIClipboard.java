// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;

/** The system's clipboard, as the application's acts write and read it: its words. */
final class StateUIClipboard {
    private StateUIClipboard() {}

    /** Puts `words` on the clipboard, in place of whatever it held. */
    static void write(Context context, String words) {
        ClipboardManager clipboard = context.getSystemService(ClipboardManager.class);
        if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("", words));
    }

    /** The words on the clipboard; null where it holds none. */
    static String read(Context context) {
        ClipboardManager clipboard = context.getSystemService(ClipboardManager.class);
        ClipData clip = clipboard == null ? null : clipboard.getPrimaryClip();
        if (clip == null || clip.getItemCount() == 0) return null;
        CharSequence words = clip.getItemAt(0).coerceToText(context);
        return words == null ? null : words.toString();
    }
}
