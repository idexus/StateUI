# The application element

What happens with no control behind it - an alert, the clock, the screen
reader, a value kept between launches - belongs to the application.
`ApplicationContract` is the contract of the application at the root of the
tree, and it declares what the host does for it. An application adds its
own such acts and events through a tier the application element wears.

## Acts with no control

Each of the library's application acts has a Swift front an application
calls, and the front hands the act its arguments in the order the contract
declares them.

```text
  alert                  Dialogs.alert              the title, the message, the button's caption
  confirm                Dialogs.confirm            answers whether it was accepted
  chooseAction           Dialogs.chooseAction       answers the chosen caption, or nothing
  prompt                 Dialogs.prompt             answers the text, or nothing
  announce               ScreenReader.announce      the screen reader says a text
  hideOnScreenKeyboard   OnScreenKeyboard.hide()    answers whether a view held the focus
  currentTime            ClockTime.now()            hour, minute, second, millisecond
  currentTimeZone        TimeZoneInfo.local()       an IANA identifier
  utcOffset              TimeZoneInfo.utcOffset     minutes, for a zone and a day
  persistValue           a kept state's write       a key's new value, to its store
  persistSceneValue      a scene state's write      a scene key's new value, to the platform's scene record
  handlerFailed          the runtime                a handler's escaped error, told to the host
```

A dialog opens on the page that is showing. The application element is a
`structure` element: it carries no platform control of its own.

## A tier of the application

`ApplicationTier` is a tier the application element wears. An application
declares one exactly as the library declares its contracts: its acts are
called with `stateUICall`, which awaits the answer as the declared types, or
with `stateUISend`, which does not wait; its events are heard with
`HostEvents.on`. None of them aims at a control.

An act of an element's own, such as `focus` or a web view's `goBack`, is
called through the element's aim instead: `Aim.call` puts the aimed element
first, and the act reaches whatever wears the contract declaring it.
