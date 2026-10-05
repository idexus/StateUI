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

/// Makes an element of `tag` and answers its number.
STATEUI_WEB(create) int32_t stateui_web_create(const char *tag, int32_t length);

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

/// Reads what a field holds into the relay and answers its length; `copy_read` copies it out.
STATEUI_WEB(read_value) int32_t stateui_web_read_value(int32_t element);

/// Copies what the relay read last into `into`, which holds its length.
STATEUI_WEB(copy_read) void stateui_web_copy_read(char *into);

/// Calls listener `listener` whenever the element hears `event` - a DOM event's name, or `enter` for the Return key.
STATEUI_WEB(listen) void stateui_web_listen(int32_t element, const char *event, int32_t length, int32_t listener);

/// The document's title, which the browser shows on the tab.
STATEUI_WEB(set_title) void stateui_web_set_title(const char *text, int32_t length);

/// Asks for one display frame.
STATEUI_WEB(request_frame) void stateui_web_request_frame(void);

/// The page's time, in milliseconds on one monotonic clock.
STATEUI_WEB(now) double stateui_web_now(void);

/// Whether the user's system is in its dark appearance; `listen_appearance` calls `listener` when it turns.
STATEUI_WEB(prefers_dark) int32_t stateui_web_prefers_dark(void);
STATEUI_WEB(listen_appearance) void stateui_web_listen_appearance(int32_t listener);
