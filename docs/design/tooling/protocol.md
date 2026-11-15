# The protocol

An editor speaks to `stateui serve --stdio` in JSON-RPC 2.0: requests,
answers and notifications, each a frame on the process's standard input and
output. The terminal's `--format json` writes the same messages' results.
Every message type is Swift in `StateUIToolingProtocol`; nothing generates
them.

## Frames

A frame is a header, a blank line and a JSON body:

```text
Content-Length: 41\r\n
\r\n
{"jsonrpc":"2.0","id":"1","method":"x"}
```

The length counts the body's UTF-8 bytes. A header's names are read in any
case and every header but the length is passed over. Bytes come in whatever
pieces the pipe gives - a header split, a character split, several frames in
one read - and `FrameReader` keeps what it has until a frame is whole.

A header stays within 8 KiB and a body within 16 MiB. Bytes that cannot be a
frame - no length, a length that is not one decimal number, a header past its
limit - end the connection: past a broken frame there is no telling where the
next begins. A whole frame whose body is not JSON is answered with JSON-RPC's
parse error, and the connection goes on.

## A message is read whole

A message holds exactly what its type declares. The envelope holds
`jsonrpc`, `id`, `method`, `params`, `result` and `error`, nothing else; a
method's parameters hold its parameter type's fields, nothing else, at any
depth. An optional field is left out, never `null`.

The rule is one test, not a list of fields kept beside each type: the
parameters are read as their type, written back, and must be the JSON that
came. What did not come back - a field the type has not, a `null` the type
leaves out - is named by its place (`/inner/more`) in the refusal. A client's
misspelled field is refused at once instead of being passed over, and a type
needs nothing written twice.

An id keeps the type it came with - a string, a number, `null` - and the
answer carries it back so. A message with no `id` is a notification and is
never answered.

## A connection's life

```text
created --initialize--> initializing --initialized--> ready --shutdown--> shuttingDown --exit--> closed
```

A new connection answers `initialize` alone. Its answer names the API version
both sides speak - the newest minor of a major both offer - and the methods
the service answers, only those it implements; a client offering no version
the service speaks is refused (`-32001`) before anything runs, and may offer
again. Until `initialized` comes, every other request is refused as not
initialized (`-32002`). After `shutdown`, every request is refused as
shutting down (`-32003`); `exit` ends the connection. A method sent as a
notification does not run: a method is called with an id, and is answered.

Reading never waits on a method. A frame's lifecycle messages and refusals
are answered at once, in the order the frames came; a method's answer is
written when its method returns, so a slow method holds no other, and answers
are matched to requests by id. `shutdown` is answered after every request
accepted before it, and the connection's end waits for every answer still
owed - an answer accepted is never lost to the process ending.

One writer puts frames on standard output, each whole, in the order given;
standard error carries diagnostics, which no client reads as messages. The
process ends with status `0` when the client shut the service down, and `6`
when the input ended or broke first - a client lost.

## An operation and its events

A method that changes something - builds, runs, installs - starts an
operation and answers at once with its handle, `queued`; a client follows it
by its events and reads it whole with `operation/get`. A mutation takes the
client's `requestToken` beside its own parameters: the same token with the
same request is the same operation, run once, and answers with its handle as
it stands; the same token with another request is refused
(`REQUEST_TOKEN_CONFLICT`). A service with no such method offers neither
`operation/get` nor `operation/cancel`.

```text
queued -> running -> succeeded | failed
queued/running -> cancelling -> cancelled
```

The handle is written before the operation starts, so no event comes before
the answer that names its operation - for a batch, before the whole batch's
answer. Events go to the connection that started the operation, numbered from
1 in the order they happened (`operation/event`): a state reached, progress a
tool told, a program's output. The snapshot is written before the event that
tells it, and the terminal state is the operation's last event.

A cancel stops a queued operation at once and a running one through
`cancelling`, which cancels its work's task; the operation is `cancelled`
once its work has ended. Asking again changes nothing, and a cancel after the
operation succeeded or failed is not accepted - its end stands. `shutdown`
and the connection's end cancel the client's operations and wait for them,
within ten seconds, before going on.

A program's output comes in chunks below 64 KiB, cut where a character ends:
text when the bytes are UTF-8, Base64 when they are not. Each carries the
stream's cursor - the bytes written before it and in it - so a client knows
where it stands.

## A client that reads too slowly

The service never waits on a client to read: a program's output is read as
it comes, whatever the editor does. Once more than 8 MiB stand written and
unread, live output is no longer sent; the operation records a gap instead,
and before its next event of any other kind - its end included - it sends
`outputGap` with the cursors the missed output lies between and
`replayAvailable: false`. A gap is never presented as a whole log. States and
progress are always sent. A client leaving more than 8 MiB unread for 30
seconds is lost: the connection ends and its operations stop.

What stands unread is what the connection's writer was given and has not
written yet: `serve --stdio`'s writer counts it (`StandardOutput.backlog`),
since a write to a pipe its reader does not empty waits. A connection is
made with its writer's count - there is no default - so no writer is
silently taken for one that never waits.

A lost client ends the service there (`Connection.lost`): `serve --stdio`
waits neither for its input to close - a client that stopped reading may
never close it - nor for what it was not read to be written, and ends with
the status of a client lost. What the connection held goes with its process:
a package it indexed is another connection's to take. The input is read
beside the connection's life, so its end, an `exit` and a client lost all
end the service the same way.

## The recorded examples

`tools/StateUI.CLI/exports/protocol` holds one example a method - its request
and its answer, and for a method starting an operation, the operation's
`result` as `operation/get` gives it once it succeeded - and one a
notification, written from the Swift types by `ProtocolExamplesTests`
(`STATEUI_UPDATE_EXPORTS=1` records them). The same test sends the examples'
requests to the service in their order and finds the answers the examples
hold, the service's instance, identity and machine aside, and requires an
example of every method the service answers. An editor's client is held to
these files: its own tests read each message with its own types and write it
back the same (`npm run test:tooling` in `editors/VSCode`).
