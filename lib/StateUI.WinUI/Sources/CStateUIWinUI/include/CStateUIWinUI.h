// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The relay's C surface: what the WinUI host calls, and the callbacks the relay
// makes on the UI thread. Plain C, so Swift imports it as a C module. A handle is
// an AddRef'd WinRT interface pointer the host lets go of with
// stateui_winui_release; a view is the number the host gave the element.
// Design: docs/design/platforms/winui/relay.md#the-c-surface
#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct StateUIObject *StateUIObjectRef;

/// What the relay calls on the UI thread. Every one is set: the relay calls them unchecked.
typedef struct {
    /// WinUI stands on the thread: the host's first render.
    void (*launched)(void);

    /// A turn the doorbell posted to the UI thread's queue.
    void (*turn)(void);

    /// A frame WinUI composes, while the host holds the frame clock.
    void (*frame)(void);

    /// A panel's MeasureOverride: `size` takes the width and height the view needs.
    void (*measure)(int64_t view, double width, double height, double *size);

    /// A panel's ArrangeOverride: the view places its children in the size given.
    void (*arrange)(int64_t view, double width, double height);

    /// A button's Click.
    void (*clicked)(int64_t view);
} StateUIWinUICallbacks;

/// Starts the Windows App SDK and WinUI on this thread and runs its loop until the last window closes.
int32_t stateui_winui_run(StateUIWinUICallbacks const *callbacks);

/// Makes this thread hold WinUI elements with no loop of WinUI's running - a test process's thread.
int32_t stateui_winui_embed(StateUIWinUICallbacks const *callbacks);

/// Runs this thread's messages for `seconds` - the loop an embedded thread lacks.
void stateui_winui_pump(double seconds);

/// Posts one turn to the UI thread's queue; any thread.
void stateui_winui_post_turn(void);

/// Subscribes to CompositionTarget.Rendering, or lets go of it.
void stateui_winui_hold_frames(bool hold);

/// Lets go of a handle.
void stateui_winui_release(StateUIObjectRef object);

StateUIObjectRef stateui_winui_window_make(void);
void stateui_winui_window_set_title(StateUIObjectRef window, char const *title);
void stateui_winui_window_set_content(StateUIObjectRef window, StateUIObjectRef content);
void stateui_winui_window_activate(StateUIObjectRef window);
void stateui_winui_window_close(StateUIObjectRef window);

/// Every element: measured and placed by its parent's panel, shown or collapsed, drawn how opaque.
void stateui_winui_measure(StateUIObjectRef element, double width, double height, double *size);
void stateui_winui_arrange(StateUIObjectRef element, double x, double y, double width, double height);
void stateui_winui_invalidate_measure(StateUIObjectRef element);
void stateui_winui_set_shown(StateUIObjectRef element, bool shown);
void stateui_winui_set_opacity(StateUIObjectRef element, double opacity);

/// Where WinUI laid the element out in its parent: x, y, width, height, in DIPs.
void stateui_winui_frame(StateUIObjectRef element, double *frame);

/// A control's IsEnabled.
void stateui_winui_set_enabled(StateUIObjectRef control, bool enabled);

/// The words a text block or a button's caption shows, in UTF-8; the length they need, their end not counted.
int32_t stateui_winui_text(StateUIObjectRef element, char *utf8, int32_t capacity);

StateUIObjectRef stateui_winui_panel_make(int64_t view);
void stateui_winui_panel_set_children(StateUIObjectRef panel, StateUIObjectRef const *children, int32_t count);

StateUIObjectRef stateui_winui_text_make(void);
void stateui_winui_text_set_text(StateUIObjectRef text, char const *utf8);

/// The words' colour as 0xAARRGGBB; `has` false puts back the platform's.
void stateui_winui_text_set_color(StateUIObjectRef text, bool has, uint32_t argb);

StateUIObjectRef stateui_winui_button_make(int64_t view);
void stateui_winui_button_set_text(StateUIObjectRef button, char const *utf8);

/// Presses a button as UI Automation does, which raises its Click.
void stateui_winui_button_invoke(StateUIObjectRef button);

#ifdef __cplusplus
}
#endif
