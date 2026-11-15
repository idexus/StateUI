# Apple bundles

An Apple head runs as a bundle: its program, the libraries it links, its
pictures and its icon, an `Info.plist` saying what it is, and a signature.

## Info.plist

A bundle's keys are its host's, with the application's own
`Platforms/<Host>/Info.plist` laid over them key by key - a key the
application gives replaces the host's whole, an array or a dictionary
included (`InfoPlist`). The host's keys for macOS: the program, the
identifier `com.stateui.<name in lower case>`, the application's name shown
and spoken, StateUI's release as the bundle's version, the oldest macOS
StateUI runs on (26.4), high resolution, and the icon `StateUI` where the
application has one. What is the application's own - Gallery's name
"StateUI Gallery", its `stateui-gallery://` links, why it asks where you are
- stands in its own file, which its manifest leaves out of the head's
sources; nothing about one application stands in the tool.

## An AppKit bundle

`<Product>.app/Contents` holds in `MacOS` the head and every dynamic library
SwiftPM laid beside it - StateUI's runtime once, its host and the backends
the application links - found from the program by `@loader_path`; in
`Resources` the application's `Images`, carried as they are (AppKit draws
SVG), and `StateUI.icns` drawn from `Resources/AppIcon/appicon_macos.svg`
(pictures.md); and `Info.plist`. The bundle is signed ad hoc as a whole
(`codesign --force --deep --sign -`), which a Mac runs from where it stands;
a signature of a developer's own identity is a package's step. Every
application is a bundle, so every one has its name, identifier and icon in
the Dock and opens its own links.

## A UIKit bundle

`<Product>.app` holds the head at its root, every dynamic library SwiftPM
laid beside it in `Frameworks` - found by the rpath
`@executable_path/Frameworks` added to the head - the application's
`Images` drawn three times over (pictures.md), and the icon: `appicon_mark.svg`
over `appicon_bkg.svg`, one opaque 1024-pixel square in an asset catalog,
compiled by `actool` for the platform into `Assets.car` and the home screen's
pictures, whose keys (`CFBundleIcons`, `CFBundleIcons~ipad`) join
`Info.plist`. The host's keys for iOS: the program, identifier and names as
macOS's, the platform built for (`iPhoneSimulator` or `iPhoneOS`), iOS 26.4
as the oldest, both families, every orientation, a launch screen of the
system's, and many scenes - an iPad's windows. The application's own
`Platforms/UIKit/Info.plist` lies over them all. The pictures and the icon's
catalog are drawn into the build's scratch folder and drawn again only where
their artwork changed. A simulator's bundle is signed ad hoc, the libraries
first; a device's as the next section says.

## Signing for a device

A device runs a bundle a development profile provisions it for. Of this
Mac's profiles - Xcode's `UserData/Provisioning Profiles` and
`MobileDevice/Provisioning Profiles`, each decoded by `security cms` - the
one chosen allows a debugger (`get-task-allow`), is still valid, provisions
the device's UDID or every device, grants the bundle's identifier exactly or
by a wildcard of its team, and names a certificate the keychain holds as a
signing identity (`security find-identity`, by the certificate's SHA-1);
the exact identifier wins over a wildcard, then the latest to expire
(`ProvisioningProfile`). The profile goes into the bundle as
`embedded.mobileprovision`; the libraries, then the bundle, are signed with
that identity and the profile's entitlements, its application identifier the
team's and the bundle's. Where no profile fits, the build is refused before
it compiles: running any application on the device from Xcode once, with a
certificate in the keychain, makes one.
