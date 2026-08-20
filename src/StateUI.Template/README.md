# Overview

Write .NET MAUI user interfaces in Swift. Project template.

**Version 0.1 - the API is still changing.** Use in a project is at your own
risk: names and signatures move between versions while the design is being
found.

```
dotnet new install StateUI.Template
dotnet new stateui -n MyApp
```

Name the app with letters and digits only: the name becomes the Swift module
and the Android application id, and a hyphen or space in either fails far from
its cause.

The FIRST build takes ten minutes or more and is not a hang: it compiles
swift-syntax from source, for the macro plugin behind `@StateClass`. Nothing of
it ships in the app, and it is paid once - every build after it is seconds.

# License

Apache License 2.0, Copyright 2026 Paweł Krzywdziński and Contributors
