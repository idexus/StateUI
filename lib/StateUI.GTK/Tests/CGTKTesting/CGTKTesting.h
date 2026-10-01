// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// GTK's own checks of what an accessible holds, which GTK declares with a variable list of arguments Swift cannot
// call: each a check of one kind of value. Each answers NULL where the accessible holds the value, else what it holds,
// for g_free. Declared here by themselves: GTK's headers belong to the host's own module.
extern char *gtk_test_accessible_check_property(void *accessible, int property, ...);
extern char *gtk_test_accessible_check_state(void *accessible, int state, ...);

static inline char *stateui_test_accessible_property_is_words(void *accessible, int property, const char *words) {
    return gtk_test_accessible_check_property(accessible, property, words);
}

static inline char *stateui_test_accessible_property_is_number(void *accessible, int property, int number) {
    return gtk_test_accessible_check_property(accessible, property, number);
}

static inline char *stateui_test_accessible_state_is(void *accessible, int state, int on) {
    return gtk_test_accessible_check_state(accessible, state, on);
}
