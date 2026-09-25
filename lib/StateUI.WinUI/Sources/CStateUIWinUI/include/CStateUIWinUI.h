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

/// What of the user's input a view listens for, each a bit: taps; the pointer entering, leaving, moving, and its
/// button going down and up; a press dragged; two fingers pinching.
typedef enum {
    StateUIHearingTaps = 1,
    StateUIHearingPointer = 2,
    StateUIHearingDrags = 4,
    StateUIHearingPinches = 8,
} StateUIHearing;

/// What a view heard: a tap, its place in a quick run of taps from 1, 0 for a press assistive technology made; the
/// pointer at (x, y) DIPs of the view; a drag's phase - 0 began, 1 moved, 2 ended, 3 cancelled - moved by (x, y)
/// DIPs since it began; a pinch's phase, its scale since the last, at (x, y) as shares of the view's size.
typedef enum {
    StateUIHeardTap,
    StateUIHeardPointerEntered,
    StateUIHeardPointerExited,
    StateUIHeardPointerMoved,
    StateUIHeardPointerPressed,
    StateUIHeardPointerReleased,
    StateUIHeardDrag,
    StateUIHeardPinch,
} StateUIHeard;

/// A question for the user: `kind` 0 an alert, 1 a confirmation, 2 a choice of actions, 3 a prompt; its title
/// and message; the captions that accept and cancel; for a choice, the dangerous one and the choices; for a
/// prompt, the field's placeholder, its most characters (0 for any), what it is for (StateUI's `InputPurpose`)
/// and what it starts holding. Null for a caption there is none of.
typedef struct {
    int32_t kind;
    char const *title;
    char const *message;
    char const *accept;
    char const *cancel;
    char const *destruction;
    char const *const *choices;
    int32_t choiceCount;
    char const *placeholder;
    int32_t maximumLength;
    int32_t purpose;
    char const *initial;
} StateUIQuestion;

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

    /// A switch, a check box or a radio button the user turned on or off.
    void (*toggled)(int64_t view, bool on);

    /// A slider's value moved.
    void (*valueChanged)(int64_t view, double value);

    /// A field's words changed, all of them handed over in UTF-8.
    void (*textChanged)(int64_t view, char const *utf8);

    /// A single-line field's Enter.
    void (*submitted)(int64_t view);

    /// A scroller's view changed: where it stands now, in DIPs.
    void (*scrolled)(int64_t view, double x, double y);

    /// The user took hold of a scroller, or let go of it.
    void (*held)(int64_t view, bool holding);

    /// The user chose an entry by its place: an action of a window's chrome, or its way back (-1) or sidebar toggle
    /// (-2); a tab.
    void (*chosen)(int64_t view, int32_t index);

    /// A split view's sidebar opened or closed of WinUI's accord: a click beside it, or the window's room.
    void (*presented)(int64_t view, bool open);

    /// Something the environment reports changed: the theme, the power, the network.
    void (*environmentChanged)(void);

    /// What a view heard of the user's input, as `StateUIHeard` says: `phase` a tap's place or a gesture's phase.
    void (*heard)(int64_t view, StateUIHeard what, int32_t phase, double x, double y, double scale);

    /// The user answered the question asked under `ticket`: whether it was accepted, and the words chosen or
    /// typed, in UTF-8; null for none.
    void (*answered)(int64_t ticket, bool accepted, char const *utf8);

    /// A press on a canvas, followed from down to up: `phase` 0 pressed, 1 dragged, 2 released, at (x, y) DIPs of it.
    void (*canvasPressed)(int64_t view, int32_t phase, double x, double y);
} StateUIWinUICallbacks;

/// What the environment is, in groups, each read at once.
typedef enum {
    StateUIFactsDevice,
    StateUIFactsApplication,
    StateUIFactsLocale,
    StateUIFactsBattery,
    StateUIFactsConnectivity,
    StateUIFactsTheme,
    StateUIFactsDisplay,
} StateUIFacts;

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

/// The window's chrome across its top, and the row of tabs beneath it; null for none. The first chrome given also
/// takes the window's way back: the mouse's back button, Alt+Left and the Back key choose its way back (-1).
void stateui_winui_window_set_chrome(StateUIObjectRef window, StateUIObjectRef titleBar, StateUIObjectRef tabs);
void stateui_winui_window_activate(StateUIObjectRef window);
void stateui_winui_window_close(StateUIObjectRef window);

/// Makes the element fill whatever place it is arranged in, whatever its style aligns it to: a StateUI layout
/// decides its place.
void stateui_winui_fill_place(StateUIObjectRef element);

/// Every element: measured and placed by its parent's panel, shown or collapsed, drawn how opaque.
void stateui_winui_measure(StateUIObjectRef element, double width, double height, double *size);
void stateui_winui_arrange(StateUIObjectRef element, double x, double y, double width, double height);
void stateui_winui_invalidate_measure(StateUIObjectRef element);
void stateui_winui_set_shown(StateUIObjectRef element, bool shown);
void stateui_winui_set_opacity(StateUIObjectRef element, double opacity);

/// Where `element`'s top left corner stands in its window's content, in DIPs, into `origin` (x, y).
void stateui_winui_origin(StateUIObjectRef element, double *origin);

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

/// How words look on a text block or any control showing them: the font - a size of 0 or less and an empty
/// family are the platform's - the colour as 0xAARRGGBB, `has` false putting back the platform's, and the room
/// around them in DIPs.
void stateui_winui_set_font(StateUIObjectRef element, double size, bool bold, bool italic, char const *family);
void stateui_winui_set_foreground(StateUIObjectRef element, bool has, uint32_t argb);
void stateui_winui_set_padding(StateUIObjectRef element, double left, double top, double right, double bottom);

/// How words look, as WinUI holds it: the size, the weight, the most lines, the alignment and the colour as
/// 0xAARRGGBB - five values; what a test reads back.
void stateui_winui_text_style(StateUIObjectRef element, double *style);

StateUIObjectRef stateui_winui_text_make(void);
void stateui_winui_text_set_text(StateUIObjectRef text, char const *utf8);

/// One run of a label's words, and how it differs from the label's: its colour and its background where it has
/// them, as 0xAARRGGBB; its size in DIPs, 0 for the label's; bold, italic, and lines under or through it.
typedef struct {
    char const *text;
    uint32_t color;
    uint32_t background;
    double size;
    bool hasColor;
    bool hasBackground;
    bool bold;
    bool italic;
    bool underline;
    bool strikethrough;
} StateUIWordsRun;

/// Shows `runs`, in order, as the text block's words, each as it says, in place of its words.
void stateui_winui_text_set_runs(StateUIObjectRef text, StateUIWordsRun const *runs, int32_t count);

/// The runs a text block shows, six values each - its colour as 0xAARRGGBB or 0, its size or 0, its weight, 1 for
/// italic, its lines (1 under, 2 through), its background or 0 - into `values` as far as `capacity` goes; answers
/// how many runs it shows. What a test reads back.
int32_t stateui_winui_text_runs(StateUIObjectRef text, double *values, int32_t capacity);

/// A label's lines - StateUI's LineBreak, and the most lines, 0 for any - its words' alignment across it - start,
/// centre, end - the space between its letters in thousandths of an em, the height of a line in DIPs, 0 for the
/// font's, and the lines under or through its words.
void stateui_winui_text_set_lines(StateUIObjectRef text, int32_t breaking, int32_t maximum);
void stateui_winui_text_set_alignment(StateUIObjectRef text, int32_t horizontal);
void stateui_winui_text_set_spacing(StateUIObjectRef text, int32_t characterSpacing, double lineHeight);
void stateui_winui_text_set_decorations(StateUIObjectRef text, bool underline, bool strikethrough);

StateUIObjectRef stateui_winui_button_make(int64_t view);

/// The words a button or a radio button shows.
void stateui_winui_set_caption(StateUIObjectRef control, char const *utf8);

/// A button's look: what fills it - the platform's for none, and fainter under the pointer and pressed, as
/// WinUI's own buttons - its outline `strokeWidth` DIPs wide, and its corners' radius, less than 0 for the
/// platform's.
void stateui_winui_button_set_look(StateUIObjectRef button, StateUIBrush background, StateUIBrush stroke,
                                   double strokeWidth, double cornerRadius);

/// Presses a button as UI Automation does, which raises its Click.
void stateui_winui_button_invoke(StateUIObjectRef button);

/// The controls that are on or off - a switch, a check box with no caption, and a radio button in a group of its
/// own - each telling its turn through `toggled`.
StateUIObjectRef stateui_winui_switch_make(int64_t view);
StateUIObjectRef stateui_winui_check_box_make(int64_t view);
StateUIObjectRef stateui_winui_radio_make(int64_t view);
void stateui_winui_toggle_set_on(StateUIObjectRef toggle, bool on);
bool stateui_winui_toggle_is_on(StateUIObjectRef toggle);

/// Turns a control as UI Automation does, which the user's turn is: a switch or a check box toggled, a radio
/// button chosen.
void stateui_winui_toggle_press(StateUIObjectRef toggle);

StateUIObjectRef stateui_winui_slider_make(int64_t view);

/// The range, then the value, kept inside it: a drag lands on a ten-thousandth of the range, an arrow key moves a
/// hundredth and Page Up a tenth.
void stateui_winui_slider_set(StateUIObjectRef slider, double value, double minimum, double maximum);
double stateui_winui_slider_value(StateUIObjectRef slider);

/// The slider's steps as WinUI holds them - an arrow key's, Page Up's and a drag's: three values.
void stateui_winui_slider_steps(StateUIObjectRef slider, double *steps);

/// Moves a slider as UI Automation does, which the user's move is.
void stateui_winui_slider_move(StateUIObjectRef slider, double value);

StateUIObjectRef stateui_winui_field_make(int64_t view);
void stateui_winui_field_set_text(StateUIObjectRef field, char const *utf8);
void stateui_winui_field_set_placeholder(StateUIObjectRef field, char const *utf8);

/// A shape drawn behind a layout's children: a rectangle, rounded or not, or an ellipse, filled and outlined.
StateUIObjectRef stateui_winui_shape_make(StateUIOutline outline);
void stateui_winui_shape_set(StateUIObjectRef shape, double radius, StateUIBrush fill, StateUIBrush stroke,
                             double strokeWidth);

/// A shape: one WinUI Path, drawn by `stateui_winui_path_draw` and painted by `stateui_winui_path_paint`.
StateUIObjectRef stateui_winui_path_make(void);

/// Paints a shape: its fill and outline, the outline's width, its dashes and their offset in outline widths, its ends
/// (StateUI's LineCap), its joins (LineJoin) and how far a mitred join may reach.
void stateui_winui_path_paint(StateUIObjectRef path, StateUIBrush fill, StateUIBrush stroke, double width,
                              double const *dashes, int32_t dashCount, double dashOffset, int32_t cap, int32_t join,
                              double miter);

/// Draws a shape in a room `width` by `height` DIPs: `kind` 0 a rectangle, its corners' `radii` clockwise from the
/// top left, or 1 an ellipse, both drawn `inset` from the room's edges; 2 the geometry `commands` draw - flat, 0 move
/// x y, 1 line x y, 2 cubic x1 y1 x2 y2 x y, 3 quadratic x1 y1 x y, 4 close - filled by `evenOdd`'s rule, placed by
/// `aspect` (fit, fill, stretch, centre) and centred, then moved by `transform` (a b c d tx ty) where one is given.
void stateui_winui_path_draw(StateUIObjectRef path, int32_t kind, double const *radii, double const *commands,
                             int32_t count, bool evenOdd, int32_t aspect, double const *transform, double width,
                             double height, double inset);

/// A canvas: a panel its drawing is replayed on, again for each size and scale it is shown at; a press on it is
/// told through `canvasPressed` for the view `view`.
StateUIObjectRef stateui_winui_canvas_make(int64_t view);

/// The canvas's drawing, as StateUI's `HostDrawing` lays it out: each instruction's kind and whole numbers in
/// `ints`, its numbers in `numbers`, and its text in `words`, `wordCount` UTF-8 runs of `lengths` bytes end to end.
void stateui_winui_canvas_draw(StateUIObjectRef canvas, int32_t const *ints, int32_t intCount, double const *numbers,
                               int32_t numberCount, char const *words, int32_t const *lengths, int32_t wordCount);

/// A ColorBox: a Border filled with one colour, its corners rounded in DIPs - top left, top right, bottom right,
/// bottom left.
StateUIObjectRef stateui_winui_color_box_make(void);
void stateui_winui_color_box_set(StateUIObjectRef box, uint32_t argb, double const *corners);

/// Renders the element and reads the colour, as ARGB, at each of `count` points given as x and y in DIPs of it -
/// what a test reads of the screen; whether it rendered.
bool stateui_winui_pixels(StateUIObjectRef element, double const *points, int32_t count, uint32_t *argb);

/// A ScrollView's scroller: a ScrollViewer around `content`, scrolling down (0), across (1), both ways (2) or not at
/// all (3); each bar shown as WinUI decides (0), always (1) or never (2).
StateUIObjectRef stateui_winui_scroller_make(int64_t view);
void stateui_winui_scroller_set(StateUIObjectRef scroller, StateUIObjectRef content, int32_t orientation,
                                int32_t verticalBar, int32_t horizontalBar);

/// Moves the scroller's view to `x`, `y` DIPs at once; the scroller keeps it within what it can reach, and says where
/// it stands through `scrolled` once it has moved.
void stateui_winui_scroller_move(StateUIObjectRef scroller, double x, double y);

/// Where the scroller's view stands, then the farthest it reaches across and down, in DIPs: four values.
void stateui_winui_scroller_offset(StateUIObjectRef scroller, double *offset);

/// A window's chrome: WinUI's TitleBar, its way back and its sidebar's toggle, the title, the page's actions on it or
/// in its overflow, and three slots - leading, centre, trailing. The way back is chosen as -1, the toggle as -2, an
/// action by its place.
StateUIObjectRef stateui_winui_title_bar_make(int64_t view);
void stateui_winui_title_bar_set(StateUIObjectRef bar, char const *title, bool back, bool paneToggle,
                                 bool hasBackground, uint32_t background, bool hasForeground, uint32_t foreground);
void stateui_winui_title_bar_set_actions(StateUIObjectRef bar, char const *const *texts, bool const *overflows,
                                         bool const *enabled, int32_t count);
void stateui_winui_title_bar_set_slots(StateUIObjectRef bar, StateUIObjectRef leading, StateUIObjectRef center,
                                       StateUIObjectRef trailing);

/// A split view: WinUI's NavigationView, the sidebar in its pane as wide as WinUI opens it - beside the detail from
/// `expandsAt` DIPs, over it and closed by a click beside it below - with none of the view's own buttons, which the
/// window's chrome carries; `row` stands across the top of the detail.
StateUIObjectRef stateui_winui_split_make(int64_t view, double expandsAt);
void stateui_winui_split_set(StateUIObjectRef split, StateUIObjectRef pane, StateUIObjectRef content,
                             StateUIObjectRef row, bool open);

/// A tabbed view's row of tabs: a SelectorBar, `selected` chosen.
StateUIObjectRef stateui_winui_tabs_make(int64_t view);
void stateui_winui_tabs_set(StateUIObjectRef tabs, char const *const *titles, int32_t count, int32_t selected);

/// A group of the environment's facts, in UTF-8, each ended by the unit separator (0x1F); the display's are the
/// screen `window` stands on. Answers the length the facts need, their end not counted.
int32_t stateui_winui_facts(StateUIFacts kind, StateUIObjectRef window, char *utf8, int32_t capacity);

/// Watches the theme, the power and the network, `environmentChanged` called in the UI thread's turn after each
/// change; once.
void stateui_winui_watch_environment(void);

/// Listens on `element`, which the view `view` shows, for what `hearing` names, each heard through `heard`; 0
/// stops. A panel that listens is hit where it draws nothing, and one that hears taps assistive technology presses.
void stateui_winui_hear(StateUIObjectRef element, int64_t view, uint32_t hearing);

/// Presses `element` as assistive technology does, through its automation peer; whether it could be pressed.
bool stateui_winui_press(StateUIObjectRef element);

/// Whether a click at (x, y) DIPs of `element` would reach the element itself.
bool stateui_winui_hits(StateUIObjectRef element, double x, double y);

/// How many views listen for the user's input - what a test counts to see every one stop.
int32_t stateui_winui_listeners(void);

/// How many canvases WinUI holds - what a test counts to see every one let go.
int32_t stateui_winui_canvases(void);

/// The local time of day: hour, minute, second and millisecond, into `time`.
void stateui_winui_clock(int32_t *time);

/// The IANA identifier of the local time zone, in UTF-8, as far as `capacity` goes; answers its whole length.
int32_t stateui_winui_time_zone(char *utf8, int32_t capacity);

/// How far `zone` - an IANA identifier, the local zone for null - stands from UTC on a day, in minutes; year 0
/// for today. Answers false for a zone ICU does not know.
bool stateui_winui_utc_offset(char const *zone, int32_t year, int32_t month, int32_t day, int32_t *minutes);

/// Says `utf8` to a screen reader, from `element`, cutting off what it was saying.
void stateui_winui_announce(StateUIObjectRef element, char const *utf8);

/// Puts the keyboard's focus on `element`, or the first control in it that takes it, answering whether one did;
/// or takes it off whatever holds it inside `element`, answering whether anything did.
bool stateui_winui_focus(StateUIObjectRef element, bool focus);

/// Whether `element`, or something inside it, holds the keyboard's focus.
bool stateui_winui_focused(StateUIObjectRef element);

/// Takes the focus off a field typed into in `element`'s window, so the on-screen keyboard goes; whether one was.
bool stateui_winui_hide_keyboard(StateUIObjectRef element);

/// Puts `question` to the user in WinUI's dialog over `element`'s window, once any dialog showing there has
/// closed; the answer comes back through `answered`, under `ticket`.
void stateui_winui_ask(StateUIObjectRef element, int64_t ticket, StateUIQuestion const *question);

/// Answers the dialog showing over `element`'s window as the user would: `button` 0 accepts, 1 cancels, 2 and on
/// press the choices in order; a prompt's field first holding `words` where they are given. Whether a dialog
/// was showing and had that button. What a test does.
bool stateui_winui_answer(StateUIObjectRef element, int32_t button, char const *words);

/// The folder the kept values stand in, in UTF-8; empty for the application's own in the user's local data.
void stateui_winui_set_store(char const *utf8);

/// The kept values' store as it stands, in UTF-8, as far as `capacity` goes; answers its whole length.
int32_t stateui_winui_stored(char *utf8, int32_t capacity);

/// Writes the whole store, in UTF-8, in place of the old one; whether it was written.
bool stateui_winui_store(char const *utf8);

/// The folder the application's pictures are read from, in UTF-8; empty for `Images` beside the executable.
void stateui_winui_set_pictures(char const *folder);

/// An Image showing the picture `name` names - an SVG where a PNG of that name is asked for and absent - filling
/// its room as StateUI's Aspect says: fit, fill, stretch, centre. Answers whether the picture was found; `size`
/// takes the size an SVG declares, in DIPs, and zero for a bitmap, whose size WinUI knows once it has read it.
StateUIObjectRef stateui_winui_image_make(void);
bool stateui_winui_image_set(StateUIObjectRef image, char const *name, int32_t aspect, double *size);

/// The size of the bitmap `image` shows, in DIPs; zero until it is read, and for an SVG. Once it is read, the
/// layout holding the image is asked to measure again.
void stateui_winui_image_size(StateUIObjectRef image, double *size);

/// Draws an SVG `image` shows at `width` by `height` DIPs, at the display's scale; nothing for a bitmap.
void stateui_winui_image_draw(StateUIObjectRef image, double width, double height);

#ifdef __cplusplus
}
#endif
