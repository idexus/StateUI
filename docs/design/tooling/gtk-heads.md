# GTK heads

A GTK head is a program SwiftPM builds on Linux for the machine's own
architecture, beside the libraries it links.

## The artifact

`stateui build --host gtk` publishes the program, every library SwiftPM laid
beside it - which the program finds there - and the application's
`Resources/Images` as they are, since GTK draws SVG (`GTKHead`). The program
runs from the artifact; its Swift runtime is the toolchain's. Beside it
stands the application's `stateui.json` (projects.md, A head carries what the
application is), whose identifier is the application ID the desktop entry and
icon are named by, and stands in the artifact's manifest; its name is the
entry's.
`stateui package --host gtk` lays the artifact's files in
`artifacts/<Name>/GTK`, made anew.

## Installing

The desktop shows a window by the entry its application ID names: its name,
its icon in the dash, the links it opens. Writing that entry changes the
user's profile, so it stands apart from the build: `stateui install
--artifact <folder>` (`application/install`) writes
`applications/<id>.desktop` - the program and `%u`, the icon by the ID, the
window matched by the product (`StartupWMClass`), each scheme
`Platforms/GTK/link-schemes` lists as `x-scheme-handler/<scheme>` - and
copies `Resources/AppIcon/appicon_gnome.svg` to
`icons/hicolor/scalable/apps/<id>.svg`, under `XDG_DATA_HOME`, else
`~/.local/share`; then makes the entry each scheme's default (`xdg-mime`).
A head with no ID or no icon installs nothing. Installing never builds: it
takes a published artifact as it stands.

## Running

`stateui run --host gtk` builds, installs, stops a copy of the program still
running - a GTK application is one instance, and a second start would only
bring the first forward - and runs it, its output told as it comes; Ctrl+C
ends it. With `--device` naming a guest or a machine paired, all of it happens
there, the output told here.

With `--gdb` (`RunRequest.gdb`) it runs under gdb. A breakpoint on
`g_return_if_fail_warning` says each GTK critical - its domain and
expression read from the architecture's argument registers - with its stack,
and the program goes on; a signal that stops it says its stack and every
thread's. gdb ends as the program does: one that ends by itself with its own
status and no stop said, one a signal stopped as that signal would, 128 and
its number - so the run fails on a crash and only on one, on another machine
as here (`application/run`'s `debugger`). gdb 17 says of every Clang module a Swift
library's debug information names - read as split DWARF, which it is not -
`During symbol reading: Could not find DWO CU ….pcm(…)`, some two thousand
lines a start that no setting of its own quiets (`complaints`, its worker
threads): the run leaves those lines out, and every other gdb word stays.
