// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.AlertDialog;
import android.content.Context;
import android.text.InputFilter;
import android.widget.EditText;
import android.widget.FrameLayout;

/**
 * The questions the application asks the user, as the platform's own dialogs. Each answers once, by its
 * ticket: whether it was accepted, and the words chosen or typed - a dialog dismissed any other way is
 * not accepted.
 */
final class StateUIDialogs {
    private StateUIDialogs() {}

    /** Tells the user something, with one button. */
    static void alert(Context context, long ticket, String title, String message, String button) {
        Answer answer = new Answer(ticket);
        AlertDialog dialog = new AlertDialog.Builder(context)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton(button, (shown, which) -> answer.give(true, null))
                .create();
        answer.onDismissOf(dialog);
        dialog.show();
    }

    /** Asks yes or no. */
    static void confirm(Context context, long ticket, String title, String message, String accept, String cancel) {
        Answer answer = new Answer(ticket);
        AlertDialog dialog = new AlertDialog.Builder(context)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton(accept, (shown, which) -> answer.give(true, null))
                .setNegativeButton(cancel, (shown, which) -> answer.give(false, null))
                .create();
        answer.onDismissOf(dialog);
        dialog.show();
    }

    /** Offers a list of choices, the destructive one last; the answer is the caption pressed. */
    static void chooseAction(Context context, long ticket, String title, String cancel, String destructive,
                             String[] choices) {
        Answer answer = new Answer(ticket);
        String[] shown = destructive == null ? choices : append(choices, destructive);
        AlertDialog.Builder builder = new AlertDialog.Builder(context)
                .setItems(shown, (dialog, which) -> answer.give(true, shown[which]));
        if (title != null && !title.isEmpty()) builder.setTitle(title);
        if (cancel != null) builder.setNegativeButton(cancel, (dialog, which) -> answer.give(false, null));
        AlertDialog dialog = builder.create();
        answer.onDismissOf(dialog);
        dialog.show();
    }

    /** Asks for words; the answer is what was typed, or none where it was cancelled. */
    static void prompt(Context context, long ticket, String title, String message, String accept, String cancel,
                       String placeholder, int maximumLength, int inputType, String initial) {
        Answer answer = new Answer(ticket);
        EditText field = new EditText(context);
        field.setInputType(inputType);
        field.setSingleLine(true);
        field.setText(initial);
        field.setSelection(initial.length());
        if (placeholder != null) field.setHint(placeholder);
        if (maximumLength >= 0) field.setFilters(new InputFilter[] {new InputFilter.LengthFilter(maximumLength)});
        FrameLayout room = new FrameLayout(context);
        int side = Math.round(20 * context.getResources().getDisplayMetrics().density);
        room.setPadding(side, 0, side, 0);
        room.addView(field);

        AlertDialog dialog = new AlertDialog.Builder(context)
                .setTitle(title)
                .setMessage(message)
                .setView(room)
                .setPositiveButton(accept, (shown, which) -> answer.give(true, field.getText().toString()))
                .setNegativeButton(cancel, (shown, which) -> answer.give(false, null))
                .create();
        answer.onDismissOf(dialog);
        dialog.show();
        field.requestFocus();
    }

    private static String[] append(String[] words, String last) {
        String[] all = new String[words.length + 1];
        System.arraycopy(words, 0, all, 0, words.length);
        all[words.length] = last;
        return all;
    }

    /** One dialog's answer, given once: a button's, or the dismissal's when no button answered. */
    private static final class Answer {
        private final long ticket;
        private boolean given;

        Answer(long ticket) {
            this.ticket = ticket;
        }

        void give(boolean accepted, String words) {
            if (given) return;
            given = true;
            StateUIHost.answered(ticket, accepted, words);
        }

        void onDismissOf(AlertDialog dialog) {
            dialog.setOnDismissListener(dismissed -> give(false, null));
        }
    }
}
