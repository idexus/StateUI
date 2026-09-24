# The AppKit runtime

What the AppKit host reads of the Mac it runs on and tells the core, beside
what [the host layer](../../host/runtime.md) shares with every runtime.

## The environment

The device, the main display, the application and the system's appearance are
told as the runtime starts. The user's locale, the battery and the network are
told as the application starts and again whenever one changes, for as long as
it runs: the locale when the user or the time zone changes it, the battery when
macOS reports its power source or Low Power Mode turns, the network when its
path moves. The locale's language decides the root's layout direction. A Mac
with no battery reports none - full, on mains - and Low Power Mode as the
battery saver. The network is reachable when its path is satisfied, local when
interfaces stand but no route leads out; each interface in use - Wi-Fi, wired,
cellular - is a connection profile.
