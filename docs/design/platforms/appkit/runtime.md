# The AppKit runtime

What the AppKit runtime holds, and what it reads of the Mac it runs on and
tells the core, beside what [the host layer](../../host/runtime.md) shares with
every runtime.

## The AppKit runtime

`AppKitRenderer` holds the host layer's runtime (`HostRuntime`) and adds what
is AppKit's: the scenes and their windows, native window restoration, the
page menus in the application's menu bar, the pictures, the doorbell on the
main queue. It presents what a turn rendered through the `Pump`
(`TurnPresenter`): the windows kept in step with the tree, the restored
windows offered to their scenes - a restored window no scene claims by the
presentation after its offer is declined - and it performs the acts the
application calls. A window's or a scene's phase, and what the user settled
on a native control after the phases it moved, wait in the pump's queue and
are rendered in their turn.

## The environment

The device, the main display, the application and the system's appearance are
told as the runtime starts. The user's locale, the battery and the network are
told as the application starts and again whenever one changes, for as long as
it runs, each change through the runtime's one step for it: the system's
appearance when it turns, the locale when the user or the time zone changes it, the battery when
macOS reports its power source or Low Power Mode turns, the network when its
path moves. The locale's language decides the root's layout direction. It is
the locale macOS resolves for the application - its bundle's localization
nearest the user's languages - so an application localized in no language
written right to left lays out left to right, as AppKit's own controls do. A Mac
with no battery reports none - full, on mains - and Low Power Mode as the
battery saver. The network is reachable when its path is satisfied, local when
interfaces stand but no route leads out; each interface in use - Wi-Fi, wired,
cellular - is a connection profile.
