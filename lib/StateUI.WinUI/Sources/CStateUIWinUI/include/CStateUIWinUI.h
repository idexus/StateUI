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

/// A brush as the host hands it: its kind - 0 none, 1 solid, 2 linear, 3 radial - its geometry in fractions of
/// the painted box (a line's two points, or a centre and a radius), then a colour and an offset for each stop.
typedef struct {
    int32_t kind;
    double geometry[4];
    int32_t count;
    uint32_t const *colors;
    double const *offsets;
} StateUIBrush;

/// An outline: 0 a rectangle, 1 one rounded by `radius` DIPs, 2 an ellipse.
typedef enum { StateUIOutlineRectangle, StateUIOutlineRounded, StateUIOutlineEllipse } StateUIOutline;

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

    /// A switch the user turned.
    void (*toggled)(int64_t view, bool on);

    /// A slider's value moved.
    void (*valueChanged)(int64_t view, double value);

    /// A field's words changed, all of them handed over in UTF-8.
    void (*textChanged)(int64_t view, char const *utf8);

    /// A single-line field's Enter.
    void (*submitted)(int64_t view);
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

/// Cuts what the element shows to `outline` over `width` by `height` DIPs; `cuts` false shows it whole.
void stateui_winui_set_clip(StateUIObjectRef element, bool cuts, StateUIOutline outline, double radius,
                            double width, double height);

/// Whether the element takes clicks and touches; one that does not lets them through to what is behind it.
void stateui_winui_set_hit_testable(StateUIObjectRef element, bool testable);

/// Where the element is drawn among its panel's children: a higher one over a lower, equal ones in order.
void stateui_winui_set_z_index(StateUIObjectRef element, int32_t z);

/// Asks WinUI to arrange the element again - a place in the air lands only in a pass.
void stateui_winui_invalidate_arrange(StateUIObjectRef element);

/// Runs WinUI's layout pass over the element's tree now, as its next frame would.
void stateui_winui_update_layout(StateUIObjectRef element);

/// Moves, turns and scales the element where its layout put it: DIPs and degrees, about the point
/// (`centerX`, `centerY`) of it, in DIPs.
void stateui_winui_set_transform(StateUIObjectRef element, double translationX, double translationY,
                                 double rotation, double scaleX, double scaleY, double centerX, double centerY);

/// The transform as WinUI holds it, in `set_transform`'s order: seven values.
void stateui_winui_transform(StateUIObjectRef element, double *values);

/// The element's Opacity as WinUI holds it.
double stateui_winui_opacity(StateUIObjectRef element);

/// Whether the user leaves Windows' animations on.
bool stateui_winui_animations_enabled(void);

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

StateUIObjectRef stateui_winui_switch_make(int64_t view);
void stateui_winui_switch_set_on(StateUIObjectRef toggle, bool on);
bool stateui_winui_switch_is_on(StateUIObjectRef toggle);

/// Turns a switch as UI Automation does, which the user's turn is.
void stateui_winui_switch_toggle(StateUIObjectRef toggle);

StateUIObjectRef stateui_winui_slider_make(int64_t view);

/// The range, then the value, kept inside it; the steps are a ten-thousandth of the range.
void stateui_winui_slider_set(StateUIObjectRef slider, double value, double minimum, double maximum);
double stateui_winui_slider_value(StateUIObjectRef slider);

/// Moves a slider as UI Automation does, which the user's move is.
void stateui_winui_slider_move(StateUIObjectRef slider, double value);

StateUIObjectRef stateui_winui_field_make(int64_t view);
void stateui_winui_field_set_text(StateUIObjectRef field, char const *utf8);
void stateui_winui_field_set_placeholder(StateUIObjectRef field, char const *utf8);

/// A shape drawn behind a layout's children: a rectangle, rounded or not, or an ellipse, filled and outlined.
StateUIObjectRef stateui_winui_shape_make(StateUIOutline outline);
void stateui_winui_shape_set(StateUIObjectRef shape, double radius, StateUIBrush fill, StateUIBrush stroke,
                             double strokeWidth);

/// A ColorBox: a Border filled with one colour, its corners rounded in DIPs - top left, top right, bottom right,
/// bottom left.
StateUIObjectRef stateui_winui_color_box_make(void);
void stateui_winui_color_box_set(StateUIObjectRef box, uint32_t argb, double const *corners);

/// Renders the element and reads the colour, as ARGB, at each of `count` points given as x and y in DIPs of it -
/// what a test reads of the screen; whether it rendered.
bool stateui_winui_pixels(StateUIObjectRef element, double const *points, int32_t count, uint32_t *argb);

#ifdef __cplusplus
}
#endif
