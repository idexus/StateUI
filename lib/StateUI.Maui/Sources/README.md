# Overview

StateUI's .NET MAUI host: native interfaces written in Swift, rendered with
MAUI controls on Android, iOS, Mac Catalyst, Windows and Linux. `StateUI.Maui`
is the C# half. An application's Swift half comes from the StateUI Swift
package when the application builds, so this package alone does not make an
application. On Linux, `StateUI.Maui.Linux` is referenced beside it.

The working path starts from the template, created against a StateUI checkout
(a directory named `StateUI`):

```
dotnet new install StateUI.Maui.Template
dotnet new stateui-maui -n MyApp --stateui-path /path/to/StateUI
```

`--appkit` adds a native macOS head beside the MAUI one.

**Version 0.4 - the API is still changing.** Use in a project is at your own
risk: names and signatures move between versions while the design is being
found.

# License

Apache License 2.0, Copyright 2026 Paweł Krzywdziński and Contributors
