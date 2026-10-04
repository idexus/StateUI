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
    Scene                            windows and the state they share
      Window                         a window onto a page
        Page, NavigationStack,       what a window shows; the arrangements are pages too
        TabView, SplitView,
        ModalStack                   a page with the pages presented over it, the last on top
  Overlay                            the views a page lays over its window, and the library's own
  MenuBar, Menu, MenuItem,           a page's menus, their entries, and the lines between them
  Divider
  ContextMenu                        the menu a view offers where the user asks for one
  ToolbarItemGroup, ToolbarItem          a page's actions in its bar or toolbar
  TitleView                          the view a page shows in its bar in place of its title
  TextSpans, TextSpan                        the runs of text a label is made of
```

## Slots

A slot is an element whose only job is to say where the one view it holds
goes: a page's `TitleView`. The view inside is an ordinary part of the tree, built
where it is shown, so a composed view there reads its own state and builds
again when that state moves.

## Collections as one node

A page's toolbar items hang off it as one `ToolbarItemGroup` node for each
`.toolbar` declaration, holding its items, its menus as one `MenuBar`, and a
label's runs as one `TextSpans`. The host
has a list to keep in step, and a list needs a parent of its own to be matched
against. Where the host
puts an item of such a collection - a toolbar item's placement - is a value no default answers for, so its member is not cleared; see
[cleared](member-facts.md#cleared).
