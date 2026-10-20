# The system on Apple's platforms

AppKit and UIKit read much of the system alike, and the package they share,
`lib/StateUI/StateUI.Apple`, reads it once.

## The system's facts

The user's locale - its language and region, the time zone, a 24-hour clock,
the first day of the week, metric measures, the direction words read in - is
read from Foundation's current locale, calendar and time zone; what the
network reaches - the internet, only what is near, or nothing - and through
what is read from the system's path (`SystemFacts`). One watch hears the
locale and the time zone change, and the network, at once and then as it
changes, until the host lets it go (`SystemWatch`). The application is named
by its bundle: the name it shows, its identifier, its version and its build.

What differs is each platform's own and stays in its host: the device and its
screen, the battery - a Mac's power source, a phone's device - and the theme
and the accent, which AppKit reads from the application's appearance and
UIKit from a scene's traits.
