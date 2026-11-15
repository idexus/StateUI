# The command line

`stateui <command> [options]`. Each command writes its result in the format
`--format` names: `text`, words for a person; `json`, the result in its
envelope; `jsonl`, an operation's events and then its result, a document a
line.

## Standard output

In `json` and `jsonl`, standard output holds the envelope and nothing else, so
a program reads it without filtering:

```text
{"apiVersion":"1.0","result":{...}}
```

The envelope is the message an editor receives for the same request, written
by the same encoder - keys sorted, slashes as they are - so the same result is
the same bytes. What a person reads beside a result - an error, the help a
command line naming no command gets - goes to standard error.

## Exit status

The tool ends with one status a kind of ending, so a script tells the kinds
apart without reading words:

| Status | The tool ended |
| --- | --- |
| `0` | with the work done, or with the help that was asked for |
| `1` | on a program it ran failing - SwiftPM unable to read a package |
| `2` | on a command line naming no command, arguments a command does not take, or no project where one is named |
| `3` | missing a program it needs - Swift not found, or what `doctor` was asked to find |
| `6` | serving an editor, when its input ended or broke before it shut the service down - a client lost |
| `130` | interrupted, once the work it stopped has stopped |

A command line naming no command writes the help on standard error. The
argument parser's own status for arguments a command does not take, 64, is
read as `2`.

## An interrupt

The terminal's interrupt - Ctrl+C - stops the command's work instead of
the tool: the work's task is cancelled, so each program it runs is stopped
with every program it started, and the tool ends with status `130` once they
are gone. A second interrupt ends the tool at once, with what is still
running left as it stands. On Windows the console's Ctrl+C and Ctrl+Break are
the interrupt.
