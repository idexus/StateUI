# Trademark Policy

**StateUI** is a trademark of Paweł Krzywdziński.

The software in this repository is released under the
[Apache License 2.0](LICENSE). That licence grants you rights in the **code**. It
does not grant you rights in the **name** or the logo - its section 6 says so in
as many words, and this file is here to say what you may do with them instead.

The short version: **use the name to talk about this project. Do not use it in a
way that suggests your project is this one, or is endorsed by it.**

## You do not need to ask

- Say that your software uses, supports, is built with, or is compatible with
  StateUI.
- Write about StateUI: articles, tutorials, courses, books, talks, videos - and
  use the name in the title of such material.
- Redistribute unmodified copies of StateUI under the name StateUI.
- Link to the project, and use the logo to do so.
- Name a package that extends or integrates with StateUI, as long as your own
  name comes first - `Acme.StateUI.Charts`, not `StateUI.Charts`.

## Please ask first

- Using **StateUI** as the leading element in the name of your own product,
  package, service or company - *StateUI Pro*, *StateUI Cloud*, *StateUI for X*.
- Using it as a domain name, an organisation name, or a social media handle.
- Anything that suggests this project endorses, sponsors, or is affiliated with
  you.

## Prior and independent use

"State" and "UI" are ordinary words, and other projects have used them -
including together - independently of this one, some of them earlier. Nothing
here is a claim against them. This document describes how to refer to **this**
project, and asks only that you do not present your own work as if it were this
one.

## Forks

You may fork and modify StateUI - the licence says so. **Give your fork a
different name.** You are welcome to say that it is *based on StateUI* or *a fork
of StateUI*; please do not release it as StateUI, because someone downloading it
will reasonably expect the original.

The name is not scattered through the sources. It is in five places, and a fork
that changes them is rebranded:

- `Package.swift` - the Swift module name, which is what `import StateUI` reads.
- `src/StateUI/Sources/Bridge/Exports.swift` - the `@_cdecl("stateui_…")` names.
  They are the C ABI between the Swift half and its host, so a fork that does not
  also fork the host can leave them alone.
- `src/StateUI.Runtime/StateUI.Runtime.csproj` - the NuGet package id.
- `.scripts/StateUI.targets` - the `StateUIApp*` MSBuild properties and the
  native artifact names.
- `src/StateUI.Template/` - the id `dotnet new` installs.

## The logo

Use it to point at this project. Do not alter its shape, proportions or colours,
and do not use it as the icon of your own application.

The artwork a scaffolded app starts with - the icon, the splash, the tile - is
placeholder art carrying the mark, there so a new project builds and runs before
any design work. Replace it with your own before you ship.

## Asking

Open a discussion - or an issue - on the project's GitHub. Reasonable requests
are usually granted, and asking is not a trap.

In the open on purpose: a permission given once is then one anybody can read.

---

This policy is based on the
[Model Trademark Guidelines](https://modeltrademarkguidelines.org/), available
under CC BY 3.0.
