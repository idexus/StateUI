// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The suite's driver, as Swift imports it: what the page holds, read by the relay's numbers of its elements, and
// what the user does to it - over Node's page (Testing/JavaScript/page.mjs), or a browser's (browser.mjs), which
// alone answers the last three. Words come back in two steps: a read answers their length in bytes, and
// `copy_read` copies them.
#include <stdint.h>

#define STATEUI_WEB_TESTING(name) __attribute__((import_module("stateui_web_testing"), import_name(#name)))

STATEUI_WEB_TESTING(child_count) int32_t stateui_web_testing_child_count(int32_t element);
STATEUI_WEB_TESTING(child) int32_t stateui_web_testing_child(int32_t element, int32_t index);
STATEUI_WEB_TESTING(read_style) int32_t stateui_web_testing_read_style(int32_t element, const char *name, int32_t length);
STATEUI_WEB_TESTING(read_attribute) int32_t stateui_web_testing_read_attribute(int32_t element, const char *name, int32_t length);
STATEUI_WEB_TESTING(read_text) int32_t stateui_web_testing_read_text(int32_t element);
STATEUI_WEB_TESTING(read_value) int32_t stateui_web_testing_read_value(int32_t element);
STATEUI_WEB_TESTING(copy_read) void stateui_web_testing_copy_read(char *into);
STATEUI_WEB_TESTING(enter) void stateui_web_testing_enter(int32_t element, const char *text, int32_t length);
STATEUI_WEB_TESTING(leave) void stateui_web_testing_leave(int32_t element);
STATEUI_WEB_TESTING(tap) void stateui_web_testing_tap(int32_t element);
STATEUI_WEB_TESTING(dismiss) void stateui_web_testing_dismiss(int32_t element);
STATEUI_WEB_TESTING(tell) void stateui_web_testing_tell(const char *name, int32_t length, const char *words, int32_t wordsLength);
STATEUI_WEB_TESTING(lay_out) void stateui_web_testing_lay_out(int32_t element, double x, double y, double width, double height);
// The browser's alone: the page goes on a frame while the program waits; the controller beside the browser is asked
// for what the page cannot do itself, in JSON - the user's own input, a file; and a script runs on an element `e`,
// answering its value in JSON.
STATEUI_WEB_TESTING(pause) void stateui_web_testing_pause(void);
STATEUI_WEB_TESTING(ask) int32_t stateui_web_testing_ask(const char *message, int32_t length);
STATEUI_WEB_TESTING(evaluate) int32_t stateui_web_testing_evaluate(int32_t element, const char *script, int32_t length);
