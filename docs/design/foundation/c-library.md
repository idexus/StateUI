# The C library

`StateUIFoundation` is the ground StateUI and an application build on that
needs no interface: today the platform's C library behind one import, and
later what is built on it - the date and time types among them. It is a
module of the StateUI package and travels in the StateUI library, so a
process holds one copy of it.

Every platform names its C library differently - Darwin, Android, Glibc,
CRT on Windows, WASILibc on the Web - and a file that wants `exp`, `sin` or
`pow` would otherwise say all five. `StateUIFoundation` imports the one
there is and passes it on: `import StateUIFoundation` is that arithmetic on
every platform. It passes the library on rather than declaring functions of
its own of the same names, so a file that also imports Apple's Foundation,
which passes Darwin on too, meets one `exp`, not two.

What a platform holds beyond its C library is no part of what it passes on:
a basic built on it imports it under its own condition - Windows' threads
below - and so does a file that needs it for itself, Apple's run loop.

## Which thread

`currentThreadNumber()` says which thread code runs on, as a number to
compare: `pthread_self` where there are POSIX threads, `GetCurrentThreadId`
on Windows, and nought on the Web, where one thread runs everything. The UI
thread's executor keeps the number of the thread it drains on, and compares.
