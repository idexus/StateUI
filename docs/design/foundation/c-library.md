# The C library

`StateUIFoundation` is the ground StateUI and an application build on that
needs no interface: the platform's C library behind one import, and what is
built on it. It is a
module of the StateUI package and travels in the StateUI library, so a
process holds one copy of it.

Every platform names its C library differently - Darwin, Android, Glibc,
CRT on Windows, WASILibc on the Web - and a file that wants `exp`, `sin` or
`pow` would otherwise say all five. `StateUIFoundation` imports the one
there is and passes it on: `import StateUIFoundation` is that arithmetic on
every platform. It passes the library on rather than declaring functions of
its own of the same names, so a file that also imports Apple's Foundation,
which passes Darwin on too, meets one `exp`, not two. A platform whose C
library it does not know stops the build there, by name, rather than leaving
an empty module to fail far away at the first `exp`.

What a platform holds beyond its C library is no part of what it passes on:
a basic built on it imports it under its own condition - Windows' threads
below - and so does a file that needs it for itself, Apple's run loop.

An application that imports the foundation meets the C library and nothing
of the foundation's own: every basic it builds on the library is the host's,
behind `@_spi(Host)`, and a guard (`FoundationSurfaceTests`) refuses a
declaration it opens to anyone else.

## Which thread

`currentThreadNumber()`, the host's, says which thread code runs on, as a number to
compare - the thread's own, as a debugger shows it: `pthread_threadid_np` on
Apple, `pthread_self` where there are other POSIX threads, `GetCurrentThreadId`
on Windows, and nought on the Web, where one thread runs everything. Two
threads alive at once never share one; an ended thread's may come back. The UI
thread's executor keeps the number of the thread it drains on, and compares.
An application asks whether it runs on the UI thread as Swift asks it,
`MainActor.preconditionIsolated`.

## The environment and the standard error

`environmentVariable(_:)` reads one of the process's environment variables -
`_dupenv_s` on Windows, `getenv` elsewhere - and `writeStandardError(_:)`
writes to the standard error, which nothing buffers, every byte of it: a write
the system cuts short, or a signal interrupts, goes on from where it stopped.
They stand here, the host's, so the host layer and every host read a switch
and write a line without a condition of their own.

## Conditions

`canImport` asks for a module only to import it; what a platform does is
asked by `os()`. A chain choosing what each platform does names every
platform it knows and ends in `#error`, so a platform it does not know stops
the build by name rather than taking a branch written for another.

## Its tests on every platform

Each branch is proved where it runs: the foundation's tests
(`StateUIFoundationTests`) on the Mac with the root package's, on Linux and on
Windows first in a whole run of the GTK and the WinUI host's tests
(`test-gtk.sh`, `test-winui.ps1`), and the thread number in Android's test
application and in the Web suite, through `@_spi(Host)` as a host imports it, the one platform each that compiles its
branch.
