// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.inputmethod.BaseInputConnection;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import java.util.ArrayList;

/**
 * The questions the application asks the user, as the platform's own dialogs. Each answers once, by its
 * ticket: whether it was accepted and the words typed, or the place of the action chosen - a dialog dismissed
 * any other way is not accepted.
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

    /** The input type of the question on top's field: what its keyboard offers; -1 where it asks no words. */
    static int fieldInputType() {
        Shown top = top();
        return top == null || top.field == null ? -1 : top.field.getInputType();
    }

    /**
     * Answers the question on top as the user does: its field first given `words` where it has one, then its
     * accepting button pressed for `ACCEPT`, its cancel for `CANCEL`, else its list's action at `place`; whether one
     * was.
     */
    static boolean answer(int role, int place, String words) {
        Shown top = top();
        if (top == null) return false;
        if (words != null && top.field != null) top.field.setText(words);
        if (role == ACCEPT || role == CANCEL) {
            Button button = top.dialog.getButton(
                    role == ACCEPT ? DialogInterface.BUTTON_POSITIVE : DialogInterface.BUTTON_NEGATIVE);
            return button != null && button.performClick();
        }
        if (top.choices == null || place < 0 || place >= top.choices.length) return false;
        return top.dialog.getListView().performItemClick(null, place, place);
    }

    /** What a press answers: the accepting button, the cancel, an action of a list. */
    // Swift: AndroidAnswer
    static final int ACCEPT = 0, CANCEL = 1, ACTION = 2;

    /** Takes every dialog showing away, each answered as dismissed: the window they stand over goes. */
    static void dismissAll() {
        // A dialog hears its dismissal in a later message: the list is emptied first, the dialogs dismissed after.
        ArrayList<Shown> all = new ArrayList<>(showing);
        showing.clear();
        for (int index = all.size() - 1; index >= 0; index--) all.get(index).dialog.dismiss();
    }

    /**
     * Takes every dialog showing away unanswered: the activity goes, to be made again, and the next one asks each
     * question again - the process's acts wait for it.
     */
    static void leaveAll() {
        ArrayList<Shown> all = new ArrayList<>(showing);
        showing.clear();
        for (int index = all.size() - 1; index >= 0; index--) {
            all.get(index).answer.given = true;
            all.get(index).dialog.dismiss();
        }
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

    /** Offers a list of actions in order, and its cancel; the answer is the place of the action chosen. */
    static void chooseAction(Context context, long ticket, String title, String[] choices, String cancel) {
        Answer answer = new Answer(ticket);
        AlertDialog.Builder builder = new AlertDialog.Builder(context)
                .setItems(choices, (dialog, which) -> answer.choose(which))
                .setNegativeButton(cancel, (dialog, which) -> answer.give(false, null));
        if (title != null && !title.isEmpty()) builder.setTitle(title);
        AlertDialog dialog = builder.create();
        answer.onDismissOf(dialog);
        show(dialog, answer, title, null, choices, null);
    }

    /** Asks for words; the answer is what was typed, or none where it was cancelled. */
    static void prompt(Context context, long ticket, String title, String message, String accept, String cancel,
                       String placeholder, int maximumLength, int inputType, String initial) {
        Answer answer = new Answer(ticket);
        EditText field = new EditText(context);
        field.setInputType(inputType);
        field.setSingleLine(true);
        if (maximumLength >= 0) field.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence text, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence text, int start, int before, int count) {}

            @Override
            public void afterTextChanged(Editable text) {
                String held = StateUIHost.heldWords(
                        text.toString(), maximumLength, BaseInputConnection.getComposingSpanStart(text) != -1);
                if (held != null) text.replace(0, text.length(), held);
            }
        });
        field.setText(initial);
        field.setSelection(field.getText().length());
        if (placeholder != null) field.setHint(placeholder);
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

        void choose(int place) {
            if (given) return;
            given = true;
            StateUIHost.actionChosen(ticket, place);
        }

        void onDismissOf(AlertDialog dialog) {
            dialog.setOnDismissListener(dismissed -> {
                showing.removeIf(shown -> shown.dialog == dialog);
                give(false, null);
            });
        }
    }
}
