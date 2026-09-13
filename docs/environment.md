# Environment, platform facts, and time

`@Environment` resolves a shared reference by its Swift type. It is the route
for application models supplied to a subtree, platform facts supplied by a
host, and the runtime session belonging to the application, scene, window, or
page.

Environment resolution does not introduce another reactive system. The
resolved object's `@State` properties use the same read tracking, bindings, and
host channels described in [State and reactivity](state-and-reactivity.md).

## Providing an application object

Provide a class with `.environment(_:)` on the common ancestor of every view
that needs it:

```swift
final class Account {
    @State var name = "Guest"
    @State var visits = 0
}

struct AccountBadge: ContentView {
    @Environment private var account: Account

    var content: any View {
        Label("\(account.name) · \(account.visits) visit(s)")
    }
}

struct AccountEditor: ContentView {
    @Environment private var account: Account

    var content: any View {
        Entry(account.$name)
    }
}

struct AccountBranch: ContentView {
    @State private var account = Account()

    var content: any View {
        VStack {
            AccountBadge()
            AccountEditor()
            Button("Visit").onClicked { account.visits += 1 }
        }
        .environment(account)
    }
}
```

The type is the key. `AccountBadge` needs no initializer argument, and an
environment of another type cannot collide with it. If several ancestors
provide `Account`, the nearest one wins for its branch.

The provider passes a reference without reading its properties. A write to
`account.visits` therefore invalidates bodies that read `visits`, not the body
that merely provides the object. Replacing the `account` held by the provider's
own state rebuilds that provider, after which descendants resolve the new
object.

Custom environment values must be reference types. Give every model property
that participates in the interface its own `@State`; a plain property is not
observed. The environment object itself never crosses the host boundary.

Reading a custom environment that no ancestor provided stops with a diagnostic
naming the missing type. There is no optional, silently empty environment
lookup.

### Editing a provided object

The projected environment `$account` can lend a writable member to ordinary
described input. The model property's own projection is the whole state and is
the appropriate channel when a host carries that value:

- `$account.name` reaches the member through the provided object;
- `account.$name` borrows the `@State` declared on `Account.name` itself.

Assigning a different object through `$account` is rejected. The ancestor owns
which object it provides; descendants edit its properties or communicate a
replacement through an explicit binding owned by that ancestor.

## Overriding one branch

The same rule applies to standard providers. A test, preview, or controlled
subtree can provide a nearer instance:

```swift
struct SavePanel: ContentView {
    @Environment private var connectivity: Connectivity

    var content: any View {
        Button("Save")
            .isEnabled(connectivity.networkAccess == .internet)
    }
}

let offline = Connectivity()
offline.networkAccess = .none

SavePanel().environment(offline)
```

Only that branch sees the override. The process-wide provider remains the
answer everywhere else.

## Standard environment

Every tree starts with one process-wide instance of each standard provider.
The host seeds the facts it knows before the first render and updates changing
facts on its UI thread. Each field is `@State`, so reading one field subscribes
to that field rather than to its whole provider.

There are seven host domains. Their ordered property schemas are part of
StateUI's contract:

| Domain and type | Properties | Meaning and initial fallback |
| --- | --- | --- |
| battery — `Battery` | `chargeLevel`, `state`, `powerSource`, `energySaverStatus` | charge and power state; level is `-1`, enums are `.unknown` until reported |
| connectivity — `Connectivity` | `networkAccess`, `connectionProfiles` | reachability and all active connection kinds; `.unknown` and `[]` until reported |
| display — `DeviceDisplay` | `width`, `height`, `density`, `orientation`, `rotation`, `refreshRate` | main display pixels, pixels per layout point, orientation, rotation, and rate; numeric values are `0` and enums `.unknown` until reported |
| locale — `LocaleInfo` | `language`, `region`, `name`, `timeZone`, `uses24HourClock`, `firstDayOfWeek`, `isMetric` | host-normalized language, region, IANA zone, clock and calendar conventions; text starts empty, the clock starts 12-hour, the week on Sunday, and units metric |
| device — `DeviceInfo` | `idiom`, `platform`, `model`, `manufacturer`, `name`, `versionString`, `deviceType` | form factor, open platform name, hardware and system facts; text starts empty and closed values `.unknown` |
| app — `AppInfo` | `name`, `packageName`, `versionString`, `buildString`, `requestedTheme` | manifest identity and live requested appearance; text starts empty and theme `.unspecified` |
| application — `ApplicationSession` | `phase` | process-wide visibility state; the host maps lifecycle to `.active`, `.inactive`, or `.background` |

A host may be unable to observe a domain. The documented fallback remains
visible in that case; an empty string or `.unknown` is data, not a reason to
guess. A malformed complete domain update is refused rather than partially
applied. Closed enum values unknown to the runtime degrade to `.unknown` while
open vocabulary, such as `DeviceInfo.platform`, stays authored text.

The closed vocabulary used by these fields is:

| Type | Cases |
| --- | --- |
| `BatteryState` | `unknown`, `charging`, `discharging`, `full`, `notCharging`, `notPresent` |
| `BatteryPowerSource` | `unknown`, `battery`, `ac`, `usb`, `wireless` |
| `EnergySaverStatus` | `unknown`, `on`, `off` |
| `NetworkAccess` | `unknown`, `none`, `local`, `constrainedInternet`, `internet` |
| `ConnectionProfile` | `unknown`, `bluetooth`, `cellular`, `ethernet`, `wiFi` |
| `DisplayOrientation` | `unknown`, `portrait`, `landscape` |
| `DisplayRotation` | `unknown`, `rotation0`, `rotation90`, `rotation180`, `rotation270` |
| `Weekday` | `sunday` through `saturday` |
| `DeviceIdiom` | `unknown`, `phone`, `tablet`, `desktop`, `tv`, `watch` |
| `DeviceType` | `unknown`, `physical`, `virtual` |
| `AppTheme` | `unspecified`, `light`, `dark` |
| `ApplicationPhase` | `active`, `inactive`, `background` |

The [Platform contract](platform-contract.md) is the implementation-status
authority. A public provider describes the StateUI schema; it does not imply
that every host can produce every fact. Where no checked host integration
proves a capability, rely on the documented fallback.

### Reading platform facts

```swift
struct RuntimeSummary: ContentView {
    @Environment private var device: DeviceInfo
    @Environment private var display: DeviceDisplay
    @Environment private var locale: LocaleInfo
    @Environment private var app: AppInfo

    var content: any View {
        VStack {
            Label("\(app.name) \(app.versionString)")
            Label("\(device.platform) · \(device.idiom)")
            Label("\(Int(display.width / max(display.density, 1))) points wide")
            Label("\(locale.language)-\(locale.region) · \(locale.timeZone)")
        }
    }
}
```

Use `DeviceInfo.idiom` for a semantic form-factor decision. Use display points
for layout (`pixels / density`) and handle zero density before the first host
report. Use `AppInfo.requestedTheme` only when logic itself branches on the
theme; themed colors resolve through the style and color system directly.

`Connectivity.networkAccess == .internet` means ordinary internet access.
`.constrainedInternet` describes a route with a portal or another constraint,
and `connectionProfiles` may contain more than one active transport.

## Runtime sessions are environments

Four session types are available by the same mechanism:

| Session | Lifetime and ownership |
| --- | --- |
| `ApplicationSession` | one process; styles, default motion, persistent keys and storage, application phase, and open scenes |
| `SceneSession` | one application scene; scene phase, its windows, and scene/window operations |
| `WindowSession` | one native window; lifecycle, title, geometry requests, chrome, modal stack, and close operation |
| `PageSession` | one content-page element; title, toolbar, menus, and page presentation state |

Each scene, window, and page provides its own session nearer than the inert
fallback instance. A descendant therefore acts on the session it is inside:

```swift
struct WindowHeading: ContentView {
    @Environment private var window: WindowSession
    @Environment private var application: ApplicationSession

    var content: any View {
        VStack {
            Label(window.title ?? "Untitled")
            Label("\(application.scenes.count) scene(s)")
        }
    }
}
```

Session properties are state. A body that reads `window.phase` follows its
changes, while a handler holding `window` can call `close()` later and still
refers to that window. The application structure and session ownership are
defined in [Architecture](architecture.md#application-sessions).

## Portable calendar values

StateUI's public date and time values represent what controls actually edit:

- `CalendarDate` is a calendar day: year, month, and day, with no time or zone;
- `ClockTime` is a time of day: hour, minute, second, and an optional
  millisecond, with no day or zone.

```swift
let due = CalendarDate(year: 2026, month: 9, day: 30)
let alarm = ClockTime(hour: 7, minute: 30)

VStack {
    DatePicker(due)
    TimePicker(alarm)
    Label("Due \(due.text) at \(alarm.text)")
}
```

Both types are comparable lexicographically by their components and conform to
`StateValue`, so they can be held in `@State`, bound to a picker, and carried
without a formatter. Their text forms are invariant:

- `CalendarDate.text` is `YYYY-MM-DD`;
- `ClockTime.text` is `HH:MM:SS` and omits milliseconds.

The string initializers accept those invariant forms (`ClockTime` also accepts
`HH:MM` and `HH:MM:SS.sss`) and return `nil` for another shape. Initializers do
not validate whether the components form a real calendar day or normalized
time. Validate authored or external data before handing it to a native picker.

A `ClockTime` carried through a picker uses hour, minute, and second. The
millisecond is retained by direct values such as `ClockTime.now()`, but a picker
does not display or report it.

## Host clock and time zones

Portable local-time questions are host acts because the host owns the active
clock, locale, and zone database:

```swift
let zone = try await TimeZoneInfo.local()
let now = try await ClockTime.now()
let localOffset = try await TimeZoneInfo.getUtcOffset()
let winterOffset = try await TimeZoneInfo.getUtcOffset(
    of: zone,
    on: CalendarDate(year: 2027, month: 1, day: 15))

Label("\(zone) · \(now.text) · \(localOffset.components.seconds) seconds from UTC")
Label("Winter: \(winterOffset.components.seconds) seconds from UTC")
```

`TimeZoneInfo.local()` returns an IANA identifier. `getUtcOffset(of:on:)`
returns a Swift `Duration`, negative west of UTC; omit the zone for the local
zone and omit the date for today. Supplying a date makes daylight-saving
differences explicit. Offset transport uses signed minutes, so half-hour and
quarter-hour zones need no special representation.

These calls throw when the host does not implement the act or returns a value
of the wrong shape. Treat the active host's checked support as part of the
platform contract rather than replacing a failed clock answer with guessed
locale data.

`LocaleInfo.timeZone` is the host's last reported zone and is useful for
reactive display or branching. `TimeZoneInfo.local()` is an explicit fresh
question for work that already runs asynchronously.

## Foundation boundary

The cross-platform StateUI library does not import Foundation. Applications
may import Foundation for their own models, serialization, networking, and
calendar arithmetic:

```swift
import Foundation

let payload = try JSONEncoder().encode(["ready": true])
let size = payload.count
```

Keep portable interface decisions on StateUI's host-normalized boundary:

- use `LocaleInfo` for the current language, region, clock convention, units,
  and IANA zone;
- use `ClockTime.now()` and `TimeZoneInfo` for portable local-clock and offset
  questions;
- use `CalendarDate` and `ClockTime` at control and state boundaries;
- use `Task.sleep` or `Ticker` for application timing, not Foundation
  `Timer` or `RunLoop`;
- use StateUI's `@MainThread` for application handlers, not Swift
  `@MainActor` as a cross-platform UI abstraction.

An application can convert between its Foundation-rich domain model and these
small StateUI values at its boundary. That keeps the library's wire,
description, and native-host contracts deterministic while leaving the
application free to use Foundation where its deployment targets provide the
semantics it needs.

## Related contracts

- [State and reactivity](state-and-reactivity.md) covers state ownership,
  bindings, persistence, journeys, conversions, samples, and engines.
- [Architecture](architecture.md) defines session ownership and the complete
  two-path model.
- [Host contract](host-contract.md) defines typed state channels and host
  reconciliation.
- [Platform contract](platform-contract.md) is the checked implementation
  matrix for standard facts, controls, properties, and events.
