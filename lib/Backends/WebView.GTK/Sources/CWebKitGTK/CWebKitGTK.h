// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What the GTK backend calls of WebKitGTK 6.0, declared by itself over `void *`: GTK's headers belong to the GTK
// host's own module, and a second module including them would take GTK's declarations from it. WebKit's objects are
// GObjects, and a GTK widget where WebKit answers one; its gboolean an int, its gssize a long.

extern void *webkit_web_view_new(void);
extern void webkit_web_view_load_uri(void *web_view, const char *uri);
extern void webkit_web_view_load_html(void *web_view, const char *content, const char *base_uri);
extern void webkit_web_view_go_back(void *web_view);
extern void webkit_web_view_go_forward(void *web_view);
extern void webkit_web_view_reload(void *web_view);
extern int webkit_web_view_can_go_back(void *web_view);
extern int webkit_web_view_can_go_forward(void *web_view);
extern const char *webkit_web_view_get_uri(void *web_view);
extern void *webkit_web_view_get_back_forward_list(void *web_view);
extern void webkit_web_view_terminate_web_process(void *web_view);

extern void *webkit_web_view_get_settings(void *web_view);
extern void webkit_settings_set_user_agent(void *settings, const char *user_agent);
extern const char *webkit_settings_get_user_agent(void *settings);

extern void webkit_web_view_evaluate_javascript(
    void *web_view, const char *script, long length, const char *world_name, const char *source_uri,
    void *cancellable, void (*callback)(void *source, void *result, void *user_data), void *user_data);
extern void *webkit_web_view_evaluate_javascript_finish(void *web_view, void *result, void **error);
extern char *jsc_value_to_json(void *value, unsigned indent);

extern void *webkit_navigation_policy_decision_get_navigation_action(void *decision);
extern int webkit_navigation_action_get_navigation_type(void *action);
