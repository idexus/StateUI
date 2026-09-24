# The standard environment

The battery, the network, the display, the locale, the device, the
application's manifest and its phase are state the host holds and the core
can only be told about. Each is a provider object of `@State` properties,
offered to every view the way an object an ancestor provides is.

## The standard environment

```text
  Battery              chargeLevel, state, powerSource, energySaverStatus
  Connectivity         networkAccess, connectionProfiles
  DeviceDisplay        width, height, density, orientation, rotation, refreshRate
  LocaleInfo           language, region, name, timeZone, uses24HourClock, firstDayOfWeek, isMetric
  DeviceInfo           formFactor, platform, model, manufacturer, name, versionString, deviceType
  AppInfo              name, packageName, versionString, buildString, requestedTheme
  ApplicationSession   phase, and what the application writes: styles, motion, kept keys
```

A view resolves one with `@Environment var battery: Battery`. Nothing is
registered and nothing is passed down: the type is the key, the standard
rule. The objects live for the process, and a view that reads none of them
costs nothing.

## How the host writes it

The host seeds every provider before the first render, so the first tree
already knows its form factor and its locale, and writes again whenever the
platform reports a change. A host writes through `StateUIHost`, one setter
per provider - `setBatteryInfo`, `setConnectivityInfo`, `setDisplayInfo`,
`setLocaleInfo`, `setDeviceInfo`, `setApplicationInfo` with `setTheme`, and
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
UI thread, which is why the instances can be `nonisolated(unsafe)`.

## Open sets are text

`DeviceInfo.platform` is text, not a vocabulary: the set of platforms is
open, and a host may name one this release does not know. `FormFactor`
tells apart devices that share an operating system, such as a phone and a
tablet, which `stateUIPlatform()`, compiled in, never can.
