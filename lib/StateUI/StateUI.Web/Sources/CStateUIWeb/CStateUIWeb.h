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

/// Calls listener `listener` whenever the element hears `event` - a DOM event's name, `enter` for the Return key, or
/// `activate` for Return or Space pressed on the element itself.
STATEUI_WEB(listen) void stateui_web_listen(int32_t element, const char *event, int32_t length, int32_t listener);

/// What the event a listener is hearing carries: 0 how many clicks it counts, 1 and 2 where the pointer is from the
/// listening element's top left corner.
STATEUI_WEB(event_number) double stateui_web_event_number(int32_t index);

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

/// Whether the user asked for less motion.
STATEUI_WEB(reduces_motion) int32_t stateui_web_reduces_motion(void);
