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
| `2` | on a command line naming no command, or arguments a command does not take |

A command line naming no command writes the help on standard error. The
argument parser's own status for arguments a command does not take, 64, is
read as `2`.
