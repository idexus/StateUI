# Processes

`ProcessRunner` runs every program the tool starts: a compiler, Gradle, `adb`,
a simulator's tools, the application itself. It stands on swift-subprocess.

## An argument array, never a shell line

A request names its program and its arguments as an array, and each argument
reaches the program as written: no shell reads it, so a space splits nothing,
and `$HOME`, `%PATH%`, `*` and `;` are characters. A program found by name is
looked up on the search path; a program at a path runs from it.

On Windows a program reads one command line, which swift-subprocess builds
from the array by quoting each argument the way `CommandLineToArgvW` reads it
back - but it leaves an empty argument unquoted, so the program would see one
argument fewer than written. The runner refuses a request with an empty
argument there (`ProcessFailure.emptyArgument`) rather than run the program
with arguments it was not given; the refusal goes when swift-subprocess quotes
an empty argument as `""`.

The environment is this tool's own, less the variables a request removes, with
the ones it sets - an operation hands a program exactly the environment it
decided, and a variable this tool inherited reaches no program that was not
meant to see it.

## A program and everything it started

A captured program starts as the leader of a session of its own; on Windows,
swift-subprocess places it in a job object with every process it starts.
Stopping it - its time limit passed, or the task running it cancelled - stops
the whole session:

```text
every process whose session is the leader's      SIGTERM
the grace period passes (5 s unless asked)
every process of the session still running       SIGKILL
```

On Windows the program is asked to close, then the job ends. The run returns
once they are gone, its outcome saying why it was stopped.

The session, not the process group, is what holds a program's descendants. A
program may start its children in process groups of their own - Foundation's
`Process` does, and so do the tools built on it - and a signal to the
leader's group misses them. A session survives a new group, and survives a
parent's end: a process whose parent ended keeps its session. Only a process
that leaves the session itself, as a daemon does, outlives the stop: it chose
to outlive the program that started it.

A session has no controlling terminal, so a program reaching for the terminal
to ask something fails at once instead of waiting on a terminal it cannot
read.

A program's own end does not stop what it started. The run returns when the
program ends, even while a descendant still holds its output: the reading
stops when the program is gone.

The members of a session are found by `getsid` over every process -
`proc_listallpids` on macOS, `/proc` on Linux.

A terminal program shares this tool's standard streams and its process group,
as a program a shell runs in the foreground: the terminal's interrupt reaches
both, and stopping it reaches the program alone.

## Output comes in lines

A captured program's two streams are read at once, as they come, so a program
filling both never blocks on the one not read. Each is cut into lines at a
line feed, a carriage return before it dropped; bytes that are not UTF-8 read
as U+FFFD.

A line longer than 64 KiB comes in pieces, each cut where a character ends.
A program writing one long line - a minified document, a long command -
never ends a run: swift-subprocess's own line reader fails a run on a line
past its limit, so the runner reads bytes and cuts them itself
(`OutputLines`).

## A pipe whose reader ended

A write to a pipe whose reader ended - a served stateui gone before its input
was written, an editor gone before it read the tool's output - fails, and the
caller hears why; it never ends the tool. On macOS and Linux such a write
raises SIGPIPE, which ends a process by default, so the tool ignores it once
before it writes to another program's input or to its own output
(`BrokenPipe.ignore`); a socket's write asks the same of its own (`MSG_NOSIGNAL`,
`SO_NOSIGPIPE`). Windows raises no signal.

## A program the machine keeps

An emulator the tool boots belongs to the machine, as a booted simulator
does, not to the run that asked for it: it is started in a session of its own,
its streams on the null device (`DetachedProcess`, `posix_spawn` with
`POSIX_SPAWN_SETSID`), so a terminal's interrupt that stops the run never
reaches it, and nothing the tool reads waits on its output. Everything else
the tool starts is the run's and ends with it.
