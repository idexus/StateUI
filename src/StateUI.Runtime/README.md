# Overview

Write .NET MAUI user interfaces in Swift. Runtime library - the C# half; the
Swift half arrives through SwiftPM when an app builds, so this package alone
does not make an app. The working path starts from the template:

```
dotnet new install StateUI.Template
dotnet new stateui -n MyApp
```

**Version 0.2 - the API is still changing.** Use in a project is at your own
risk: names and signatures move between versions while the design is being
found.

# License

Apache License 2.0, Copyright 2026 Paweł Krzywdziński and Contributors
