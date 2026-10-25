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

// Compiled in the relay, every function is exported from the host's library, where the host's tests call it too.
#ifdef STATEUI_WINUI_RELAY
#pragma clang attribute push(__attribute__((dllexport)), apply_to = function)
#endif

typedef struct StateUIObject *StateUIObjectRef;

/// A vocabulary the relay and the host share by name: Swift imports it as an enum of its own, so a switch over it on
/// either side names every case, and a case one side adds fails to compile on the other.
/// Design: docs/design/platforms/winui/relay.md#a-shared-vocabulary
#define STATEUI_CLOSED_ENUM __attribute__((enum_extensibility(closed)))

/// What a brush paints: nothing, one color, a linear gradient, a radial one.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIBrushKindNone,
    StateUIBrushKindSolid,
    StateUIBrushKindLinear,
    StateUIBrushKindRadial,
} StateUIBrushKind;

/// A brush as the host hands it: its kind, its geometry in fractions of the painted box (a line's two points, or a
/// center and its radii across and down), then a color and an offset for each stop.
typedef struct {
    StateUIBrushKind kind;
    double geometry[4];
    int32_t count;
    uint32_t const *colors;
    double const *offsets;
} StateUIBrush;

/// An outline: 0 a rectangle, 1 one rounded by `radius` DIPs, 2 an ellipse.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIOutlineRectangle,
    StateUIOutlineRounded,
    StateUIOutlineEllipse,
} StateUIOutline;

/// What of the user's input a view listens for, each a bit: taps; the pointer entering, leaving, moving, and its
/// button going down and up; a press dragged; two fingers pinching; the hand over a layout; two fingers turning. Its
/// bits stand as the host layer's `Hearing` does (`WinUIGesturesTests`).
// Swift: none
typedef enum {
    StateUIHearingTaps = 1,
    StateUIHearingPointer = 2,
    StateUIHearingDrags = 4,
    StateUIHearingPinches = 8,
    StateUIHearingHand = 16,
    StateUIHearingRotations = 32,
} StateUIHearing;

/// What a view heard: a tap, its place in a quick run of taps from 1, 0 for a press assistive technology made; the
/// pointer at (x, y) DIPs of the view; a pinch's `StateUIPhase`, its scale since the last, at (x, y) as shares of the
/// view's size; a press a drag may become, its `StateUIPressPhase` at (x, y) DIPs of the window's content, which the
/// host's rule makes a drag; a rotation's `StateUIPhase` and its degrees clockwise since the last, in the scale's
/// place; a wheel turned with Control, as Windows tells a trackpad's pinch, its notches in the scale's place - or,
/// over a layout WinUI's own scroller hears, the scale it scales for it.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIHeardTap,
    StateUIHeardPointerEntered,
    StateUIHeardPointerExited,
    StateUIHeardPointerMoved,
    StateUIHeardPointerPressed,
    StateUIHeardPointerReleased,
    StateUIHeardPinch,
    StateUIHeardPress,
    StateUIHeardRotation,
    StateUIHeardWheelPinch,
    StateUIHeardWheelScale,
} StateUIHeard;

/// A gesture's phase: begun, moved, ended, taken away.
// Swift: GesturePhase
typedef enum { StateUIPhaseBegan, StateUIPhaseChanged, StateUIPhaseEnded, StateUIPhaseCancelled } StateUIPhase;

/// A press's phase, the press a drag may become: down, moved, let go, taken away.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIPressPhaseDown,
    StateUIPressPhaseMoved,
    StateUIPressPhaseLetGo,
    StateUIPressPhaseTakenAway,
} StateUIPressPhase;

/// Where the hand over a layout stands after a finger's report: left to whatever holds the layout, still asking
/// whether the layout takes it, or the layout's.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIHandLeft,
    StateUIHandAsking,
    StateUIHandTaken,
} StateUIHandState;

/// Where words stand across or down their room: at its start, its center, its end.
// Swift: TextAlignment
typedef enum { StateUITextAlignmentStart, StateUITextAlignmentCenter, StateUITextAlignmentEnd } StateUITextAlignment;

/// The case typed letters are put in: as typed, the platform's own, lower, upper.
// Swift: TextCase
typedef enum {
    StateUITextCaseNone,
    StateUITextCaseDefault,
    StateUITextCaseLowercase,
    StateUITextCaseUppercase,
} StateUITextCase;

/// How a picker shows its choices: in a menu, as segments, as radio buttons.
// Swift: PickerPresentation
typedef enum {
    StateUIPickerPresentationMenu,
    StateUIPickerPresentationSegmented,
    StateUIPickerPresentationRadio,
} StateUIPickerPresentation;

/// The ways a scroller moves its document: down, across, both, neither.
// Swift: ScrollOrientation
typedef enum {
    StateUIScrollOrientationVertical,
    StateUIScrollOrientationHorizontal,
    StateUIScrollOrientationBoth,
    StateUIScrollOrientationNeither,
} StateUIScrollOrientation;

/// When a scroller shows its bar: as the platform does, always, never.
// Swift: ScrollIndicatorVisibility
typedef enum {
    StateUIScrollIndicatorVisibilityAutomatic,
    StateUIScrollIndicatorVisibilityVisible,
    StateUIScrollIndicatorVisibilityNever,
} StateUIScrollIndicatorVisibility;

/// The input scope a text box is given: the keys a keyboard on the screen offers, and whether it starts sentences
/// in capitals or offers emoji.
// Swift: WinUIInputScope
typedef enum {
    StateUIInputScopeDefault,
    StateUIInputScopeText,
    StateUIInputScopeChat,
    StateUIInputScopeEmail,
    StateUIInputScopeNumber,
    StateUIInputScopeTelephone,
    StateUIInputScopeUrl,
} StateUIInputScope;

/// What a button is: WinUI's Button, its DropDownButton, its SplitButton, its HyperlinkButton.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIButtonKindButton,
    StateUIButtonKindDropDown,
    StateUIButtonKindSplit,
    StateUIButtonKindLink,
} StateUIButtonKind;

/// The ways the hand over a layout moves it: none - the hand is not heard - across, down, every way.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIHandAxisNone,
    StateUIHandAxisHorizontal,
    StateUIHandAxisVertical,
    StateUIHandAxisEveryWay,
} StateUIHandAxis;

/// What a file dialog asks for: one file to open, several, a place to save.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIFileDialogKindOpen,
    StateUIFileDialogKindOpenSeveral,
    StateUIFileDialogKindSave,
} StateUIFileDialogKind;

/// An entry of a menu as the relay takes it, flat: an item, a separator, a submenu opening and closing, an item
/// standing unchecked or checked.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIMenuEntryItem,
    StateUIMenuEntrySeparator,
    StateUIMenuEntryMenuOpening,
    StateUIMenuEntryMenuClosing,
    StateUIMenuEntryItemOff,
    StateUIMenuEntryItemOn,
} StateUIMenuEntry;

/// A path's command, ahead of its points: move, line, cubic, quadratic, close.
// Swift: HostCurveCommand.Kind
typedef enum {
    StateUICurveMove,
    StateUICurveLine,
    StateUICurveCubic,
    StateUICurveQuadratic,
    StateUICurveClose,
} StateUICurve;

/// A canvas's instruction, ahead of its values, as the host layer lays a drawing out (`HostDrawing`).
// Swift: HostDrawing.Kind
typedef enum {
    StateUIDrawingFillColor = 0,
    StateUIDrawingStrokeColor = 1,
    StateUIDrawingTextColor = 2,
    StateUIDrawingLineWidth = 3,
    StateUIDrawingFontSize = 4,
    StateUIDrawingOpacity = 5,
    StateUIDrawingStrokeLine = 6,
    StateUIDrawingStrokeRectangle = 7,
    StateUIDrawingStrokeRoundedRectangle = 8,
    StateUIDrawingStrokeEllipse = 9,
    StateUIDrawingStrokePath = 11,
    StateUIDrawingFillRectangle = 12,
    StateUIDrawingFillRoundedRectangle = 13,
    StateUIDrawingFillEllipse = 14,
    StateUIDrawingFillPath = 16,
    StateUIDrawingText = 17,
    StateUIDrawingTranslate = 18,
    StateUIDrawingRotate = 19,
    StateUIDrawingScale = 20,
    StateUIDrawingSaveState = 21,
    StateUIDrawingRestoreState = 22,
} StateUIDrawing;

/// A shape's figure: a rectangle, an ellipse, or a geometry of its own.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIFigureKindRectangle,
    StateUIFigureKindEllipse,
    StateUIFigureKindAuthored,
} StateUIFigureKind;

/// A ground of a split view's pane: WinUI's own, a color, the in-app acrylic in a color.
typedef enum STATEUI_CLOSED_ENUM { StateUIGroundOwn, StateUIGroundColor, StateUIGroundAcrylic } StateUIGround;

/// Whether assistive technology meets an element: as the control is of itself, met, skipped, or skipped with every
/// part its template draws.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIPresenceOwn,
    StateUIPresenceMet,
    StateUIPresenceSkipped,
    StateUIPresenceSkippedWithParts,
} StateUIPresence;

/// An entry of a list: an item, or an edge - a header or a footer.
typedef enum STATEUI_CLOSED_ENUM { StateUIItemKindItem, StateUIItemKindEdge } StateUIItemKind;

/// How a list's entries stand: down, across, or in columns.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIItemsShapeList,
    StateUIItemsShapeRow,
    StateUIItemsShapeGrid,
} StateUIItemsShape;

/// A theme an element stands in: the system's, light, dark.
// Swift: ColorScheme
typedef enum { StateUIColorSchemeSystem, StateUIColorSchemeLight, StateUIColorSchemeDark } StateUIColorScheme;

/// What a question for the user is.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIQuestionKindAlert,
    StateUIQuestionKindConfirm,
    StateUIQuestionKindChooseAction,
    StateUIQuestionKindPrompt,
} StateUIQuestionKind;

/// What a view hears of a drag: its own drag started or ended; a drag over it, gone from it, or dropped on it.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIDragHeardStarted,
    StateUIDragHeardEnded,
    StateUIDragHeardOver,
    StateUIDragHeardLeft,
    StateUIDragHeardDropped,
} StateUIDragHeard;

/// A question for the user: its kind; its title and message; the captions that accept and cancel; for a choice, its
/// actions in order and the place of the dangerous one, -1 for none; for a prompt, the field's placeholder, its most
/// characters (0 for any), whether its words are spell checked and predicted, its input scope (`WinUIInputScope`) and
/// what it starts holding. Null for a caption there is none of.
typedef struct {
    StateUIQuestionKind kind;
    char const *title;
    char const *message;
    char const *accept;
    char const *cancel;
    char const *const *choices;
    int32_t choiceCount;
    int32_t destructive;
    char const *placeholder;
    int32_t maximumLength;
    bool spellChecked;
    bool predicted;
    int32_t scope;
    char const *initial;
} StateUIQuestion;

/// A file dialog: its kind; the kinds of file it offers, `typeCount`
/// captions, each with the count of its extensions - bare, without the dot - in `extensions` in turn; a save's name
/// and the `length` bytes it writes.
typedef struct {
    StateUIFileDialogKind kind;
    int32_t typeCount;
    char const *const *captions;
    int32_t const *extensionCounts;
    char const *const *extensions;
    char const *name;
    uint8_t const *contents;
    int64_t length;
} StateUIFileDialog;

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

    /// A slider's or a stepper's value moved.
    void (*valueChanged)(int64_t view, double value);

    /// A field's words changed, all of them handed over in UTF-8 - `composing` while an input method is composing
    /// them, told again as it commits them.
    void (*textChanged)(int64_t view, char const *utf8, bool composing);

    /// The words of the prompt asked under `ticket` changed - an input method composing them or not: the host holds
    /// them within the prompt's bound (`stateui_winui_prompt_write`).
    void (*promptTyped)(int64_t ticket, char const *utf8, bool composing);

    /// A single-line field's Enter, or a search box's query.
    void (*submitted)(int64_t view);

    /// A scroller's view changed: where it stands now, in DIPs.
    void (*scrolled)(int64_t view, double x, double y);

    /// The user holds a view down or lets it go: a scroller taken hold of, a button held by a pointer or a key.
    void (*held)(int64_t view, bool holding);

    /// The user pulled a scroller to refresh it: whether its spinner stays.
    bool (*refreshPulled)(int64_t view);

    /// The user chose an entry by its place: an action of a window's chrome, or its way back (-1), sidebar toggle
    /// (-2) or Escape (-3); a tab; a picker's choice.
    void (*chosen)(int64_t view, int32_t index);

    /// What a view presents opened or closed of WinUI's accord: a split view's sidebar, a picker's list, a calendar.
    void (*presented)(int64_t view, bool open);

    /// Something the environment reports changed: the theme, the power, the network, a screen.
    void (*environmentChanged)(void);

    /// What a view heard of the user's input, as `StateUIHeard` says: `phase` a tap's place or a gesture's phase.
    void (*heard)(int64_t view, StateUIHeard what, int32_t phase, double x, double y, double scale);

    /// The user answered the question asked under `ticket`: whether it was accepted, the words typed, in UTF-8, null
    /// for none, and the place of the action a choice's user chose, -1 for none; or why WinUI could not ask it, in
    /// UTF-8, null where it did.
    void (*answered)(int64_t ticket, bool accepted, char const *utf8, int32_t chosen, char const *failure);

    /// The file dialog shown under `ticket` closed: the `count` files chosen - a save's once its contents stand
    /// written - their paths and names in UTF-8, none for a cancel; or why it failed, in UTF-8, null where it did not.
    void (*filesChosen)(int64_t ticket, int32_t count, char const *const *paths, char const *const *names,
                        char const *failure);

    /// The file read under `ticket`: its `length` bytes; or why it could not be read, in UTF-8, null where it was.
    void (*fileRead)(int64_t ticket, uint8_t const *bytes, int64_t length, char const *failure);

    /// The request sent under `ticket` was answered: its status, its headers' names and values in turn a unit
    /// separator apart, in UTF-8, and its `length` bytes; or why no answer came, in UTF-8, null where one did.
    void (*requestAnswered)(int64_t ticket, int32_t status, char const *headers, uint8_t const *body, int64_t length,
                            char const *failure);

    /// What was launched under `ticket`: whether an application took it.
    void (*launchAnswered)(int64_t ticket, bool taken);

    /// What a view heard of a drag - dropped, with `words` in UTF-8.
    void (*dragHeard)(int64_t view, StateUIDragHeard heard, char const *words);

    /// Files dropped on a view from the system: their `count` paths and names, in UTF-8.
    void (*filesDragged)(int64_t view, int32_t count, char const *const *paths, char const *const *names);

    /// A press on a canvas, followed from down to up, at (x, y) DIPs of it.
    void (*canvasPressed)(int64_t view, StateUIPressPhase phase, double x, double y);

    /// The user picked a day - its year, month and day - or a time of day - its hour, minute and 0.
    void (*picked)(int64_t view, int32_t first, int32_t second, int32_t third);

    /// The user chose an item of a view's menu: its place among the menu's items, from 0.
    void (*menuChosen)(int64_t view, int32_t index);

    /// The keyboard came into a view - to it or to what stands in it - or left it.
    void (*focused)(int64_t view, bool focused);

    /// The window `window` names was activated or deactivated, or minimized: whether it stands minimized, and
    /// whether it is activated.
    void (*windowStateChanged)(int64_t window, bool minimized, bool activated);

    /// The window `window` names closed - the user's click, or the program's.
    void (*windowClosed)(int64_t window);

    /// The window numbered `window` was laid out, before it is drawn: whether what reads a frame said where it stands,
    /// which the window then lays out again.
    bool (*windowLaidOut)(int64_t window);

    /// An ItemsView needs a cell of `kind`: the host answers the panel that holds an entry, and its number in `cell`;
    /// the relay stands it in an ItemContainer kept for the list's life.
    StateUIObjectRef (*itemCell)(int64_t view, StateUIItemKind kind, int64_t *cell);

    /// An ItemsView stood the cell of the panel `cell` names for the entry of `identity`, in UTF-8.
    void (*itemHeld)(int64_t view, int64_t cell, char const *identity);

    /// An ItemsView put the cell of the panel `cell` names aside.
    void (*itemLetGo)(int64_t view, int64_t cell);

    /// The user changed an ItemsView's choice: every item chosen now, their identities joined by newlines.
    void (*itemsChose)(int64_t view, char const *identities);

    /// The user invoked an ItemsView's item.
    void (*itemInvoked)(int64_t view, char const *identity);

    /// An ItemsView's view changed: the places of the first and the last entry in it.
    void (*itemsShowing)(int64_t view, int32_t first, int32_t last);

    /// A key went down in the window whose chrome is `view`, before the element holding the focus has it - its
    /// VirtualKey and VirtualKeyModifiers: whether a view taking it took it.
    bool (*keyTaken)(int64_t view, int32_t key, int32_t modifiers);

    /// The hand over a layout - a press dragged by any pointer, a trackpad's fingers: its `StateUIPhase`, moved by
    /// (x, y) DIPs since the last, let go at (speedX, speedY) DIPs a second - NaN where untold - `time` its
    /// milliseconds on the pointer's clock: whether the layout took it.
    bool (*hand)(int64_t view, int32_t phase, double x, double y, double time, double speedX, double speedY);

    /// A finger over a layout a hand moves - a press of the primary button, a finger, a pen - at its
    /// `StateUIPressPhase`, by its number, at (x, y) DIPs of the window's content and (inX, inY) of the view, `time`
    /// its milliseconds on the pointer's clock: where the hand stands, by the host layer's reading of the fingers.
    StateUIHandState (*finger)(
        int64_t view, int32_t phase, uint32_t pointer, double x, double y, double inX, double inY, double time);

    /// A wheel's step over a layout, as far as the platform scrolls for it, moving what is under it by (x, y)
    /// DIPs: whether the layout took it.
    bool (*wheel)(int64_t view, double x, double y);

    /// A press dragged with Alt over a view two fingers move - its `StateUIPhase` - at (x, y) of the view, its middle
    /// at (middleX, middleY), in DIPs: two fingers, the press and its mirror.
    void (*mirrored)(int64_t view, int32_t phase, double x, double y, double middleX, double middleY);
} StateUIWinUICallbacks;

/// What the environment is, in groups, each read at once.
typedef enum STATEUI_CLOSED_ENUM {
    StateUIFactsDevice,
    StateUIFactsApplication,
    StateUIFactsLocale,
    StateUIFactsBattery,
    StateUIFactsConnectivity,
    StateUIFactsTheme,
    StateUIFactsDisplay,
    StateUIFactsAccessibility,
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
/// Whether WinUI's frames are subscribed to now. What a test reads.
bool stateui_winui_holds_frames(void);

/// Takes a reference of the host's own to a handle, which the host lets go of as it lets go of its own; the handle.
StateUIObjectRef stateui_winui_retain(StateUIObjectRef object);

/// Lets go of a handle.
void stateui_winui_release(StateUIObjectRef object);

/// A window, its activation and its minimizing told through `windowStateChanged` under the number `window`.
StateUIObjectRef stateui_winui_window_make(int64_t window);
void stateui_winui_window_set_title(StateUIObjectRef window, char const *title);
void stateui_winui_window_set_content(StateUIObjectRef window, StateUIObjectRef content);

/// The window's chrome across its top, its menu bar and the row of tabs beneath it; null for none. The first chrome
/// given also takes the window's way back: the mouse's back button, Alt+Left and the Back key choose its way back
/// (-1).
void stateui_winui_window_set_chrome(StateUIObjectRef window, StateUIObjectRef titleBar, StateUIObjectRef menuBar,
                                     StateUIObjectRef tabs);
void stateui_winui_window_activate(StateUIObjectRef window);
void stateui_winui_window_close(StateUIObjectRef window);
/// Hides the window, or shows it again without activating it.
void stateui_winui_window_set_shown(StateUIObjectRef window, bool shown);
/// Minimizes or restores the window as its buttons do: `ShowWindow` with `command`. What a test does.
void stateui_winui_window_show_as_user(StateUIObjectRef window, int32_t command);

/// Moves or sizes the window where `has` says, each alone: `values` are x and y from the corner of the screen's work
/// area and the width and height of its content, in DIPs.
void stateui_winui_window_set_frame(StateUIObjectRef window, bool const *has, double const *values);

/// The least and the greatest size of the window's content in DIPs: least width, least height, greatest width,
/// greatest height, 0 for none.
void stateui_winui_window_set_limits(StateUIObjectRef window, double const *limits);

/// What the window is: whether the user may maximize and minimize it, and whether it floats over the application's
/// other windows.
void stateui_winui_window_set_traits(StateUIObjectRef window, bool maximizable, bool minimizable, bool floats);

/// Shows the desktop through the window in the desktop acrylic where `blurred` - of the thin kind or the base one,
/// in the theme's color `argb`, its luminosity hiding `opacity` of the desktop and its tint `tintOpacity` - else in
/// Mica, the desktop's tint.
void stateui_winui_window_set_backdrop(StateUIObjectRef window, bool blurred, bool thin, float opacity,
                                       float tintOpacity, uint32_t argb);

/// Whether the window shows the desktop acrylic, of the kind and at the luminosity's opacity it reads into `thin` and
/// `opacity`; false where it shows Mica.
bool stateui_winui_window_acrylic(StateUIObjectRef window, bool *thin, float *opacity);

/// Paints the window behind its pages in `argb` - the backdrop through it where the color lets it - or leaves it
/// WinUI's own where `written` is false.
void stateui_winui_window_set_background(StateUIObjectRef window, bool written, uint32_t argb);

/// Clears the card a navigation view lays over its detail in the window where `clear` is true, so the detail shows the
/// window's background as the sidebar does, the card's edge the theme's divider; leaves WinUI's own card where it is
/// false.
void stateui_winui_window_clear_detail(StateUIObjectRef window, bool clear);

/// The color the window shows behind its pages, as ARGB; false where it shows WinUI's own.
bool stateui_winui_window_background(StateUIObjectRef window, uint32_t *argb);

/// Shows the window in a theme, a `StateUIColorScheme`.
void stateui_winui_window_set_theme(StateUIObjectRef window, int32_t scheme);

/// The theme the window shows in now, light or dark, a `StateUIColorScheme`.
int32_t stateui_winui_window_actual_theme(StateUIObjectRef window);

/// What a test reads of a window, into 13 values: x, y, width, height, the four limits in the order they are set,
/// maximizable, minimizable, acrylic, floating and shown as 1 or 0.
void stateui_winui_window_frame(StateUIObjectRef window, double *values);

/// The window's name the system shows - the taskbar's, Alt+Tab's - in UTF-8, as far as `capacity` goes; answers its
/// length.
int32_t stateui_winui_window_system_title(StateUIObjectRef window, char *utf8, int32_t capacity);

/// Makes the element fill whatever place it is arranged in, whatever its style aligns it to: a StateUI layout
/// decides its place.
void stateui_winui_fill_place(StateUIObjectRef element);

/// Stands `replacement` where `element` stands in its parent - a panel's child, a border's, or a content control's
/// content - and takes `element` out; nothing where it stands in none.
void stateui_winui_replace(StateUIObjectRef element, StateUIObjectRef replacement);

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

/// A control's IsEnabled; a view that is no control keeps none, and nothing is done.
void stateui_winui_set_enabled(StateUIObjectRef control, bool enabled);

/// What an element is drawn over, under its whole frame; none for WinUI's own: a control's Background and the theme
/// resources its template paints its container, field or face from, a panel's Background; nothing for any other.
void stateui_winui_set_background(StateUIObjectRef element, StateUIBrush background);

/// Cuts what the element shows to `outline` over `width` by `height` DIPs; `cuts` false shows it whole.
void stateui_winui_set_clip(StateUIObjectRef element, bool cuts, StateUIOutline outline, double radius,
                            double width, double height);

/// Whether the element takes clicks and touches; one that does not lets them through to what is behind it.
void stateui_winui_set_hit_testable(StateUIObjectRef element, bool testable);

/// Where the element is drawn among its panel's children: a higher one over a lower, equal ones in order.
void stateui_winui_set_z_index(StateUIObjectRef element, int32_t z);

/// The direction the element lays itself out and writes in, which what stands in it inherits: right to left, or
/// left to right.
void stateui_winui_set_flow_direction(StateUIObjectRef element, bool rightToLeft);

/// Tips the element as it is drawn after its transform: `matrix` the sixteen numbers of a 4 x 4 matrix, row by
/// row, applied to a point (x, y, 0, 1) of the element and divided by the fourth; null for no tip.
void stateui_winui_set_projection(StateUIObjectRef element, const double *matrix);

/// The tip the element is drawn with, its matrix's sixteen numbers into `matrix`; false where it has none.
bool stateui_winui_projection(StateUIObjectRef element, double *matrix);

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

/// Whether the element shows: it and everything around it visible, up to the content of the window it stands in, or
/// of an open popup over it.
bool stateui_winui_is_shown(StateUIObjectRef element);

/// A control's IsEnabled as WinUI holds it; true for an element that is no control.
bool stateui_winui_is_enabled(StateUIObjectRef element);

/// Whether the user leaves Windows' animations on.
bool stateui_winui_animations_enabled(void);

/// The words a text block or a button's caption shows, in UTF-8; the length they need, their end not counted.
int32_t stateui_winui_text(StateUIObjectRef element, char *utf8, int32_t capacity);

/// The words WinUI shows over the element while the pointer rests on it, in UTF-8 - null shows none - and the
/// words it holds, the length they need returned, their end not counted.
void stateui_winui_set_tooltip(StateUIObjectRef element, char const *utf8);

/// A control's keyboard shortcut - a virtual key, 0 for none, the VirtualKeyModifiers held with it, and whether it
/// gives way to a field being typed into - and the shortcut it holds, whether it holds one; and a key with its
/// modifiers sent as the system sends keys.
void stateui_winui_set_shortcut(StateUIObjectRef element, int32_t key, int32_t modifiers, bool givesWayToTyping);
bool stateui_winui_shortcut(StateUIObjectRef element, int32_t *key, int32_t *modifiers);
void stateui_winui_send_keys(int32_t key, int32_t modifiers);
int32_t stateui_winui_tooltip(StateUIObjectRef element, char *utf8, int32_t capacity);

StateUIObjectRef stateui_winui_panel_make(int64_t view);
void stateui_winui_panel_set_children(StateUIObjectRef panel, StateUIObjectRef const *children, int32_t count);
/// How a child the panel is given enters: WinUI's entrance from `offset` DIPs across, toward its place; 0 for none.
void stateui_winui_panel_set_entrance(StateUIObjectRef panel, double offset);

/// What stands in a stack beside its controls: a separator, a panel holding a line in the theme's divider stroke, one
/// pixel thick both ways.
StateUIObjectRef stateui_winui_separator_make(void);

/// How words look on a text block or any control showing them: the font - a size of 0 or less, a weight of 0 and
/// an empty family are the platform's, a weight 100 to 900, `tabularDigits` every digit as wide as the others - the
/// color as 0xAARRGGBB and the room around them in DIPs, each with `has` false putting back the platform's.
void stateui_winui_set_font(
    StateUIObjectRef element, double size, int32_t weight, bool italic, bool tabularDigits, char const *family);
void stateui_winui_set_foreground(StateUIObjectRef element, bool has, uint32_t argb);
void stateui_winui_set_padding(StateUIObjectRef element, bool has, double left, double top, double right, double bottom);

/// The room between the letters of a text block's or a control's words, in thousandths of an em.
void stateui_winui_set_character_spacing(StateUIObjectRef element, int32_t thousandths);

/// Whether a text block's or a control's words grow with the user's text size, written and read back.
void stateui_winui_set_text_scales(StateUIObjectRef element, bool scales);
bool stateui_winui_text_scales(StateUIObjectRef element);

/// How words look, as WinUI holds it: the size, the weight, the most lines, the alignment and the color as
/// 0xAARRGGBB - five values; what a test reads back.
void stateui_winui_text_style(StateUIObjectRef element, double *style);

StateUIObjectRef stateui_winui_text_make(void);
/// What a label is drawn over: a color, a gradient, or none - still hit across its bounds.
void stateui_winui_text_set_background(StateUIObjectRef label, StateUIBrush background);

/// Where a label's words stand across its height, a `StateUITextAlignment`: at its top, middle or bottom.
void stateui_winui_text_set_vertical(StateUIObjectRef label, int32_t vertical);

/// Whether the user can select a label's words and copy them.
void stateui_winui_text_set_selectable(StateUIObjectRef label, bool selectable);

void stateui_winui_text_set_text(StateUIObjectRef text, char const *utf8);

/// One run of a label's words, and how it differs from the label's: its color and its background where it has
/// them, as 0xAARRGGBB; its size in DIPs, 0 for the label's; its weight 100 to 900, 0 for the label's; italic, its
/// digits all as wide, and lines under or through it; its font
/// family, empty for the label's; and the space between its letters in thousandths of an em of its size.
typedef struct {
    char const *text;
    uint32_t color;
    uint32_t background;
    double size;
    bool hasColor;
    bool hasBackground;
    int32_t weight;
    bool italic;
    bool tabularDigits;
    bool underline;
    bool strikethrough;
    char const *family;
    int32_t spacing;
} StateUIWordsRun;

/// Shows `runs`, in order, as the text block's words, each as it says, in place of its words.
void stateui_winui_text_set_runs(StateUIObjectRef text, StateUIWordsRun const *runs, int32_t count);

/// The runs a text block shows, six values each - its color as 0xAARRGGBB or 0, its size or 0, its weight, 1 for
/// italic and 2 for digits all as wide, its lines (1 under, 2 through), its background or 0 - into `values` as far as `capacity` goes; answers
/// how many runs it shows. What a test reads back.
int32_t stateui_winui_text_runs(StateUIObjectRef text, double *values, int32_t capacity);

/// A label's lines - whether the words wrap, the most lines, 0 for any, and whether words that do not fit are cut
/// with an ellipsis - its words' alignment across it, a `StateUITextAlignment` - the space between its letters in
/// thousandths of an em, the height of a line in DIPs, 0 for the font's, and the lines under or through its words.
void stateui_winui_text_set_lines(StateUIObjectRef text, bool wraps, int32_t lines, bool trims);
void stateui_winui_text_set_alignment(StateUIObjectRef text, int32_t horizontal);
void stateui_winui_text_set_spacing(StateUIObjectRef text, int32_t tracking, double lineHeight);
void stateui_winui_text_set_decorations(StateUIObjectRef text, bool underline, bool strikethrough);

/// A button of `kind`: WinUI's Button - opening its flyout, or holding its context menu, where it is given one - its
/// DropDownButton opening its flyout, an arrow saying so, its SplitButton - its click its own and its flyout behind
/// the arrow - or its HyperlinkButton, holding no address: what its click opens is the caller's to open.
StateUIObjectRef stateui_winui_button_make(int64_t view, StateUIButtonKind kind);

/// A button's menu, written as a context menu is (`stateui_winui_set_context_menu`): the flyout a Button, a
/// DropDownButton or a SplitButton opens.
void stateui_winui_button_set_menu(StateUIObjectRef button, int64_t view, int32_t const *kinds,
                                   char const *const *titles, bool const *enabled, char const *const *identifiers,
                                   char const *const *icons, bool const *destructive, int32_t const *keys,
                                   int32_t const *modifiers, bool const *givesWay, int32_t count);

/// A button's look: what fills it - the platform's for none, kept `underPointer` and `pressed` of its opacity under
/// the pointer and pressed - its outline `lineWidth` DIPs wide, and its corners' radius, less than 0 for the
/// platform's; or, `drawsOval`, an oval `width` by `height` DIPs holding its fill and its outline.
void stateui_winui_button_set_look(StateUIObjectRef button, StateUIBrush background, StateUIBrush stroke,
                                   double lineWidth, double cornerRadius, bool drawsOval, double width,
                                   double height, double underPointer, double pressed);

/// What a button shows: its words - wrapped onto more lines or cut short with an ellipsis where they do not fit,
/// else on one line - and the picture the first of the files `icons` names that the pictures hold (each ended by
/// a line feed, empty for none): beside the words - StateUI's IconPosition, `spacing` DIPs apart, a negative one
/// WinUI Gallery's gap - at its own size, or alone, filling the room inside the padding as StateUI's ContentMode says.
void stateui_winui_button_set_content(StateUIObjectRef button, char const *words, char const *icons,
                                      int32_t position, double spacing, int32_t aspect, bool wraps, bool trims);
/// Bounds the picture beside a button's words to the room a button `height` DIPs tall keeps for it, inside its
/// padding and outline; no bound for 0. WinUI arranges a button at no less than it measured, and StateUI measures
/// it with no bound on its height: a button placed lower than its picture would show the words cut.
void stateui_winui_button_set_room(StateUIObjectRef button, double height);
/// Puts other words on a button that shows some, in the place they stand.
void stateui_winui_button_set_words(StateUIObjectRef button, char const *words);

/// A window's main action: WinUI's accent button style where `accent`, the platform's plain one else; and whether a
/// button wears it - what a test reads.
void stateui_winui_button_set_accent(StateUIObjectRef button, bool accent);
bool stateui_winui_button_accent(StateUIObjectRef button);
/// Whether a button's words stand in the theme's critical color where the tree colors them not, and whether they do.
void stateui_winui_button_set_critical(StateUIObjectRef button, bool critical);
bool stateui_winui_button_critical(StateUIObjectRef button);

/// Puts a control in its template's visual state `state` - "PointerOver", "Pressed", "Normal" - as the pointer
/// would; whether the template has it. What a test does.
bool stateui_winui_go_to_state(StateUIObjectRef control, char const *state);

/// Presses a button as UI Automation does, which raises its Click.
void stateui_winui_button_invoke(StateUIObjectRef button);

/// A control's one accent color, `argb`, where `tinted`, and the platform's accent otherwise: a check box's tick,
/// a switch's track while it is on, a slider's thumb and the track behind it, a picker's chosen choice in its list, a
/// progress bar and a spinner - kept `underPointer` and `pressed` of its opacity under the pointer and pressed.
void stateui_winui_set_tint(StateUIObjectRef control, uint32_t argb, bool tinted, double underPointer,
                            double pressed);

/// What a test reads: how many times a control's theme was read again, so its template took resources written into
/// the control.
int32_t stateui_winui_themes_read_again(void);

/// A sheet: a card over a veil across its window, holding a presented page under the head of the bar a stack in it
/// brings - its way back (chosen on `view` as -1), its title and its close button (-2), each where shown - as large
/// as its page where it `fits`, else at its standard size, within `room` (the least width and height, then the
/// standard's) and the window; a window's sheets, a sheet pushed over those before it and taking the keyboard, the
/// top one popped. Escape takes the top one away, chosen on the window's chrome as -3.
StateUIObjectRef stateui_winui_sheet_make(int64_t view);
void stateui_winui_sheet_set(
    StateUIObjectRef sheet, char const *title, StateUIObjectRef page, bool back, bool close, char const *backWords,
    char const *closeWords, bool fits, double const *room);
/// The page's actions on the sheet's head - at its leading edge after the way back, at its trailing edge before the
/// close button, and behind "more" - and an action's menu, as the title bar's are
/// (`stateui_winui_title_bar_set_actions`, `stateui_winui_title_bar_set_action_menu`), a press chosen on `view` by its
/// place.
void stateui_winui_sheet_set_actions(StateUIObjectRef sheet, char const *const *texts, char const *const *identifiers,
                                     char const *const *icons, bool const *words, bool const *destructive,
                                     int32_t const *groups, int32_t leadingGroups, bool const *enabled,
                                     int32_t const *keys, int32_t const *modifiers, bool const *givesWay,
                                     int32_t const *states, int32_t count);
void stateui_winui_sheet_set_action_menu(StateUIObjectRef sheet, int32_t place, bool held, int32_t first,
                                         int32_t const *kinds, char const *const *titles, bool const *enabled,
                                         char const *const *identifiers, char const *const *icons,
                                         bool const *destructive, int32_t const *keys, int32_t const *modifiers,
                                         bool const *givesWay, int32_t count);
void stateui_winui_window_push_sheet(StateUIObjectRef window, StateUIObjectRef sheet);
void stateui_winui_window_pop_sheet(StateUIObjectRef window);

/// Lays `overlays` over the window's page and its sheets, where the page stands, the first lowest; a click beside
/// what they hold goes on to them. None takes the layer away.
void stateui_winui_window_set_overlays(StateUIObjectRef window, StateUIObjectRef const *overlays, int32_t count);

/// How many sheets a window shows - what a test reads.
int32_t stateui_winui_window_sheets(StateUIObjectRef window);

/// A view's context menu: `count` entries, each of its `StateUIMenuEntry` kind, with its caption, whether it can be chosen, the identifier automation finds it by (empty for none), the files its
/// picture may stand in - each ended by a line feed, empty for none - whether choosing it destroys something, and an
/// item's shortcut, its key 0 for none (`stateui_winui_set_shortcut`), shown beside it; an item's choice told through
/// `menuChosen` by its place among the items. None takes the menu away.
void stateui_winui_set_context_menu(StateUIObjectRef element, int64_t view, int32_t const *kinds,
                                    char const *const *titles, bool const *enabled, char const *const *identifiers,
                                    char const *const *icons, bool const *destructive, int32_t const *keys,
                                    int32_t const *modifiers, bool const *givesWay, int32_t count);

/// A window's menu bar: WinUI's MenuBar, written as a context menu is, each menu at the top one of the bar's own, an
/// item's shortcut pressing it while the window is in front.
StateUIObjectRef stateui_winui_menu_bar_make(int64_t view);
void stateui_winui_menu_bar_set(StateUIObjectRef bar, int64_t view, int32_t const *kinds, char const *const *titles,
                                bool const *enabled, char const *const *identifiers, char const *const *icons,
                                bool const *destructive, int32_t const *keys, int32_t const *modifiers,
                                bool const *givesWay, int32_t count);

/// Paints a menu bar as one of the window's bars: its background, its menus' words, the theme it stands in - a
/// `StateUIColorScheme` - and the platform's own again where none is given.
void stateui_winui_menu_bar_set_colors(StateUIObjectRef bar, bool hasBackground, uint32_t background,
                                        bool hasForeground, uint32_t foreground, int32_t theme);

/// A view's context menu, or a bar's menus, as a test reads them: items by caption, "!" before one that cannot be
/// chosen, "-" a separator, a submenu's entries - and a bar's menu's - in brackets after its caption, ";" between -
/// in UTF-8; the length it needs.
int32_t stateui_winui_menus(StateUIObjectRef element, char *utf8, int32_t capacity);

/// Chooses the item at `index` among those menus' items, submenus' included, as assistive technology does.
void stateui_winui_menus_choose(StateUIObjectRef element, int32_t index);

/// What those menus' items, submenus' included, hold of `what` - "identifier" the one automation finds each by, "icon"
/// the file its picture shows, "destructive" 1 where its words stand in the theme's critical color, "shortcut" its
/// accelerator's key and modifiers, "," between - in their order, ";" between, in UTF-8: what a test reads; the
/// length it needs.
int32_t stateui_winui_menus_items(StateUIObjectRef element, char const *what, char *utf8, int32_t capacity);

/// A picker as its `StateUIPickerPresentation` says: WinUI's ComboBox, a SelectorBar of segments or RadioButtons - its
/// choices, the one chosen (-1 for none, written only where `writeSelected`) told through `chosen`; a ComboBox's
/// placeholder while none is, its choices across it (a `StateUITextAlignment`), and its list opening and closing told through
/// `presented`.
StateUIObjectRef stateui_winui_picker_make(int64_t view, int32_t kind);
void stateui_winui_picker_set_options(StateUIObjectRef picker, char const *const *options, int32_t count);
void stateui_winui_picker_set(StateUIObjectRef picker, int32_t selected, bool writeSelected, char const *title);
void stateui_winui_picker_set_alignment(StateUIObjectRef picker, int32_t alignment);
void stateui_winui_picker_set_open(StateUIObjectRef picker, bool open);
bool stateui_winui_picker_is_open(StateUIObjectRef picker);
int32_t stateui_winui_picker_selected(StateUIObjectRef picker);

/// The choices the picker holds, in UTF-8, each on a line of its own, as far as `capacity` goes; the length they need.
int32_t stateui_winui_picker_choices(StateUIObjectRef picker, char *utf8, int32_t capacity);

/// Opens or closes the list as UI Automation does, and chooses as the user does, outside the program's write - what
/// a test does.
void stateui_winui_picker_open_as_user(StateUIObjectRef picker, bool open);
void stateui_winui_picker_choose_as_user(StateUIObjectRef picker, int32_t index);

/// A day: WinUI's CalendarDatePicker, its day (none where not `hasDate`), its bounds (null for WinUI's own), its day
/// written short or long in the user's own way, and its calendar, whose opening and closing are told through
/// `presented`; the user's day told through `picked`.
StateUIObjectRef stateui_winui_date_make(int64_t view);
void stateui_winui_date_set(StateUIObjectRef picker, bool hasDate, int32_t year, int32_t month, int32_t day);
void stateui_winui_date_set_range(StateUIObjectRef picker, int32_t const *earliest, int32_t const *latest);
void stateui_winui_date_set_format(StateUIObjectRef picker, bool longForm);
void stateui_winui_date_set_open(StateUIObjectRef picker, bool open);
bool stateui_winui_date_is_open(StateUIObjectRef picker);

/// The day it shows, as year, month and day; whether it shows one.
bool stateui_winui_date(StateUIObjectRef picker, int32_t *parts);

/// A time of day: WinUI's TimePicker in the user's clock, its time (none where not `hasTime`); the user's time told
/// through `picked`.
StateUIObjectRef stateui_winui_time_make(int64_t view);
void stateui_winui_time_set(StateUIObjectRef picker, bool hasTime, int32_t hour, int32_t minute);

/// The time it shows, as hour and minute; whether it shows one.
bool stateui_winui_time(StateUIObjectRef picker, int32_t *parts);

/// Picks as the user does, outside the program's write - what a test does.
void stateui_winui_date_pick_as_user(StateUIObjectRef picker, int32_t year, int32_t month, int32_t day);
void stateui_winui_time_pick_as_user(StateUIObjectRef picker, int32_t hour, int32_t minute);

/// What shows work: a progress bar, how far along from 0 to 1 as the host keeps it, and a spinner, turning while its
/// work runs.
StateUIObjectRef stateui_winui_progress_bar_make(void);
void stateui_winui_progress_bar_set(StateUIObjectRef bar, double progress);
double stateui_winui_progress_bar_value(StateUIObjectRef bar);
StateUIObjectRef stateui_winui_progress_ring_make(void);
void stateui_winui_progress_ring_set_running(StateUIObjectRef ring, bool running);
bool stateui_winui_progress_ring_running(StateUIObjectRef ring);

/// The controls that are on or off - a switch and a check box - each telling its turn through `toggled`.
StateUIObjectRef stateui_winui_switch_make(int64_t view);
StateUIObjectRef stateui_winui_check_box_make(int64_t view);

/// The words a switch says over its track or a check box beside its box - none where empty - and their color,
/// `argb`, where `has`; the platform's where not.
void stateui_winui_toggle_set_words(StateUIObjectRef toggle, char const *utf8, bool has, uint32_t argb);
void stateui_winui_toggle_set_on(StateUIObjectRef toggle, bool on);

bool stateui_winui_toggle_is_on(StateUIObjectRef toggle);

/// Turns a control as UI Automation does, which the user's turn is: a switch or a check box toggled.
void stateui_winui_toggle_press(StateUIObjectRef toggle);

StateUIObjectRef stateui_winui_slider_make(int64_t view);

/// The range from `lower` to `upper` and its steps - an arrow key's, Page Up's and the one a drag lands on - then the
/// value, kept inside the range.
void stateui_winui_slider_set(StateUIObjectRef slider, double value, double lower, double upper, double key,
                              double page, double drag);
double stateui_winui_slider_value(StateUIObjectRef slider);

/// The slider's steps as WinUI holds them - an arrow key's, Page Up's and a drag's: three values.
void stateui_winui_slider_steps(StateUIObjectRef slider, double *steps);

/// A stepper: WinUI's NumberBox, its spin buttons beside its number; the range from `lower` to `upper`, the value
/// kept inside it, a step a spin button's and an arrow key's, and `fractionDigits` decimals written in the user's
/// own way.
StateUIObjectRef stateui_winui_stepper_make(int64_t view);
void stateui_winui_stepper_set(StateUIObjectRef stepper, double value, double lower, double upper, double step,
                               int32_t fractionDigits);
double stateui_winui_stepper_value(StateUIObjectRef stepper);

/// Presses a stepper's spin button, up or down, as UI Automation does - what a test does.
void stateui_winui_stepper_step_as_user(StateUIObjectRef stepper, bool up);

/// Enters `utf8` in a stepper's box as the user does, the box reading them as Enter has it - what a test does.
void stateui_winui_stepper_enter_as_user(StateUIObjectRef stepper, char const *utf8);

/// Moves a slider's or a stepper's value as UI Automation does, which the user's move is.
void stateui_winui_value_move(StateUIObjectRef control, double value);

/// The words the user types, each change told through `textChanged`: a field on one line, whose Enter is
/// `submitted`, and one holding a password; an editor of several lines, whose Enter starts a new one; a search box,
/// whose query is `submitted`.
StateUIObjectRef stateui_winui_field_make(int64_t view);
StateUIObjectRef stateui_winui_password_make(int64_t view);
StateUIObjectRef stateui_winui_editor_make(int64_t view);
StateUIObjectRef stateui_winui_search_make(int64_t view);
void stateui_winui_field_set_text(StateUIObjectRef field, char const *utf8);
void stateui_winui_field_set_placeholder(StateUIObjectRef field, char const *utf8);

/// How a field or an editor takes words: read only, spell checked, predicting the next word, and its input scope
/// (a `StateUIInputScope`), which picks the keyboard a screen offers.
void stateui_winui_field_set_behavior(StateUIObjectRef field, bool readOnly, bool spellChecked, bool predicted,
                                       int32_t scope);

/// The case a field's or an editor's typing takes, a `StateUITextCase`.
void stateui_winui_field_set_casing(StateUIObjectRef field, int32_t textCase);

/// How a search box takes words: read only, the case its typing takes (a `StateUITextCase`), the words typed across
/// it as `stateui_winui_field_set_look` has them, and how typing is checked, predicted and keyed.
void stateui_winui_search_set_box(StateUIObjectRef search, bool readOnly, int32_t textCase, int32_t alignment,
                                  bool spellChecked, bool predicted, int32_t scope);

/// A search box's placeholder in `argb` where `colored`, else the theme's.
void stateui_winui_search_set_placeholder_color(StateUIObjectRef search, uint32_t argb, bool colored);

/// Its words across it (StateUI's `TextAlignment`) and its placeholder's color, the platform's where not
/// `placeholderColored`.
void stateui_winui_field_set_look(StateUIObjectRef field, int32_t alignment, uint32_t placeholderArgb,
                                  bool placeholderColored);

/// Puts the caret `start` characters in and selects `length` from it, both kept inside the words.
void stateui_winui_field_select(StateUIObjectRef field, int32_t start, int32_t length);

/// Does an Edit menu's own entry to the field - undo 0, redo 1, cut 2, copy 3, paste 4, delete 5, select all 6 - which
/// takes the focus back; a password box only pastes and selects all.
void stateui_winui_field_edit(StateUIObjectRef field, int32_t command);

/// What a test reads of a field, an editor or a search box's text box: read only, spell checked, predicting, its input scope's first name
/// (-1 for none), its words' alignment, its selection's start and length, whether its placeholder is colored,
/// whether Enter starts a new line - nine values.
void stateui_winui_field_facts(StateUIObjectRef field, int32_t *facts);

/// Types in a search box as the user does, into the text box its template holds - what a test does.
void stateui_winui_search_type(StateUIObjectRef search, char const *utf8);

/// Submits a search box's query as UI Automation does, its own button's way - what a test does.
void stateui_winui_search_submit_as_user(StateUIObjectRef search);

/// A shape drawn behind a layout's children: a rectangle, rounded or not, or an ellipse, filled and outlined.
StateUIObjectRef stateui_winui_shape_make(StateUIOutline outline);
void stateui_winui_shape_set(StateUIObjectRef shape, double radius, StateUIBrush fill, StateUIBrush stroke,
                             double lineWidth);

/// A shape: one WinUI Path, drawn by `stateui_winui_path_draw` and painted by `stateui_winui_path_paint`.
StateUIObjectRef stateui_winui_path_make(int64_t view);

/// Paints a shape: its fill and outline, the outline's width, its dashes and their offset in outline widths, its ends
/// (StateUI's LineCap), its joins (LineJoin) and how far a mitred join may reach.
void stateui_winui_path_paint(StateUIObjectRef path, StateUIBrush fill, StateUIBrush stroke, double width,
                              double const *dashes, int32_t dashCount, double dashOffset, int32_t cap, int32_t join,
                              double miter);

/// The bounds of the geometry `commands` draw, as `stateui_winui_path_draw` takes them, as WinUI measures it: its
/// x, y, width and height into `bounds`, all 0 for a geometry that draws nothing.
void stateui_winui_path_bounds(double const *commands, int32_t count, double *bounds);

/// Draws a shape's `figure` in a room `width` by `height` DIPs: a rectangle, its corners' `radii` clockwise from the
/// top left, or an ellipse, both drawn `inset` from the room's edges; or the geometry `commands` draw - flat, each a
/// `StateUICurve` and its points - filled by `evenOdd`'s rule. Each is
/// moved by `placement` (a b c d tx ty) where one is given: a figure's places it in the room, a rectangle's and an
/// ellipse's is their transform.
void stateui_winui_path_draw(StateUIObjectRef path, StateUIFigureKind figure, double const *radii, double const *commands,
                             int32_t count, bool evenOdd, double const *placement, double width, double height,
                             double inset);

/// A canvas: a panel its drawing is replayed on, again for each size and scale it is shown at; a press on it is
/// told through `canvasPressed` for the view `view`.
StateUIObjectRef stateui_winui_canvas_make(int64_t view);

/// The canvas's drawing, as StateUI's `HostDrawing` lays it out: each instruction's kind and whole numbers in
/// `ints`, its numbers in `numbers`, and its text in `words`, `wordCount` UTF-8 runs of `lengths` bytes end to end.
void stateui_winui_canvas_draw(StateUIObjectRef canvas, int32_t const *ints, int32_t intCount, double const *numbers,
                               int32_t numberCount, char const *words, int32_t const *lengths, int32_t wordCount);

/// The color, ARGB, the canvas is filled with under its drawing - its surface is its panel's own background, so a
/// view's background is painted there; 0 for none.
void stateui_winui_canvas_set_ground(StateUIObjectRef canvas, uint32_t argb);

/// The color the canvas is filled with under its drawing, ARGB; 0 for none - what a test reads.
uint32_t stateui_winui_canvas_ground(StateUIObjectRef canvas);

/// Renders the element and reads the color, as ARGB, at each of `count` points given as x and y in DIPs of it -
/// what a test reads of the screen; whether it rendered.
bool stateui_winui_pixels(StateUIObjectRef element, double const *points, int32_t count, uint32_t *argb);

/// A ScrollView's scroller: a ScrollViewer around `content`, scrolling the ways its `StateUIScrollOrientation` says;
/// each bar shown as its `StateUIScrollIndicatorVisibility` says.
StateUIObjectRef stateui_winui_scroller_make(int64_t view);
void stateui_winui_scroller_set(StateUIObjectRef scroller, StateUIObjectRef content, int32_t orientation,
                                int32_t verticalBar, int32_t horizontalBar);

/// Moves the scroller's view to `x`, `y` DIPs at once; the scroller keeps it within what it can reach, and says where
/// it stands through `scrolled` once it has moved.
void stateui_winui_scroller_move(StateUIObjectRef scroller, double x, double y);

/// Where the scroller's view stands, then the farthest it reaches across and down, in DIPs: four values.
void stateui_winui_scroller_offset(StateUIObjectRef scroller, double *offset);

/// A view's popover: WinUI's Flyout holding `content`, a closing of WinUI's accord - a click beside it, Escape -
/// told through `presented` as the view numbered `view`'s.
StateUIObjectRef stateui_winui_popover_make(int64_t view, StateUIObjectRef content);

/// Shows the popover by `anchor`, once the anchor is loaded.
void stateui_winui_popover_show(StateUIObjectRef popover, StateUIObjectRef anchor);

/// Takes the popover away as the program asks: nobody hears it.
void stateui_winui_popover_close(StateUIObjectRef popover);

/// Whether the popover shows.
bool stateui_winui_popover_is_open(StateUIObjectRef popover);

/// Hides the popover as a click beside it does, told through `presented`.
void stateui_winui_popover_hide(StateUIObjectRef popover);

/// A scroller's pull to refresh: WinUI's RefreshContainer, a pull of which is told through `refreshPulled` as the
/// view numbered `view`'s and held until the refresh ends.
StateUIObjectRef stateui_winui_refresh_make(int64_t view);

/// Stands `content` - a scroller, or null for none - in the container, and its refresh under way or not: one the
/// program begins is heard by nobody; ending it ends the user's too.
void stateui_winui_refresh_set(StateUIObjectRef refresh, StateUIObjectRef content, bool refreshing);

/// Whether the container holds a scroller - the pull offered.
bool stateui_winui_refresh_holds(StateUIObjectRef refresh);

/// Whether the container's spinner shows a refresh under way.
bool stateui_winui_refresh_refreshing(StateUIObjectRef refresh);

/// Asks the container for a refresh as a pull does, told through `refreshPulled`.
void stateui_winui_refresh_request(StateUIObjectRef refresh);

/// An ItemsView: WinUI's ItemsView over the identities the host gives it; the cell of each entry is the host's
/// (`itemCell`, `itemHeld`, `itemLetGo`), and what stands in view, the user's choice and an item invoked are told.
StateUIObjectRef stateui_winui_items_make(int64_t view);

/// How many sets of handlers hang on the list's scroller, which tell what stands in view - what a test counts.
int32_t stateui_winui_items_scroller_handlers(StateUIObjectRef list);

/// The identities, each with its `StateUIItemKind`, and the changes from the ones before: runs of places
/// removed, last first, then runs inserted, first first, each a start and a count. Asked while the list lays its
/// cells out, the relay applies them once it is done, in order.
void stateui_winui_items_set_entries(StateUIObjectRef items, char const *const *identities, int32_t const *kinds,
                                     int32_t count, int32_t const *removed, int32_t removedCount,
                                     int32_t const *inserted, int32_t insertedCount);

/// How the entries stand - in columns at least `minimumItemWidth` DIPs wide for a grid - `spacing` DIPs apart.
void stateui_winui_items_set_layout(StateUIObjectRef items, StateUIItemsShape shape, double spacing, double minimumItemWidth);

/// How many items the user may choose - none (0), one (1), many (2) - the identities chosen, and whether an item is
/// invoked.
void stateui_winui_items_set_choice(StateUIObjectRef items, int32_t mode, char const *const *chosen, int32_t count,
                                    bool invokable);

/// Brings the entry at `index` into view: at the start (0), the center (1), the end (2), or the nearest edge (3).
void stateui_winui_items_scroll_to(StateUIObjectRef items, int32_t index, int32_t anchor, bool animated);

/// The ItemsView left: nothing waits, and every cell is let go.
void stateui_winui_items_release(StateUIObjectRef items);

/// What a test reads: the identities the list holds chosen, joined by newlines; the length it needs.
int32_t stateui_winui_items_chosen(StateUIObjectRef items, char *utf8, int32_t capacity);

/// What a test reads: how many items the user may choose, as `set_choice` numbers it.
int32_t stateui_winui_items_mode(StateUIObjectRef items);

/// What a test does as the user's click on the entry at `index`: where many may be chosen it takes the item or lets it
/// go, else it takes it alone; the choice is told as the user's.
void stateui_winui_items_choose_as_user(StateUIObjectRef items, int32_t index);

/// What a test does as the user opens the item a cell holds: its container's Invoke, as Narrator's; false where there
/// is none.
bool stateui_winui_items_invoke_as_user(StateUIObjectRef cell);

/// What a test does as the user scrolls the list to `x`, `y` DIPs, unanimated: the list's view stands there once
/// WinUI's compositor has moved it, a moment later.
void stateui_winui_items_scroll_as_user(StateUIObjectRef items, double x, double y);

/// Where the list's view stands, then the farthest it reaches across and down, in DIPs: four values.
void stateui_winui_items_offset(StateUIObjectRef items, double *offset);

/// Names the row holding the cell numbered `cell` `words`: what Narrator reads of it, which reads no further.
void stateui_winui_items_name(StateUIObjectRef items, int64_t cell, char const *words);

/// What a test reads: what Narrator calls the row holding the cell numbered `cell`; the length it needs.
int32_t stateui_winui_items_row_name(StateUIObjectRef items, int64_t cell, char *utf8, int32_t capacity);

/// A window's chrome: WinUI's TitleBar, its way back and its sidebar's toggle, the title, the page's actions at its
/// edges or in its overflow, and the title view in its middle. The way back is chosen as -1, the toggle as -2, an
/// action by its place.
StateUIObjectRef stateui_winui_title_bar_make(int64_t view);
/// `foreground` is the color of the words on a bar the tree paints, its title's and its actions' alike; the bar
/// stands in `theme`, a `StateUIColorScheme` - dark for light words on a dark bar - its buttons and commands with it.
void stateui_winui_title_bar_set(StateUIObjectRef bar, char const *title, char const *subtitle, char const *icon,
                                 bool back, bool paneToggle, bool hasBackground, uint32_t background,
                                 bool hasForeground, uint32_t foreground, int32_t theme);
/// The page's actions on a window's chrome, in reading order: each one's words, the identifier automation finds it
/// by (empty for none), the files its picture may stand in - each ended by a line feed, empty for none - whether its
/// words stand beside its picture, whether choosing it destroys something, its group's place - the first
/// `leadingGroups` at the bar's leading edge, the others at its trailing edge, -1 behind "more" - whether it
/// can be chosen, its shortcut's key and modifiers (`stateui_winui_set_shortcut`), key 0 for none, and a setting's
/// state - 1 on, 0 off, -1 for an action - which makes its button a two-state one. A group stands apart from the one
/// before it; a press tells the action's place in the list.
void stateui_winui_title_bar_set_actions(StateUIObjectRef bar, char const *const *texts,
                                         char const *const *identifiers, char const *const *icons, bool const *words,
                                         bool const *destructive, int32_t const *groups, int32_t leadingGroups,
                                         bool const *enabled, int32_t const *keys, int32_t const *modifiers,
                                         bool const *givesWay, int32_t const *states, int32_t count);

/// The menu of the title bar's action at `place`, written as a context menu is (`stateui_winui_set_context_menu`), its
/// items' choices told from `first` on: the flyout its click opens, or - `held` - its context menu, press and hold or
/// the mouse's other button opening it.
void stateui_winui_title_bar_set_action_menu(StateUIObjectRef bar, int32_t place, bool held, int32_t first,
                                             int32_t const *kinds, char const *const *titles, bool const *enabled,
                                             char const *const *identifiers, char const *const *icons,
                                             bool const *destructive, int32_t const *keys, int32_t const *modifiers,
                                             bool const *givesWay, int32_t count);

/// What a test reads: the menu of the title bar's action at `place`, as `stateui_winui_menus` writes one, in UTF-8;
/// the length it needs.
int32_t stateui_winui_title_bar_action_menu(StateUIObjectRef bar, int32_t place, char *utf8, int32_t capacity);

/// Chooses the item at `index` of the menu of the title bar's action at `place`, as assistive technology does.
void stateui_winui_title_bar_action_menu_choose(StateUIObjectRef bar, int32_t place, int32_t index);

/// What a test reads: the theme a title bar stands in, a `StateUIColorScheme`.
int32_t stateui_winui_title_bar_theme(StateUIObjectRef bar);

/// What a test reads: the room a title bar keeps at its trailing edge, and the room the window's own buttons there
/// take, both in DIPs - -1 kept where the bar stands in no window - and how many of its two padding columns the
/// relay found by name.
void stateui_winui_title_bar_caption_room(StateUIObjectRef bar, double *kept, double *room, int32_t *columns);

/// Stands `view` in the title bar's middle, in the title's place; null takes it away.
void stateui_winui_title_bar_set_title_view(StateUIObjectRef bar, StateUIObjectRef view);

/// A split view: WinUI's SplitView, the sidebar in its pane as wide as WinUI opens it - `beside` the detail, else
/// over it and closed by a click beside it - the detail on a card; `row` stands across the top of the detail.
StateUIObjectRef stateui_winui_split_make(int64_t view);
void stateui_winui_split_set(StateUIObjectRef split, StateUIObjectRef pane, StateUIObjectRef content,
                             StateUIObjectRef row, bool open, bool beside);

/// The whole width of a split view's pane, in DIPs: the theme's, as WinUI's style opens it.
double stateui_winui_split_pane_width(StateUIObjectRef split);

/// A split view's pane `pane` DIPs wide on its way in or out, its sidebar standing at its whole `width`, its trailing
/// edge at the pane's.
void stateui_winui_split_slide(StateUIObjectRef split, double pane, double width);

/// Asks WinUI to measure a split view's pane and everything in it again, as its height changes: WinUI applies an
/// arrange inside the pane only to what it measured in that pass.
void stateui_winui_split_measure_pane_again(StateUIObjectRef split);

/// Stands a split view's pane on a ground for each place: beside the detail and over it - a color `argb`, or the
/// in-app acrylic in it, its luminosity hiding `opacity` of what is behind it and its tint `tintOpacity`.
void stateui_winui_split_set_pane_grounds(StateUIObjectRef split, StateUIGround besideKind, uint32_t besideArgb,
                                          float besideOpacity, float besideTintOpacity, StateUIGround overKind,
                                          uint32_t overArgb, float overOpacity, float overTintOpacity);

/// Whether a window's content shows the keys it takes - the way back's, Escape's - in a tip over everything it
/// holds: what a test reads.
bool stateui_winui_window_shows_keys(StateUIObjectRef window);

/// A tabbed view's row of tabs: a SelectorBar, each tab with its title and the files its picture may stand in -
/// each ended by a line feed, empty for none - `selected` chosen.
StateUIObjectRef stateui_winui_tabs_make(int64_t view);
void stateui_winui_tabs_set(StateUIObjectRef tabs, char const *const *titles, char const *const *icons, int32_t count,
                            int32_t selected);
/// Chooses the tab at `index` as the user's click does - what a test does.
void stateui_winui_tabs_choose_as_user(StateUIObjectRef tabs, int32_t index);

/// A group of the environment's facts, in UTF-8, each ended by the unit separator (0x1F); the display's are the
/// screen `window` stands on. Answers the length the facts need, their end not counted.
int32_t stateui_winui_facts(StateUIFacts kind, StateUIObjectRef window, char *utf8, int32_t capacity);

/// Watches the theme, the power, the network, the screens and the accessibility settings, `environmentChanged`
/// called in the UI thread's turn after each change; once.
void stateui_winui_watch_environment(void);

/// Listens on `element`, which the view `view` shows, for what `hearing` names, each heard through `heard`; 0
/// stops. A panel that listens is hit where it draws nothing, and one that hears taps assistive technology presses.
void stateui_winui_hear(StateUIObjectRef element, int64_t view, uint32_t hearing);

/// Hears a trackpad and a wheel over the layout `view` as WinUI's own scroller does, along `axis` - 0 across, 1
/// down, 2 both, a pan's - or no longer, for -1; where `pinches`, the wheel turned with Control scales.
void stateui_winui_hear_hand(StateUIObjectRef element, int64_t view, StateUIHandAxis axis, int32_t pinches);

/// The host says the press the view `view` heard is a drag: the view holds the pointer from the move it heard it in.
void stateui_winui_press_dragged(int64_t view);

/// The system's drag distance, across and down, in DIPs.
void stateui_winui_drag_distance(double *distance);

/// The system's double click: how long after the first a second click may come, in seconds, and how far from it, in
/// DIPs.
void stateui_winui_double_tap(double *tap);

/// Presses `element` as assistive technology does, through its automation peer; whether it could be pressed.
bool stateui_winui_press(StateUIObjectRef element);

/// Whether a click at (x, y) DIPs of `element` would reach the element itself.
bool stateui_winui_hits(StateUIObjectRef element, double x, double y);

/// Whether a click at (x, y) DIPs of `element` would reach it, or what stands in it, through everything its window
/// shows over it - what a test reads.
bool stateui_winui_reaches(StateUIObjectRef element, double x, double y);

/// Where `child` - or the element it stands in among `panel`'s children - is drawn in `panel`: its `Canvas.ZIndex`
/// in `depth`, its place among the panel's children in `place`, the higher of either drawn later; false where it
/// stands in no child of the panel - what a test reads.
bool stateui_winui_drawn_place(StateUIObjectRef panel, StateUIObjectRef child, int32_t *depth, int32_t *place);

/// Tells `focused` whenever the keyboard comes into the element or leaves it, while `hearing`; false stops.
void stateui_winui_hear_focus(StateUIObjectRef element, int64_t view, bool hearing);

/// The element of the view `view` carries `words` in a drag of it - null where it cannot be dragged - and takes words
/// dropped on it where `takesWords`, files where `takesFiles`; what it hears goes through `dragHeard` and
/// `filesDragged`. A view offering nothing is forgotten.
void stateui_winui_offer_drag(
    StateUIObjectRef element, int64_t view, char const *words, bool takesWords, bool takesFiles);

/// Whether `element` can be dragged and takes drops, as its view's offer set them - what a test reads.
void stateui_winui_drag_read(StateUIObjectRef element, bool *canDrag, bool *allowsDrop);

/// How many views the relay holds a drag offer of - what a test counts to see every one let go.
int32_t stateui_winui_drag_offers(void);


/// How many views listen for the user's input - what a test counts to see every one stop.
int32_t stateui_winui_listeners(void);

/// Whether WinUI has loaded `element` into a window - what a test reads.
bool stateui_winui_is_loaded(StateUIObjectRef element);

/// How many sets of input handlers hang on elements - a view that stopped listening keeps its set until the event
/// running is over - what a test counts.
int32_t stateui_winui_hung_handlers(void);

/// What assistive technology meets of the element: its automation id, name and help text - null for the control's
/// own - its heading level (0 none, 1 to 9), and whether it meets the element at all.
void stateui_winui_set_accessibility(StateUIObjectRef element, char const *identifier, char const *label,
                                     char const *hint, int32_t heading, StateUIPresence presence);

/// Whether assistive technology meets none of what stands in a panel.
void stateui_winui_panel_hide_children(StateUIObjectRef panel, bool hidden);

/// The `AutomationControlType` a panel's automation peer answers with, -1 for a panel's own, and the value it holds,
/// null for none.
void stateui_winui_panel_set_kind(StateUIObjectRef panel, int32_t controlType, char const *value);

/// The `AutomationControlType` assistive technology meets the element as; -1 where it meets none.
int32_t stateui_winui_automation_control_type(StateUIObjectRef element);

/// What assistive technology meets of the element, as its automation peer says it - what a test reads: `what` 0 its
/// name, 1 its help text, 2 its automation id, 3 its value, in UTF-8; the length they need, their end not counted.
int32_t stateui_winui_automation_words(StateUIObjectRef element, int32_t what, char *utf8, int32_t capacity);

/// Its heading level, whether it is a control element and a content element, and how many of what stands in it
/// assistive technology meets, to the deepest part: four values.
void stateui_winui_automation_facts(StateUIObjectRef element, int32_t *facts);

/// How many canvases WinUI holds - what a test counts to see every one let go.
int32_t stateui_winui_canvases(void);

/// The local time of day: hour, minute, second and millisecond, into `time`.
void stateui_winui_clock(int32_t *time);

/// The IANA identifier of the local time zone, in UTF-8, as far as `capacity` goes; answers its whole length.
int32_t stateui_winui_time_zone(char *utf8, int32_t capacity);

/// How far `zone` - an IANA identifier, the local zone for null - stands from UTC on a day, in minutes; year 0
/// for now. Answers false for a zone ICU does not know.
bool stateui_winui_utc_offset(char const *zone, int32_t year, int32_t month, int32_t day, int32_t *minutes);

/// Offers the words and the link - null for one not given - in Windows' share sheet over `window`; `answered` is
/// called once, on the UI thread, with `context`: 1 where the user shared, 0 where they cancelled, -1 where the sheet
/// could not be offered.
void stateui_winui_share(StateUIObjectRef window, char const *text, char const *link, void *context,
                         void (*answered)(void *context, int32_t shared));

/// Says `utf8` to a screen reader, from `element`, cutting off what it was saying.
void stateui_winui_announce(StateUIObjectRef element, char const *utf8);

/// Puts the keyboard's focus on `element`, or the first control in it that takes it, answering whether one did;
/// or takes it off whatever holds it inside `element`, answering whether anything did.
bool stateui_winui_focus(StateUIObjectRef element, bool focus);

/// Whether `element`, or something inside it, holds the keyboard's focus.
bool stateui_winui_focused(StateUIObjectRef element);

/// What a test reads: moves the focus in `element`'s window to its next stop, as Tab does, and names the class of
/// what holds it then; empty for nothing.
int32_t stateui_winui_tab(StateUIObjectRef element, char *utf8, int32_t capacity);

/// Takes the focus off a field typed into in `element`'s window, so the on-screen keyboard goes; whether one was.
bool stateui_winui_hide_keyboard(StateUIObjectRef element);

/// Puts `question` to the user in WinUI's dialog over `element`'s window once that window is loaded - the host asks
/// one at a time; the answer comes back through `answered`, under `ticket`.
void stateui_winui_ask(StateUIObjectRef element, int64_t ticket, StateUIQuestion const *question);

/// Answers the dialog showing over `element`'s window as the user would: `button` 0 accepts - an alert's one button
/// too - 1 cancels, 2 and on press a choice's actions in order; a prompt's field first holding `words` where they are
/// given. Whether a dialog was showing and had that button. What a test does.
bool stateui_winui_answer(StateUIObjectRef element, int32_t button, char const *words);

/// Shows `dialog` in Windows' own file dialog over `window` (a `Window`); a save writes its contents where the user
/// said, beside the UI thread. The answer comes back through `filesChosen`, under `ticket`, on the UI thread.
void stateui_winui_show_file_dialog(StateUIObjectRef window, int64_t ticket, StateUIFileDialog const *dialog);

/// Reads the file at `path`, in UTF-8, beside the UI thread - whole for a `maximum` below nought, else its first
/// `maximum` bytes, read no further; its bytes come back through `fileRead`, under `ticket`, on the UI thread.
void stateui_winui_read_file(int64_t ticket, char const *path, int64_t maximum);

/// Sends a request with Windows' own HTTP client - its address, its method and its headers' names and values in
/// turn a unit separator apart, in UTF-8, and its `length` bytes; the answer comes back through `requestAnswered`,
/// under `ticket`, on the UI thread.
void stateui_winui_send_request(
    int64_t ticket, char const *address, char const *method, char const *headers, uint8_t const *body, int64_t length);

/// Stops the request sent under `ticket`, where it is under way: its answer comes back through `requestAnswered`,
/// saying why.
void stateui_winui_cancel_request(int64_t ticket);

/// Hands the file at the path `target`, or the address `target`, to Windows to open in the application it gives it;
/// whether one took it comes back through `launchAnswered`, under `ticket`, on the UI thread.
void stateui_winui_launch(int64_t ticket, char const *target, bool file);

/// What a test does: while `held`, a launch is answered as taken and Windows is asked nothing.
void stateui_winui_hold_launches(bool held);

/// What a test does: a dialog that saves opens in `folder`, in UTF-8, so what a test saves stays there.
void stateui_winui_keep_test_files_in(char const *folder);

/// What a test does: answers the file dialog `dialog` - the one showing in the process where 0 - as the user would,
/// by the `count` files of `paths`, in UTF-8: typed whole, several each in quotes, and taken once its field holds
/// them; none cancels it. The dialog answered, 0 where it no longer shows: a dialog shown a moment ago may not take
/// its answer yet, so a test answers it again until it is gone.
int64_t stateui_winui_answer_file_dialog(int64_t dialog, char const *const *paths, int32_t count);

/// The folder the host's stores stand in, in UTF-8; empty for the application's own in the user's local data.
void stateui_winui_set_store(char const *utf8);

/// The store in the file `name` as it stands, in UTF-8, as far as `capacity` goes; answers its whole length.
int32_t stateui_winui_stored(char const *name, char *utf8, int32_t capacity);

/// Writes the whole store in the file `name`, in UTF-8, in place of the old one; whether it was written.
bool stateui_winui_store(char const *name, char const *utf8);

/// The folder the application's pictures are read from, in UTF-8; empty for `Images` beside the executable.
void stateui_winui_set_pictures(char const *folder);

/// An Image showing the first of the `count` files `names` lists that the pictures hold, filling its room as
/// StateUI's ContentMode says: fit, fill, stretch, center. Answers whether a picture was found, or none was named;
/// `size` takes the size an SVG declares, in DIPs, and zero for a bitmap, whose size WinUI knows once it has read
/// it.
StateUIObjectRef stateui_winui_image_make(void);
bool stateui_winui_image_set(StateUIObjectRef image, char const *const *names, int32_t count, int32_t aspect,
                             double *size);

/// The size of the bitmap `image` shows, in DIPs; zero until it is read, and for an SVG. Once it is read, the
/// layout holding the image is asked to measure again.
void stateui_winui_image_size(StateUIObjectRef image, double *size);

/// Draws an SVG `image` shows at `width` by `height` DIPs, at the display's scale; nothing for a bitmap.
void stateui_winui_image_draw(StateUIObjectRef image, double width, double height);

/// How many SVGs the pictures and icons under an element show read by their file's address, and how many not.
void stateui_winui_svgs_read(StateUIObjectRef element, int32_t *counts);

/// What WinUI holds of `element`'s property named `what`, in UTF-8, as far as `capacity` goes - a color as #AARRGGBB,
/// a number, 0 or 1, words, sides and corners as four numbers - answering its whole length; -1 for a property the
/// element has none of. What a test reads.
int32_t stateui_winui_read(StateUIObjectRef element, char const *what, char *utf8, int32_t capacity);

/// Writes `utf8` in the field of the prompt showing over `element`'s window, the caret after them - each change told
/// through `promptTyped`, as the user's typing is.
void stateui_winui_prompt_write(StateUIObjectRef element, char const *utf8);

/// The question showing over `element`'s window, in UTF-8, as far as `capacity` goes: its title, message, accepting
/// and cancelling captions, its field's words (0x01 for none) and its choices, each ended by the unit separator
/// (0x1F) but the last; -1 for none showing. What a test reads.
int32_t stateui_winui_question(StateUIObjectRef element, char *utf8, int32_t capacity);

/// What the screen reader was told since the relay started, in UTF-8, each ended by the unit separator (0x1F) but
/// the last, as far as `capacity` goes; its whole length. What a test reads.
int32_t stateui_winui_announced(char *utf8, int32_t capacity);

/// The file dialog showing in the process: 0 one that opens, 1 one that saves, -1 none. What a test reads.
int32_t stateui_winui_file_dialog(void);

/// What was launched since the relay started - a file by its path, an address as written - in UTF-8, each ended by
/// the unit separator (0x1F) but the last, as far as `capacity` goes; its whole length. What a test reads.
int32_t stateui_winui_launched(char *utf8, int32_t capacity);

#ifdef STATEUI_WINUI_RELAY
#pragma clang attribute pop
#endif

#ifdef __cplusplus
}
#endif
