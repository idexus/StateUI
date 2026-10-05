// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The suite's driver, as Swift imports it: what the page holds, read by the relay's numbers of its elements, and
// what the user does to it (Testing/JavaScript/page.mjs). Words come back in two steps: a read answers their length in bytes, and
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
