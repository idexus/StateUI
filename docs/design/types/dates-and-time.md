# Dates and time

`CalendarDate` is a day, `ClockTime` a time of day, and `TimeZoneName` names
a zone; the application's `clock` asks the host for the time and a zone's
offset. None of them uses Foundation.

## Without Foundation

StateUI's days and times are values of its own rather than Foundation's
`Date`. Turning a Foundation date into text needs a date formatter, a date
formatter needs ICU, and ICU is what the library cannot have: on Windows it
ships as separate libraries, and a mismatched one takes the process down with
nothing to diagnose. Three integers need none of that. Zero-padding a number
is done by hand for the same reason.

## Three integers each way

`CalendarDate` is a year, a month and a day; `ClockTime` an hour, a minute,
a second and a millisecond. Each crosses as its integers - year, month, day,
or hour, minute, second - which is also how a picker reports them back, so
the two directions say the same thing and nothing has to agree about which
number is the month. A value read back takes the whole number nearest each number
and refuses any other shape, so a report that does not read leaves the
handler alone. On a carried state each lies as three lanes in the same
order.

## Nothing checks the values

Neither type checks that its numbers make a real day or time. February 31st
crosses, and the host reads it as no day at all, which leaves the property
unset: a `DatePicker` goes on showing the date it had. A host reads a time
as a length of time since midnight, adding the three numbers up round the
day (`CalendarArithmetic.clock`), so `ClockTime(hour: 25, minute: 99)`
reaches a picker as 02:39 rather than being refused.

## Whole seconds

A `TimePicker` picks hours and minutes on every platform and keeps nothing
finer than a second, so a host is handed whole seconds: a time that crosses,
or rides a carried state, comes back with a millisecond of 0. The
millisecond is there for `application.clock.now()`.

## Text is not a display format

`text` writes one fixed shape, `2026-08-02` or `09:30:00`, for text an
application composes itself. How a picker writes a day for the user is its
`.format(_:)` - a `DateFormat`, short, medium or long - which the host
applies in the user's language and region; a time picker's is its own.

Reading text is strict. A day reads from `2026-08-02`, with or without the
leading zeros, each part digits alone - an empty part, a plus or a letter is
no day - and a year before the first carries a minus before its digits,
`-0005-03-01`, as `text` writes it, read with its sign as one number, so
every day reads back, the year furthest before the first included, whose
magnitude no `Int` holds; a time from `09:30`, `09:30:05` or `09:30:05.123`, the
fraction exactly three digits. `05.12` would be 120 milliseconds wearing a
12, and refusing it keeps a truncated value visible. Any other shape reads as
nil, so text that is not a date shows up where it is read rather than
becoming a silent midnight.

## The clock is an act

Reading a clock is the platform's business, and the core has none of its
own: Foundation's calendar machinery arrives with ICU. The application's
`clock` asks the host: one act answers the local day and time of day as seven
numbers - year, month, day, hour, minute, second, millisecond - with nothing
formatted or parsed, and `now()` and `today()` each read their part of it. The
millisecond lets a clock sleep to the next whole second instead of drifting
past it. The clock is a part of the application's session, as the clipboard
is: an act belongs to a session, never to a type's static namespace.

## Time zones come from the host

Foundation's time zones do not answer the same way on every platform. Apple
platforms answer everything themselves. Android detects no zone until `TZ`
names one: its time zone database is packed in a format Foundation does not
read, so `TimeZone.current` comes up GMT, while a named zone resolves from
ICU's own copy. Windows links only FoundationEssentials, which carries no
zone database, so a named zone is nil there and nothing sets it.

StateUI asks the host instead: the user's zone is a fact of the locale,
`locale.timeZone`, which the host reports as it reports the language, and a
zone's distance from UTC is the clock's act, so either is the same answer
everywhere, the way `application.clock.now()` is the same clock everywhere. The
Gallery's Foundation probe sample shows each platform's answers side by side.
On Android, an application that wants Foundation's own zones sets `TZ` to
`locale.timeZone` before its first `TimeZone` use, since the variable is read
ahead of any detection.

## An offset on a day

`utcOffset` answers a `Duration` rather than a `ClockTime`: an offset can be
negative, a `ClockTime` is a time of day, and `Duration` is the standard
library's own, needing no Foundation. The day decides the answer wherever
summer time does, so the host reads the day at noon, the one hour no zone
has ever moved. With no day the answer is the offset in effect now - what a
clock showing that zone's time needs, also in the night hour a switch has
not yet passed. The zone crosses as text, because an IANA identifier is
text and names nothing the core knows, and a zone or a day left out crosses
as `.nothing`, meaning the local zone and now.
