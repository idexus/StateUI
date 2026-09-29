// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.text.InputFilter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import java.util.ArrayList;

/**
 * The questions the application asks the user, as the platform's own dialogs. Each answers once, by its
 * ticket: whether it was accepted, and the words chosen or typed - a dialog dismissed any other way is
 * not accepted.
 */
final class StateUIDialogs {
    private StateUIDialogs() {}

    /** The dialogs showing, the last on top, each with what it asks. */
    private static final ArrayList<Shown> showing = new ArrayList<>();

    /** A dialog showing: its answer, its words, the captions of its list, and the field it asks words in. */
    private static final class Shown {
        final AlertDialog dialog;
        final Answer answer;
        final String title;
        final String message;
        final String[] choices;
        final EditText field;

        Shown(AlertDialog dialog, Answer answer, String title, String message, String[] choices, EditText field) {
            this.dialog = dialog;
            this.answer = answer;
            this.title = title;
            this.message = message;
            this.choices = choices;
            this.field = field;
        }
    }

    /** Keeps `dialog` among those showing until it goes, then shows it. */
    private static void show(
            AlertDialog dialog, Answer answer, String title, String message, String[] choices, EditText field) {
        Shown shown = new Shown(dialog, answer, title, message, choices, field);
        showing.add(shown);
        dialog.show();
    }

    /** The question the user meets: the top dialog not answered yet - one answered goes a message later. */
    private static Shown top() {
        for (int index = showing.size() - 1; index >= 0; index--) {
            if (!showing.get(index).answer.given) return showing.get(index);
        }
        return null;
    }

    /**
     * The question on top, as the user meets it: its title, its message, the words its field holds or null for
     * none, then its buttons' captions and its list's; null where none shows.
     */
    static String[] question() {
        Shown top = top();
        if (top == null) return null;
        ArrayList<String> words = new ArrayList<>();
        words.add(top.title == null ? "" : top.title);
        words.add(top.message == null ? "" : top.message);
        words.add(top.field == null ? null : top.field.getText().toString());
        for (int which : new int[] {DialogInterface.BUTTON_POSITIVE, DialogInterface.BUTTON_NEGATIVE,
                DialogInterface.BUTTON_NEUTRAL}) {
            Button button = top.dialog.getButton(which);
            if (button != null && button.getVisibility() == android.view.View.VISIBLE) {
                words.add(button.getText().toString());
            }
        }
        if (top.choices != null) for (String choice : top.choices) words.add(choice);
        return words.toArray(new String[0]);
    }

    /**
     * Answers the question on top as the user does: its field first given `words` where it has one, then its button
     * or its list's item of `caption` pressed; whether one was.
     */
    static boolean answer(String caption, String words) {
        Shown top = top();
        if (top == null) return false;
        if (words != null && top.field != null) top.field.setText(words);
        for (int which : new int[] {DialogInterface.BUTTON_POSITIVE, DialogInterface.BUTTON_NEGATIVE,
                DialogInterface.BUTTON_NEUTRAL}) {
            Button button = top.dialog.getButton(which);
            if (button != null && caption.equals(button.getText().toString())) return button.performClick();
        }
        if (top.choices != null) {
            for (int index = 0; index < top.choices.length; index++) {
                if (caption.equals(top.choices[index])) {
                    return top.dialog.getListView().performItemClick(null, index, index);
                }
            }
        }
        return false;
    }

    /** Takes every dialog showing away, each answered as dismissed: the window they stand over goes. */
    static void dismissAll() {
        // A dialog hears its dismissal in a later message: the list is emptied first, the dialogs dismissed after.
        ArrayList<Shown> all = new ArrayList<>(showing);
        showing.clear();
        for (int index = all.size() - 1; index >= 0; index--) all.get(index).dialog.dismiss();
    }

    /** Tells the user something, with one button. */
    static void alert(Context context, long ticket, String title, String message, String button) {
        Answer answer = new Answer(ticket);
        AlertDialog dialog = new AlertDialog.Builder(context)
                .setTitle(title)
                .setMessage(message)
                .setPositiveButton(button, (shown, which) -> answer.give(true, null))
                .create();
        answer.onDismissOf(dialog);
        show(dialog, answer, title, message, null, null);
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
        show(dialog, answer, title, message, null, null);
    }

    /** Offers a list of choices, the destructive one last; the answer is the caption pressed, the cancel's too. */
    static void chooseAction(Context context, long ticket, String title, String cancel, String destructive,
                             String[] choices) {
        Answer answer = new Answer(ticket);
        String[] shown = destructive == null ? choices : append(choices, destructive);
        AlertDialog.Builder builder = new AlertDialog.Builder(context)
                .setItems(shown, (dialog, which) -> answer.give(true, shown[which]));
        if (title != null && !title.isEmpty()) builder.setTitle(title);
        if (cancel != null) builder.setNegativeButton(cancel, (dialog, which) -> answer.give(true, cancel));
        AlertDialog dialog = builder.create();
        answer.onDismissOf(dialog);
        show(dialog, answer, title, null, shown, null);
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
        show(dialog, answer, title, message, null, field);
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
            dialog.setOnDismissListener(dismissed -> {
                showing.removeIf(shown -> shown.dialog == dialog);
                give(false, null);
            });
        }
    }
}
