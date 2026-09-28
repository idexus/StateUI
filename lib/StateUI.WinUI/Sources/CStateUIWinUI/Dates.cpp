// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A day and a time of day: WinUI's CalendarDatePicker, its day written in the
// user's own way and its calendar opening and closing, told through
// `presented`, and its TimePicker, in the user's clock; the user's choice of
// either told through `picked`. A day crosses as its year, month and day in
// the user's calendar, at noon, so no change of the clock moves it.
// Design: docs/design/platforms/winui/controls.md#a-day-and-a-time

#include "Relay.h"

#include <chrono>

#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Globalization.DateTimeFormatting.h>

using namespace stateui;
namespace globalization = winrt::Windows::Globalization;
using winrt::Windows::Foundation::DateTime;
using winrt::Windows::Foundation::TimeSpan;

namespace {
    /// Noon of the day in the user's calendar.
    DateTime noon(int32_t year, int32_t month, int32_t day) {
        globalization::Calendar calendar;
        calendar.ChangeCalendarSystem(globalization::CalendarIdentifiers::Gregorian());
        calendar.Year(year);
        calendar.Month(month);
        calendar.Day(day);
        calendar.Period(calendar.FirstPeriodInThisDay());
        calendar.Hour(12);
        calendar.Minute(0);
        calendar.Second(0);
        calendar.Nanosecond(0);
        return calendar.GetDateTime();
    }

    /// The day `moment` falls on in the user's calendar: year, month and day.
    void dayOf(DateTime moment, int32_t *parts) {
        globalization::Calendar calendar;
        calendar.ChangeCalendarSystem(globalization::CalendarIdentifiers::Gregorian());
        calendar.SetDateTime(moment);
        parts[0] = calendar.Year();
        parts[1] = calendar.Month();
        parts[2] = calendar.Day();
    }

    /// The user's own pattern for a short or a long day.
    winrt::hstring dayPattern(bool longForm) {
        globalization::DateTimeFormatting::DateTimeFormatter formatter(longForm ? L"longdate" : L"shortdate");
        return formatter.Patterns().GetAt(0);
    }
}

extern "C" StateUIObjectRef stateui_winui_date_make(int64_t view) {
    try {
        controls::CalendarDatePicker picker;
        picker.DateFormat(dayPattern(false));
        picker.DateChanged([view](controls::CalendarDatePicker const &, controls::CalendarDatePickerDateChangedEventArgs const &args) {
            if (!args.NewDate()) return;
            int32_t parts[3];
            dayOf(args.NewDate().Value(), parts);
            callbacks.picked(view, parts[0], parts[1], parts[2]);
        });
        picker.Opened([view](IInspectable const &, IInspectable const &) { callbacks.presented(view, true); });
        picker.Closed([view](IInspectable const &, IInspectable const &) { callbacks.presented(view, false); });
        return detach(picker);
    } catch (...) {
        report("making a date picker");
        return nullptr;
    }
}

extern "C" void stateui_winui_date_set(StateUIObjectRef handle, bool hasDate, int32_t year, int32_t month, int32_t day) {
    try {
        auto picker = borrow<controls::CalendarDatePicker>(handle);
        if (!hasDate) {
            picker.Date(nullptr);
            return;
        }
        auto wanted = noon(year, month, day);
        auto shown = picker.Date();
        if (shown) {
            int32_t parts[3];
            dayOf(shown.Value(), parts);
            if (parts[0] == year && parts[1] == month && parts[2] == day) return;
        }
        picker.Date(wanted);
    } catch (...) {
        report("setting a date picker's day");
    }
}

extern "C" void stateui_winui_date_set_range(StateUIObjectRef handle, int32_t const *earliest, int32_t const *latest) {
    try {
        auto picker = borrow<controls::CalendarDatePicker>(handle);
        // No bound is WinUI's own: a hundred years each way.
        if (earliest) picker.MinDate(noon(earliest[0], earliest[1], earliest[2]));
        else picker.ClearValue(controls::CalendarDatePicker::MinDateProperty());
        if (latest) picker.MaxDate(noon(latest[0], latest[1], latest[2]));
        else picker.ClearValue(controls::CalendarDatePicker::MaxDateProperty());
    } catch (...) {
        report("bounding a date picker");
    }
}

extern "C" void stateui_winui_date_set_format(StateUIObjectRef handle, bool longForm) {
    try {
        borrow<controls::CalendarDatePicker>(handle).DateFormat(dayPattern(longForm));
    } catch (...) {
        report("setting how a date picker writes its day");
    }
}

extern "C" void stateui_winui_date_set_open(StateUIObjectRef handle, bool open) {
    try {
        borrow<controls::CalendarDatePicker>(handle).IsCalendarOpen(open);
    } catch (...) {
        report("opening a date picker's calendar");
    }
}

extern "C" bool stateui_winui_date_is_open(StateUIObjectRef handle) {
    try {
        return borrow<controls::CalendarDatePicker>(handle).IsCalendarOpen();
    } catch (...) {
        report("reading whether a date picker's calendar shows");
        return false;
    }
}

extern "C" bool stateui_winui_date(StateUIObjectRef handle, int32_t *parts) {
    try {
        auto shown = borrow<controls::CalendarDatePicker>(handle).Date();
        if (!shown) return false;
        dayOf(shown.Value(), parts);
        return true;
    } catch (...) {
        report("reading a date picker's day");
        return false;
    }
}

extern "C" void stateui_winui_date_pick_as_user(StateUIObjectRef handle, int32_t year, int32_t month, int32_t day) {
    try {
        borrow<controls::CalendarDatePicker>(handle).Date(noon(year, month, day));
    } catch (...) {
        report("picking a day as the user");
    }
}

extern "C" StateUIObjectRef stateui_winui_time_make(int64_t view) {
    try {
        controls::TimePicker picker;
        picker.SelectedTimeChanged([view](controls::TimePicker const &, controls::TimePickerSelectedValueChangedEventArgs const &args) {
            if (!args.NewTime()) return;
            auto minutes = std::chrono::duration_cast<std::chrono::minutes>(args.NewTime().Value()).count();
            callbacks.picked(view, static_cast<int32_t>(minutes / 60), static_cast<int32_t>(minutes % 60), 0);
        });
        return detach(picker);
    } catch (...) {
        report("making a time picker");
        return nullptr;
    }
}

extern "C" void stateui_winui_time_set(StateUIObjectRef handle, bool hasTime, int32_t hour, int32_t minute) {
    try {
        auto picker = borrow<controls::TimePicker>(handle);
        if (!hasTime) {
            picker.SelectedTime(nullptr);
            return;
        }
        TimeSpan wanted = std::chrono::hours(hour) + std::chrono::minutes(minute);
        auto shown = picker.SelectedTime();
        if (!shown || shown.Value() != wanted) picker.SelectedTime(wanted);
    } catch (...) {
        report("setting a time picker's time");
    }
}

extern "C" bool stateui_winui_time(StateUIObjectRef handle, int32_t *parts) {
    try {
        auto shown = borrow<controls::TimePicker>(handle).SelectedTime();
        if (!shown) return false;
        auto minutes = std::chrono::duration_cast<std::chrono::minutes>(shown.Value()).count();
        parts[0] = static_cast<int32_t>(minutes / 60);
        parts[1] = static_cast<int32_t>(minutes % 60);
        return true;
    } catch (...) {
        report("reading a time picker's time");
        return false;
    }
}

extern "C" void stateui_winui_time_pick_as_user(StateUIObjectRef handle, int32_t hour, int32_t minute) {
    try {
        borrow<controls::TimePicker>(handle).SelectedTime(TimeSpan{std::chrono::hours(hour) + std::chrono::minutes(minute)});
    } catch (...) {
        report("picking a time as the user");
    }
}
