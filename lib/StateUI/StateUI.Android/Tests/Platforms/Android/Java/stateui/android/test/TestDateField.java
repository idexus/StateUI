// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.app.DatePickerDialog;
import android.app.Dialog;
import android.app.TimePickerDialog;
import android.content.DialogInterface;
import android.widget.TextView;
import java.text.DateFormat;
import java.text.ParseException;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

/** A date field's day or time read from the words it shows, and the user's hand on the dialog it opened. */
public final class TestDateField {
    private TestDateField() {}

    /** The day a field shows in the platform's own form: year, month from one, day; null where it shows another. */
    public static int[] day(TextView field) {
        Calendar shown = parse(DateFormat.getDateInstance(DateFormat.MEDIUM, Locale.getDefault()), field);
        if (shown == null) return null;
        return new int[] { shown.get(Calendar.YEAR), shown.get(Calendar.MONTH) + 1, shown.get(Calendar.DAY_OF_MONTH) };
    }

    /** The hour and minute a field shows in the user's own form; null where it shows another. */
    public static int[] time(TextView field) {
        Calendar shown = parse(android.text.format.DateFormat.getTimeFormat(field.getContext()), field);
        if (shown == null) return null;
        return new int[] { shown.get(Calendar.HOUR_OF_DAY), shown.get(Calendar.MINUTE) };
    }

    /** Sets the open calendar on a day, its month from one, and presses its OK, as the user does. */
    public static void pickDay(Dialog dialog, int year, int month, int day) {
        DatePickerDialog calendar = (DatePickerDialog) dialog;
        calendar.getDatePicker().updateDate(year, month - 1, day);
        calendar.getButton(DialogInterface.BUTTON_POSITIVE).performClick();
    }

    /** Sets the open clock on an hour and a minute, and presses its OK, as the user does. */
    public static void pickTime(Dialog dialog, int hour, int minute) {
        TimePickerDialog clock = (TimePickerDialog) dialog;
        clock.updateTime(hour, minute);
        clock.getButton(DialogInterface.BUTTON_POSITIVE).performClick();
    }

    private static Calendar parse(DateFormat format, TextView field) {
        try {
            Date date = format.parse(field.getText().toString());
            Calendar calendar = Calendar.getInstance();
            calendar.setTime(date);
            return calendar;
        } catch (ParseException unread) {
            return null;
        }
    }
}
