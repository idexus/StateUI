# Apple bundles

An Apple head runs as a bundle: its program, the libraries it links, its
pictures and its icon, and an `Info.plist` saying what it is.

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
