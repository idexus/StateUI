# Conformance on WinUI

How the conformance suite drives WinUI: `WinUIDriver` in the host's test
target, one test for each family of cases in `WinUIConformanceTests`.

## What the driver does

A user's act goes through UI Automation where WinUI offers a pattern for it -
Invoke for a button, a menu's item and a search box's query, Toggle, a range's
value - and otherwise through the relay's callback that WinUI's own input
takes into the host: a button held, a canvas pressed, a view's taps, pans,
pinches and pointer, the window's phase, the chrome's way back and its toggle.
WinUI raises a text box's KeyDown only from the keyboard, so Enter in a field
is walked on the Gallery instead.

## Typing

UI Automation's value on a text box, asked in the process that holds WinUI,
ends that process a moment later, so the driver never types through it. It
writes the words outside a program's write, which WinUI reports through the
same `TextChanging` as the keyboard's, and a box WinUI holds read only takes
none, as its keyboard takes none. The real paths - the keyboard, and UI
Automation from another process - are walked on the Gallery.

## A question

A dialog takes a press only once WinUI has shown it whole, and the next
question stands only once the last has closed; the driver presses the
button of the caption asked until the press lands.

## A colour at a point

A bitmap WinUI renders of an element that is no panel - a shape, a picture -
holds what the element draws from the first thing drawn, not its room from
its corner, and a picture's own control stands where its picture is fitted.
The driver renders the layout placing the element, a panel it renders whole,
and reads the element's point there, from where StateUI placed the element.
A large panel's bitmap comes smaller than the screen shows it, so a point is
read by the bitmap's own scale.

## A process a test

A window whose content extends into its title bar - every window the host
shows - leaves some forty of the process's GDI objects behind when it closes,
and a process holds ten thousand: a few hundred windows end it. A family of
cases shows a window a case, so the host's tests run each in a process of its
own (`test-winui.ps1`), the largest families - a view's, a visual element's -
in parts, one test each. Each test holds its process below six thousand GDI
objects, and a family past that is run in more parts.

## What the driver reads

A member's value is read from the control WinUI holds, never from what the
host last wrote: through the relay's one reader, `stateui_winui_read`, by the
native property's name - a font, a colour, a padding, a border, a field's
placeholder and bound, a path's paint, a layout's box, a range, a date, a scroll
bar, the chrome's title, way back and actions, a row's tabs - and the relay's
older readers of words, toggles, values, choices and dates. What WinUI keeps
nowhere - a shape's aspect and transform, folded into its figure; an editor's
growing, which is StateUI's measuring - the driver says it cannot read, with
why, and a case of the effect proves the member.

A running ring's automation peer says it is busy before the name its element
holds, so the driver reads an activity indicator's label from the element.
