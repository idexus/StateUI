# The keyboard

A keyboard shortcut is a key pressed with the keys held with it, written on
the control it acts as: `Button("Save").keyboardShortcut("s")`. It presses a
button and chooses a bar's item or a menu bar's entry while its window is in
front; on a context menu's entry the platform only shows it beside the words.

## A key

`Key` is a character's key, written as the character - `"s"`, a literal of
one character, so `"save"` does not compile - or one of a closed set of keys
writing none: Return, Escape, Delete, the four arrows and F1 to F12, numbered
by StateUI. A letter is its key whatever its case: Shift is a modifier, so
`"S"` is the key `"s"`, and a shortcut holding Shift says so in its modifiers.

## Modifiers

`KeyModifiers` holds the platform's own key, `.primary` - Command on Apple's
platforms, Control elsewhere - Shift and `.alt`, Option on Apple's platforms.
`.primary` alone is what a shortcut holds unless it says otherwise, so the
same `keyboardShortcut("s")` is ⌘S on the Mac and Ctrl+S on Windows and Linux.
A shortcut crosses as its key - a character as text, another key by its
number - and its modifiers' bits.

## A key typed

A shortcut needs no modifier: `keyboardShortcut("1", modifiers: [])` presses
its button on the key alone. Such a key is also what a field writes, so a
character's key held with neither the platform's own key nor Alt - alone, or
with Shift - gives way to typing (`KeyboardShortcuts.givesWayToTyping`): while
a field the user types into holds the keyboard, the key types there and the
shortcut does not act. A key writing no character - Escape, the arrows, F5 -
and a shortcut held with the platform's own key or Alt act whatever holds the
keyboard. Android, GTK and WinUI hand a key to the view holding the keyboard
first; AppKit offers it to the window's key equivalents first, UIKit to its key
commands and the page to its listener - so each host asks whether a field is
being typed into before a shortcut giving way acts.

## In a window

What a shortcut reaches is decided once, in the host layer
(`KeyboardShortcuts`): the elements it acts on are buttons, bars' items and
the entries of a menu bar, standing in sight - shown, on the top page of a
stack, the chosen tab, the sheet over the others - and enabled; the first in
reading order takes a pressed one. A shortcut two elements in sight state in
one window is said once, as the patch stating it is applied, since which acts
is then not the application's choice. A pressed shortcut clicks a button and
chooses an item as the user choosing it does (`MountedElement.chosen`).

## On each platform

Each host spells a shortcut in its toolkit's words and lets the toolkit hold
it where the toolkit holds one on a control: AppKit's key equivalent and its
modifier mask on the button, GTK's shortcut controller with a window-wide
scope activating the button, WinUI's keyboard accelerator on it, and the
page's `aria-keyshortcuts` beside its own key-down listener. UIKit holds a key
command on a responder, not on a control, so a window's root offers one for
every shortcut its tree states; Android holds none on a view, so the activity
hands the host each key no view takes - after the views, as Android's own
shortcuts come after them. Both reach their element through the host layer's
choice.

A menu bar's entry and a bar's item are held the same way where the toolkit
holds a shortcut on one: AppKit's key equivalent on the menu's item, WinUI's
accelerator on the menu bar's item and on the bar's button, UIKit's key command
in the main menu - which the window's root then leaves out of its own. Where
the toolkit holds none - AppKit's toolbar item, GTK's menus and header bar,
Android's bar - the window holds them: AppKit's content view after its key
equivalents, a GTK shortcut controller on the window (`GTKWindowShortcuts`),
Android's keys no view takes; the host layer then chooses the item. A key
giving way to typing passes over a menu bar too: AppKit offers the bar every
key before the field, so the bar (`AppKitMainMenu`) answers no key giving way
while a field is typed into.

A context menu's entry only shows its shortcut, in each toolkit's own place
for it: AppKit's key equivalent, Android's alphabetic or numeric shortcut,
GTK's `accel` attribute, WinUI's accelerator text over a disabled
accelerator, the page's `kbd` beside `aria-keyshortcuts`. The window never
presses it. UIKit's entry is a key command there too, but UIKit shows a key
command's shortcut in the main menu alone, none in a context menu.

A character no key of the letters or digits writes - punctuation - has no
virtual key of its own on WinUI and no key code on Android: there it presses
nothing.
