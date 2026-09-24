# Structure elements

Not every element is a control. The dictionary lists as controls the
elements that wear `View`, and the rest as the parts of an application's
structure: the application, its scenes and windows, the pages and their
arrangements, menus and toolbars, the slots that hold a view in a named
place, and the collections a host keeps in step. Most of them are
`structure` elements: they carry structure, not a platform control of their
own.

## The parts

```text
  Application                        the root, and the acts with no control behind them
    Scene                            one session of the application
      Window                         a window onto a page
        Page, NavigationStack,       what a window shows; the arrangements are pages too
        TabbedView, SplitView
        TitleBar                     an authored title area, with its slots
        ModalStack                   the pages presented over the window, the last on top
        Overlay                      a view above the window's page
  MenuBar, Menu, MenuItem,           a page's menus, their entries, and the lines between them
  MenuSeparator
  ContextMenu                        the menu a view offers where the user asks for one
  ToolbarItems, ToolbarItem          a page's actions in its bar or toolbar
  TitleView                          the view a page shows in its bar in place of its title
  Content, LeadingContent,           a title bar's middle, leading and trailing views
  TrailingContent
  Spans, Span                        the runs of text a label is made of
  VisualState, Setters               a state a control can be in, and the values it sets there
```

## Slots

A slot is an element whose only job is to say where the one view it holds
goes: a title bar's `Content`, `LeadingContent` and `TrailingContent`, a
page's `TitleView`. The view inside is an ordinary part of the tree, built
where it is shown, so a composed view there reads its own state and builds
again when that state moves.

## Collections as one node

A page's toolbar items hang off it as one `ToolbarItems` node holding them
all, its menus as one `MenuBar`, a label's runs as one `Spans`, and a
visual state's values as one `Setters`. The host has a list to keep in step,
and a list needs a parent of its own to be matched against. Where the host
puts an item of such a collection - a toolbar item's placement - is a value no default answers for, so its member is not cleared; see
[cleared](member-facts.md#cleared).

## Visual states

A `VisualState` is one state a control can be in, named in its group: a
control is in one state of each group, and the state's `Setters` are the
values it sets there. The names are `Name` values matched exactly. A
control entering one of its states reports `visualStateChanged` with the
state's name.
