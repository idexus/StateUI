# The standard environment

The battery, the network, the display, the locale, the device, the
application's manifest and its phase are state the host holds and the core
can only be told about. Each is an object of `@State` properties, offered to
every view the way an object an ancestor provides is, and read by its name.

## The standard environment

```text
  \.device        Device
                     info          formFactor, platform, model, manufacturer, name, versionString, deviceType
                     display       width, height, density, orientation, rotation, refreshRate
                     battery       chargeLevel, state, powerSource, energySaverStatus
                     connectivity  networkAccess, connectionProfiles
  \.locale        LocaleInfo      language, region, name, timeZone, uses24HourClock, firstDayOfWeek, isMetric,
                                  layoutDirection
  \.application   ApplicationSession
                     info          name, packageName, versionString, buildString, colorScheme, accentColor
                     phase, and what the application writes: styles, motion, kept keys
  \.scene, \.window   the sessions a view stands in
```

A view reads one by its name, `@Environment(\.device) private var device`, and
then the fact it shows, `device.battery.chargeLevel`. Nothing is registered
and nothing is passed down: the name stands for the object's type, and the
scope is keyed by type, the rule an application's own objects follow. The
objects live for the process, and a view that reads none of them costs
nothing.

## Read by name only

What the library offers has one spelling, its name (`EnvironmentValues`). The
type spelling, `@Environment var device: Device`, compiles - nothing in the
type system tells the library's objects from an application's - so it is
refused as the view is made, the message naming `@Environment(\.device)`
(`Environment.refusal`). An object the application provides with
`.environment(_:)` has no name in the library and is read by its type.

## How the host writes it

The host seeds every provider before the first render, so the first tree
already knows its form factor and its locale, and writes again whenever the
platform reports a change. A host writes through `HostBoundary`, one setter
per provider - `setBatteryInfo`, `setConnectivityInfo`, `setDisplayInfo`,
`setLocaleInfo`, `setDeviceInfo`, `setApplicationInfo` with `setColorScheme` and `setAccentColor`, and
`setApplicationPhase` - each with the whole report, typed.

## Exactly the readers rebuild

A write lands on the property's own `@State`, so exactly the views that read
the changed property build again. A battery level that moves reaches the
views showing the level and not the ones gating on the battery saver.
Rotating a phone writes orientation, rotation, width and height in one
update.

## A report that repeats itself

A setter writes only the fields that differ from what the provider holds.
Platforms report far more often than anything changes - Android on every
battery broadcast, macOS on every power-source notice - and a write asks for a
render even when it writes what was there, so a repeated report would rebuild
every reader for nothing.

## One door and the bottom of the scope

The provider instances are internal on purpose: the way to read one is
`@Environment`, and a second public door would be a second way to do one
thing. They are seeded at the bottom of every render's scope, so an
application providing a fake with `.environment(...)` is nearer by
construction and wins, which is how a test, or an application lying to one
branch, provides its own. The application itself is built outside any render,
so an `@Environment` slot left unfilled answers with the standard provider
of its type.

## The UI thread

Provider values are written by the host's reports and read by builds, both on the
UI thread, which is why the instances are `MainActor`'s.

## Open sets are text

`device.info.platform` is text, not a vocabulary: the set of platforms is
open, and a host may name one this release does not know. `FormFactor`
tells apart devices that share an operating system, such as a phone and a
tablet, which `stateUIPlatform()`, compiled in, never can.
