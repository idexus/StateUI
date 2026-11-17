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

## The service listening

`stateui service --listen <address:port>` (`ServiceListener`) accepts
connections on a thread of its own and serves each as `serve --stdio` serves
one: the protocol's connection, the tool's methods, each frame written whole
and in order (`SocketWriter`, which counts what a client leaves unread), the
socket closed once the connection ends. Many clients are served at once, each
its own connection. It says the port it took - `stateui: serving on
10.211.55.2:7979` - and serves until it is stopped, on whichever address it
is given: the loopback, a virtual machine's host-only network, the LAN. It
builds and runs code for whoever reaches it, so it admits a paired client
alone ([Pairing](#pairing)).

A client of the tool reaches another stateui either way (`ServedTool`): the
program that serves it over its standard streams - a guest's `serve --stdio`
through `prlctl exec` - or its service, by address and port; the same
conversation runs over either.

## Pairing

A service admits a client it paired with, and none other (`ServicePairing`,
`Admission`). It shows a pairing code as it starts - six digits, good for ten
minutes and one machine, retired after five wrong tries, and a new one shown
whenever one goes. On the other machine `stateui remote add <name>
<address:port> --code <code>` asks `service/pair` with it - before
`initialize`, the one thing a connection takes then beside a challenge - and
keeps what it is given (`RemoteMachines`): the machine's name here, where its
service listens, the client's id and a token of 32 random bytes from the
system's secure source. The service keeps its clients in its user's state
folder (`service/clients.json`), the client its machines
(`remotes.json`), each readable by its user alone.

Every connection is proved afresh: the client asks `service/challenge` for a
nonce, and `initialize` carries a credential - its id and the HMAC-SHA256 of
the nonce under its token, compared in a time its likeness does not tell -
which the service admits once; the token itself never crosses the network.
A connection with none, or a wrong one, is refused (`-32004`) before anything
runs. `serve --stdio` admits its client as before: the program that started
it is its user. Encryption is a later step, measured system by system: the
messages travel in plain text on the network they are given.

On a Mac a program of another maker reaches the local network only with the
Local Network permission of the application it runs under - Terminal, VS
Code - which macOS asks once; until then a connection fails as the host
unreachable (`EHOSTUNREACH`). A connection to the Mac is not held by it.

## Files through the connection

A folder travels between machines through the connection itself, whichever
road it takes - a program's standard streams or the service - so no machine
reads another's shared folder (`FolderFiles` answering, `FolderTransfer`
asking, `ServedTool.Session` keeping one connection for all of it). The asking
side lists the other's files (`folder/survey`: each file's path, size and
time, but for what a machine makes where it builds - `.build`, `.git`,
`.stateui`, `.swiftpm` and the like - and never through a link), compares
them with its own by size and by a time two seconds apart, and sends what
differs (`files/write`) - or fetches it (`file/read`) - in pieces of at most
4 MiB a message, base64 within the protocol's frames; what the other side
holds beyond them is removed (`files/remove`). A file's first piece starts it
anew beside itself (`<name>.stateui-part`), each next one must follow where
the last ended, and its last puts it in place with its time - a file stands
only once whole. A path names a file inside its folder alone: none empty,
absolute, with `.`, `..` or a backslash. These are queries, answered at once:
a folder of the checkout's 4,476 files is some 27 MB.

