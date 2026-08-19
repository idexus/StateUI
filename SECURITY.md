# Security Policy

## Reporting a vulnerability

**Please do not open a public issue.** An issue is a public disclosure, and it
puts every application built on this library at risk before there is anything to
upgrade to.

**Use GitHub's own private form:** the *Security* tab, *Report a vulnerability*.
It opens a draft advisory that only you and the maintainer can read, and it is
what a published advisory and a CVE are written from later.

It is the only channel - there is no email address to look for. It needs a
GitHub account, which is free.

**If you truly cannot use it**, open an ordinary issue saying only that you have
a security report and asking how to send it - no detail, nothing reproducible -
and a private channel will be arranged.

## What makes a report actionable

- The version, and the platform - iOS, Android, Mac Catalyst or Windows. A
  Swift/C# boundary behaves differently on each, and several of this library's
  sharpest edges are one platform's alone.
- What an attacker can actually do with it, and what they need first.
- The smallest thing that reproduces it. A failing test or a few lines of Swift
  is worth more than a description.

## What happens next

- **You get an answer.** A vulnerability is the one thing this project answers
  as a matter of course, where an ordinary issue may not -
  [SUPPORT.md](SUPPORT.md) is honest about that. There is still no deadline: one
  person reads these.
- A real report is worked on: the aim is a fix and an advisory. If it is not
  real, you get told why.
- Credit in the advisory, under whatever name you want, unless you would rather
  not be named.
- **No bug bounty.** There is no budget for one.

## Disclosure

Coordinated. Ask for time before publishing; ninety days is the usual window.
If a fix takes longer, you will be told why rather than asked to wait again.

## Which versions

The latest release, and only that one. Before 1.0 there is no long-term support
line and nothing to backport to - a fix ships in the next version.

## What is in scope

The Swift library, the C# renderer, the protocol between them, and the build
scripts. That is what this project controls.

**Not in scope, and better reported where they belong:** .NET MAUI
([dotnet/maui](https://github.com/dotnet/maui/security)), the .NET runtime
([dotnet/runtime](https://github.com/dotnet/runtime/security)), and the Swift
toolchain ([swift.org/security](https://www.swift.org/security/)). A wrapper
attracts reports about the things it wraps; those projects can fix them and this
one cannot.

## Good-faith research

Research carried out in line with this policy - against your own installation,
without reaching anybody else's data or degrading anybody else's service - is
welcome, and nothing here is a basis for a legal complaint about it.
