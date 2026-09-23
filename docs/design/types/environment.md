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
platform reports a change. A Swift host writes through `StateUIHost`. A
runtime in another language calls `stateui_set_environment` with one
provider's values per call: the domain byte (`EnvironmentDomain`), then the
typed values in the order the provider declares its properties.

## Exactly the readers rebuild

A write lands on the property's own `@State`, so exactly the views that read
the changed property build again. A battery level that moves reaches the
views showing the level and not the ones gating on the battery saver.
Rotating a phone writes orientation, rotation, width and height in one
update.

## One door and the bottom of the scope

The provider instances are internal on purpose: the way to read one is
`@Environment`, and a second public door would be a second way to do one
thing. They are seeded at the bottom of every render's scope, so an
application providing a fake with `.environment(...)` is nearer by
construction and wins, which is how a test, or an application lying to one
branch, provides its own. The application itself is built outside any render,
so an `@Environment` slot left unfilled answers with the standard provider
of its type.

## A push is refused whole

A push for a domain the library does not know, or with a payload of the
wrong shape, is refused whole, with nothing half applied, and the host
reports it once as version skew. A member of a vocabulary the library has no
case for is the exception: it reads as `.unknown`, so a newer host's
vocabulary does not cost the whole domain its report; see
[an unknown member](vocabularies.md#an-unknown-member).

The connection profiles are a list of members, so they cross as `.values` of
`.enumeration`, never as `.numbers`: a run of numbers is a run of
quantities, and a member is not one.

## The UI thread

Provider values are written by host pushes and read by builds, both on the
UI thread, which is why the instances can be `nonisolated(unsafe)`.

## Open sets are text

`DeviceInfo.platform` is text, not a vocabulary: the set of platforms is
open, and a host may name one this release does not know. `FormFactor`
tells apart devices that share an operating system, such as a phone and a
tablet, which `stateUIPlatform()`, compiled in, never can.
