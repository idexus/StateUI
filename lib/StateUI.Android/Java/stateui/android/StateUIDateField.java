// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.app.DatePickerDialog;
import android.app.Dialog;
import android.app.TimePickerDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.view.View;
import android.widget.DatePicker;
import android.widget.TextView;
import android.widget.TimePicker;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Locale;

/**
 * A DatePicker or a TimePicker: a field showing the day or the time in the user's locale, which opens the
 * platform's own calendar or clock. The user's choice, the dialog opening and it closing reach Swift by the
 * field's number; the program's opening and closing report nothing.
 */
final class StateUIDateField extends TextView
        implements View.OnClickListener, DatePickerDialog.OnDateSetListener, TimePickerDialog.OnTimeSetListener,
        DialogInterface.OnDismissListener {
    private final long view;
    private final boolean time;

    private int year = 2000, month = 1, day = 1, hour, minute;
    private int[] earliest = new int[0];
    private int[] latest = new int[0];
    private String format = "";
    private Dialog dialog;
    private boolean closing;

    StateUIDateField(Context context, long view, boolean time) {
        super(context, null, android.R.attr.spinnerStyle);
        this.view = view;
        this.time = time;
        setOnClickListener(this);
        show();
    }

    /** The day, its month counted from one. */
    void setDate(int year, int month, int day) {
        this.year = year;
        this.month = month;
        this.day = day;
        show();
    }

    /** The time of day. */
    void setTime(int hour, int minute) {
        this.hour = hour;
        this.minute = minute;
        show();
    }

    /** The earliest and latest days the calendar offers, each a year, month and day - or none. */
    void setRange(int[] from, int[] to) {
        earliest = from;
        latest = to;
    }

    /** "D" or "d" for the long or short day, "T" or "t" for the long or short time, else a pattern. */
    void setFormat(String pattern) {
        format = pattern;
        show();
    }

    /** Opens the calendar or the clock, or closes it; the program's own change reports nothing. */
    void setOpen(boolean open) {
        if (open && dialog == null) {
            showDialog();
        } else if (!open && dialog != null) {
            closing = true;
            dialog.dismiss();
            closing = false;
        }
    }

    @Override
    public void onClick(View clicked) {
        if (dialog != null) return;
        showDialog();
        StateUIHost.opened(view);
    }

    @Override
    public void onDateSet(DatePicker picker, int chosenYear, int chosenMonth, int chosenDay) {
        setDate(chosenYear, chosenMonth + 1, chosenDay);
        StateUIHost.fieldChose(view, year, month, day);
    }

    @Override
    public void onTimeSet(TimePicker picker, int chosenHour, int chosenMinute) {
        setTime(chosenHour, chosenMinute);
        StateUIHost.fieldChose(view, hour, minute, 0);
    }

    @Override
    public void onDismiss(DialogInterface dismissed) {
        dialog = null;
        if (!closing) StateUIHost.closed(view);
    }

    private void showDialog() {
        if (time) {
            dialog = new TimePickerDialog(getContext(), this, hour, minute,
                    android.text.format.DateFormat.is24HourFormat(getContext()));
        } else {
            DatePickerDialog calendar = new DatePickerDialog(getContext(), this, year, month - 1, day);
            if (earliest.length == 3) calendar.getDatePicker().setMinDate(millis(earliest, false));
            if (latest.length == 3) calendar.getDatePicker().setMaxDate(millis(latest, true));
            dialog = calendar;
        }
        dialog.setOnDismissListener(this);
        dialog.show();
    }

    /** The first or the last moment of a day in the device's zone. */
    private static long millis(int[] day, boolean end) {
        Calendar calendar = Calendar.getInstance();
        calendar.clear();
        calendar.set(day[0], day[1] - 1, day[2], end ? 23 : 0, end ? 59 : 0, end ? 59 : 0);
        return calendar.getTimeInMillis();
    }

    private void show() {
        Calendar calendar = Calendar.getInstance();
        calendar.clear();
        calendar.set(year, month - 1, day, hour, minute, 0);
        setText(formatter().format(calendar.getTime()));
    }

    private DateFormat formatter() {
        Locale locale = Locale.getDefault();
        switch (format) {
            case "D": return DateFormat.getDateInstance(DateFormat.LONG, locale);
            case "d": return DateFormat.getDateInstance(DateFormat.SHORT, locale);
            case "T": return DateFormat.getTimeInstance(DateFormat.MEDIUM, locale);
            case "t": return android.text.format.DateFormat.getTimeFormat(getContext());
            case "":
                return time ? android.text.format.DateFormat.getTimeFormat(getContext())
                        : DateFormat.getDateInstance(DateFormat.MEDIUM, locale);
            default:
                try {
                    return new SimpleDateFormat(format, locale);
                } catch (IllegalArgumentException malformed) {
                    return time ? android.text.format.DateFormat.getTimeFormat(getContext())
                            : DateFormat.getDateInstance(DateFormat.MEDIUM, locale);
                }
        }
    }
}
