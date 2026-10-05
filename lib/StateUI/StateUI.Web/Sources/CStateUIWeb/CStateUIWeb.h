// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The JavaScript relay, as Swift imports it: functions the page hands the module (JavaScript/stateui-web.js).
// An element is the number the relay keeps it under; words cross as UTF-8 and their length in bytes.
// Design: docs/design/platforms/web/runtime.md#the-relay
#include <stdint.h>

#define STATEUI_WEB(name) __attribute__((import_module("stateui_web"), import_name(#name)))

/// What the page calls: a listener by its number, and a display frame at its time in milliseconds.
typedef void (*stateui_web_heard)(int32_t listener);
typedef void (*stateui_web_frame)(double time);

/// Hands the page the two functions it calls Swift through.
STATEUI_WEB(start) void stateui_web_start(stateui_web_heard heard, stateui_web_frame frame);

/// The page's body, where the window stands.
STATEUI_WEB(body) int32_t stateui_web_body(void);

/// Makes an element of `tag` and answers its number; `create_vector` one of SVG's.
STATEUI_WEB(create) int32_t stateui_web_create(const char *tag, int32_t length);
STATEUI_WEB(create_vector) int32_t stateui_web_create_vector(const char *tag, int32_t length);

/// Writes an SVG shape's bounds in its own space - x, y, width and height - into `into`.
STATEUI_WEB(read_shape_bounds) void stateui_web_read_shape_bounds(int32_t element, double *into);

/// Takes the element out of its parent and forgets its number.
STATEUI_WEB(release) void stateui_web_release(int32_t element);

/// Puts `child` in `parent` at `index` among its children, moving it there when it stands elsewhere.
STATEUI_WEB(insert) void stateui_web_insert(int32_t parent, int32_t child, int32_t index);

/// Takes the element out of its parent, keeping its number.
STATEUI_WEB(detach) void stateui_web_detach(int32_t element);

/// The element's words.
STATEUI_WEB(set_text) void stateui_web_set_text(int32_t element, const char *text, int32_t length);

/// An attribute; `remove_attribute` takes it away.
STATEUI_WEB(set_attribute) void stateui_web_set_attribute(
    int32_t element, const char *name, int32_t nameLength, const char *value, int32_t valueLength);
STATEUI_WEB(remove_attribute) void stateui_web_remove_attribute(int32_t element, const char *name, int32_t nameLength);

/// A CSS property of the element's own style; an empty value takes it away.
STATEUI_WEB(set_style) void stateui_web_set_style(
    int32_t element, const char *name, int32_t nameLength, const char *value, int32_t valueLength);

/// What a field holds - its `value`, which its attribute is not.
STATEUI_WEB(set_value) void stateui_web_set_value(int32_t element, const char *text, int32_t length);

/// A property of the element that is true or false - a checkbox's `checked` - and one that is a number - a range's
/// `valueAsNumber`; read back the same way.
STATEUI_WEB(set_flag) void stateui_web_set_flag(int32_t element, const char *name, int32_t length, int32_t on);
STATEUI_WEB(read_flag) int32_t stateui_web_read_flag(int32_t element, const char *name, int32_t length);
STATEUI_WEB(set_number) void stateui_web_set_number(int32_t element, const char *name, int32_t length, double value);
STATEUI_WEB(read_number) double stateui_web_read_number(int32_t element, const char *name, int32_t length);

/// Selects `length` UTF-16 units of a field's words from `start`, its caret there where `length` is 0.
STATEUI_WEB(select) void stateui_web_select(int32_t element, int32_t start, int32_t length);

/// Steps a number field `by` steps, up or down, within its range - its own `stepUp`.
STATEUI_WEB(step) void stateui_web_step(int32_t element, int32_t by);

/// Reads what a field holds into the relay and answers its length; `copy_read` copies it out.
STATEUI_WEB(read_value) int32_t stateui_web_read_value(int32_t element);

/// Copies what the relay read last into `into`, which holds its length.
STATEUI_WEB(copy_read) void stateui_web_copy_read(char *into);

/// Calls listener `listener` whenever the element hears `event`: a DOM event's name; `enter` for the Return key;
/// `activate` for Return or Space pressed on the element itself; `itemtap` for a click on it but on no control inside
/// it; `dismiss` for the user's asking a modal dialog to close; `closed` for a popover taken down; `menu` for the
/// user's asking for the element's menu - a right click, a finger held still.
STATEUI_WEB(listen) void stateui_web_listen(int32_t element, const char *event, int32_t length, int32_t listener);

/// What the event a listener is hearing carries: 0 how many clicks it counts, 1 and 2 where the pointer is from the
/// listening element's top left corner; 3 the pointer's number, 4 and 5 where it is on the page, 6 its kind - 0 a
/// mouse, 1 a pen, 2 a touch - 7 its button; 8 a wheel's turn down, 9 whether a key made it a pinch, 10 a gesture's
/// scale; 11 and 12 the listening element's size.
STATEUI_WEB(event_number) double stateui_web_event_number(int32_t index);

/// Calls `listener` as the element comes near the view of the scroller `root` - within half its size - and as it
/// goes away: the event's number 0 is 1 near, 0 away.
STATEUI_WEB(watch_nearness) void stateui_web_watch_nearness(int32_t element, int32_t root, int32_t listener);

/// Shows the popover element over everything: under the element `anchor`, or beside it for `side` 1, else at (`x`,
/// `y`) in the window - kept in the window whole; `hide_popover` takes it down.
STATEUI_WEB(show_popover) void stateui_web_show_popover(
    int32_t element, int32_t anchor, double x, double y, int32_t side);
STATEUI_WEB(hide_popover) void stateui_web_hide_popover(int32_t element);

/// The `<iframe>` shows the address `words` for `kind` 0, or for 1 the document `words`, its links resolved against
/// `base` where one is given.
STATEUI_WEB(frame_show) void stateui_web_frame_show(
    int32_t element, int32_t kind, const char *words, int32_t length, const char *base, int32_t baseLength);

/// What the page can know of the frame's document: 1 it is of the page's own site, 2 it can go back, 4 forward.
STATEUI_WEB(frame_state) int32_t stateui_web_frame_state(int32_t element);

/// The frame's document's address where it is of the page's site, read in two steps: its length, then `copy_read`.
STATEUI_WEB(frame_address) int32_t stateui_web_frame_address(int32_t element);

/// A step of the frame's own - 0 back, 1 forward, 2 the page again; whether it could take it.
STATEUI_WEB(frame_step) int32_t stateui_web_frame_step(int32_t element, int32_t step);

/// Runs the script in the frame's document: its value as JSON, read as `copy_read` reads; -1 where it could not.
STATEUI_WEB(frame_evaluate) int32_t stateui_web_frame_evaluate(int32_t element, const char *script, int32_t length);

/// Puts one entry of the page's own on the browser's history; `back_history` goes back over it; `listen_history`
/// calls `listener` whenever the browser's history moves - its way back, or forward.
STATEUI_WEB(push_history) void stateui_web_push_history(void);
STATEUI_WEB(back_history) void stateui_web_back_history(void);
STATEUI_WEB(listen_history) void stateui_web_listen_history(int32_t listener);

/// Calls the act `name` of the application's own scripts - `StateUI.acts` - with the words, and `listener` once its
/// promise settles: the event's number 0 is 1 kept, 0 broken, and `script_words` reads what it gave, or why.
STATEUI_WEB(call_script) void stateui_web_call_script(
    const char *name, int32_t length, const char *words, int32_t wordsLength, int32_t listener);
STATEUI_WEB(script_words) int32_t stateui_web_script_words(void);

/// Calls `listener` each time the application's scripts tell `name` - `StateUI.tell` - the last told first, the
/// words read by `script_words`.
STATEUI_WEB(listen_script) void stateui_web_listen_script(const char *name, int32_t length, int32_t listener);

/// Calls the element's own method `name`, with nothing.
STATEUI_WEB(call_method) void stateui_web_call_method(int32_t element, const char *name, int32_t length);

/// Shows the `<dialog>` element over the page, which takes no input but it until it closes; `close_modal` closes it.
STATEUI_WEB(show_modal) void stateui_web_show_modal(int32_t element);
STATEUI_WEB(close_modal) void stateui_web_close_modal(int32_t element);

/// Scrolls the element into its scrollers' view, standing as `anchor` says: 0 at the start, 1 the middle, 2 the end,
/// 3 the nearest edge.
STATEUI_WEB(scroll_into_view) void stateui_web_scroll_into_view(int32_t element, int32_t anchor);

/// The pointer of the event being heard goes on telling the element, wherever it moves, until it lets go.
STATEUI_WEB(capture_pointer) void stateui_web_capture_pointer(int32_t element);

/// The event being heard no longer does what the page would do with it: scroll, zoom, select.
STATEUI_WEB(take_event) void stateui_web_take_event(void);

/// Calls listener `listener` whenever the element's size changes.
STATEUI_WEB(observe_size) void stateui_web_observe_size(int32_t element, int32_t listener);

/// Writes the element's box on the page - x, y, width and height from the page's top left - into `into`.
STATEUI_WEB(read_box) void stateui_web_read_box(int32_t element, double *into);

/// Writes the element's size in its layout, before any transform, into `into`: width, height.
STATEUI_WEB(read_size) void stateui_web_read_size(int32_t element, double *into);

/// Where each child of `count` pairs `(layout, child)` stands in its layout, before any transform: four numbers a
/// child - from the layout's top left, then its size - and four NaN for one the page lays out nowhere; a pair whose
/// child is its layout reads the layout's own size.
STATEUI_WEB(read_places) void stateui_web_read_places(const int32_t *pairs, int32_t count, double *into);

/// Writes how far the element is scrolled into `into`: across, down.
STATEUI_WEB(read_scroll) void stateui_web_read_scroll(int32_t element, double *into);

/// Scrolls the element to `x` across and `y` down at once.
STATEUI_WEB(scroll_to) void stateui_web_scroll_to(int32_t element, double x, double y);

/// The document's title, which the browser shows on the tab.
STATEUI_WEB(set_title) void stateui_web_set_title(const char *text, int32_t length);

/// Asks for one display frame.
STATEUI_WEB(request_frame) void stateui_web_request_frame(void);

/// Calls Swift once, after `milliseconds`, in place of the call asked for before.
STATEUI_WEB(wake_after) void stateui_web_wake_after(double milliseconds);

/// The page's time, in milliseconds on one monotonic clock.
STATEUI_WEB(now) double stateui_web_now(void);

/// Whether the user's system is in its dark appearance; `listen_appearance` calls `listener` when it turns.
STATEUI_WEB(prefers_dark) int32_t stateui_web_prefers_dark(void);
STATEUI_WEB(listen_appearance) void stateui_web_listen_appearance(int32_t listener);

/// The smallest width of the screen in CSS pixels where its user points by touch; 0 where by a mouse or a pen.
STATEUI_WEB(touch_screen) double stateui_web_touch_screen(void);

/// Whether the user asked for less motion.
STATEUI_WEB(reduces_motion) int32_t stateui_web_reduces_motion(void);

/// Draws a canvas's drawing on the `<canvas>` element, sized to its room at the screen's own density: `count`
/// numbers of operations (WebCanvasStroke.swift), and the words they write, each ended by a zero byte.
STATEUI_WEB(draw_canvas) void stateui_web_draw_canvas(
    int32_t element, const double *numbers, int32_t count, const char *words, int32_t length);

/// The local time of day into `into`: hour, minute, second, millisecond.
STATEUI_WEB(local_time) void stateui_web_local_time(double *into);

/// The local time zone's name, read in two steps: its length in bytes, then `copy_read`.
STATEUI_WEB(local_zone) int32_t stateui_web_local_zone(void);

/// How far the zone named - the local one for none - is from UTC at noon on the day - today for a year of 0 - in
/// minutes; NaN for a zone the browser does not know.
STATEUI_WEB(utc_offset) double stateui_web_utc_offset(
    const char *zone, int32_t length, int32_t year, int32_t month, int32_t day);

/// Tells a screen reader the words, through the page's polite live region.
STATEUI_WEB(announce) void stateui_web_announce(const char *words, int32_t length);

/// Takes the focus off the field holding it, whose on-screen keyboard goes with it; whether one held it.
STATEUI_WEB(blur_field) int32_t stateui_web_blur_field(void);

/// Puts the focus on the element, or the first in it that takes it; whether the element or one in it holds it.
STATEUI_WEB(focus) int32_t stateui_web_focus(int32_t element);

/// Takes the focus off the element or the one in it holding it.
STATEUI_WEB(unfocus) void stateui_web_unfocus(int32_t element);

/// What the browser keeps under the key for this page's site, read in two steps: its length in bytes, then
/// `copy_read`; `store` keeps the words in its place, and answers whether it could.
STATEUI_WEB(stored) int32_t stateui_web_stored(const char *key, int32_t length);
STATEUI_WEB(store) int32_t stateui_web_store(const char *key, int32_t keyLength, const char *words, int32_t length);
