# The service

Another machine's tool - a Parallels guest's, a computer of the network - is
reached by its service: `stateui service` listening on the network, speaking
the protocol an editor speaks ([The protocol](protocol.md)) over a TCP
connection instead of a program's standard streams. Any machine running it is
a destination of any other: a Mac's guest, a Windows computer from Linux, a
Mac from Windows.

## The socket

The tool reaches the network through a socket layer of its own
(`StreamSocket`), one implementation over each system's sockets - BSD sockets
on macOS and Linux, Winsock on Windows, started once in a process - rather
than a networking library that builds on some systems alone. A socket listens
on an address and a port - any free one for 0 - or connects to one, either
named as the system resolves it (`getaddrinfo`, IPv4 and IPv6 alike); the
first of its places that binds or connects is taken. Reads and writes block,
each on a thread of its own; a read answers nothing once the other end
closed, and a write to a closed connection fails rather than ending the
process (`MSG_NOSIGNAL` on Linux, `SO_NOSIGPIPE` on a Mac). Closing a socket
ends both directions, so a read waiting on it returns. A name nothing
resolves is refused as a configuration; a place that answers no connection,
as a failure of the socket - on Windows only after its retries, some seconds
later (both tests of it take 13 s there, against milliseconds on a Mac and
Linux).
