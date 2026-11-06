# A web view, on every host

What every host decides alike about a `WebView`, whatever web engine it
drives: what a script answers, when the way back and forward are said, and
why a navigation began. Where a document written in place is shown is each
engine's own.

## The source to reload

A reload immediately following a source change uses the complete new
source, even while the native view still shows its previous page.
`WebReloadSource` keeps that request until the adapter reports its native
document committed. A fetched address or a document carried in a data
address then uses native reload. Authored HTML with a base keeps its bytes
and base together: fetching the base does not reproduce that document.
When a native navigation takes over, the authored source is released and
reload follows the native page and its history. The adapter identifies its
own callbacks; the shared rule stores no native navigation or history.

## A script's answer

A script run in the page answers what it evaluated to, as text: words as they
are, a number as it is written, anything else as JSON, and nothing for no
value - `null` or `undefined`. A web engine that hands the value over as JSON
has it read by one rule (`ScriptAnswer`); an engine that hands over the value
itself writes it the same way.

## The way back and forward

Whether there is a page behind and a page ahead is said as it changes, and
only then: a way that did not change is not said again, and the way back is
said before the way forward (`WebHistory`).

## Why a navigation began

A navigation begins for the step the program asked for - back, forward, the
page again - where one was asked, else for what the platform tells: a new
page, a step through the history, the page fetched again. The cause is kept
to the navigation's end, whatever is asked meanwhile, and the next navigation
begins for what is told again (`WebNavigationCause`). A step through the
history the page takes itself goes back where it lands on a page of the way
back as it stood before the step, else forward (`WebHistory.step`); a
platform that keeps no list to read tells no way.

A step with no destination records no request. The adapter reads the
toolkit's capabilities, then `WebNavigationCause.ask(_:if:)` admits the
step before a call that may report synchronously. The mutating access to
the cause ends before that native call. Where a toolkit reports later and
returns whether it took the step, that result can be the admission fact.
A refusal preserves both the current cause and an earlier accepted request
still waiting to begin; it cannot label an unrelated source loaded later.

## A document with no address

A document written in place with an address of its own is shown at that
address. One with none is gone to at an address holding it, because a web
view keeps no history of a document shown without an address, and the way
back and forward is the page's history like any other. On a WebKit web view
and on Android's it is a `data:` address - its words as UTF-8, in base64
(`WebDocument`), from which the document is read back; WebView2 goes to an
address its backend answers with the document. A navigation reports the
address the page stands at. The Web shows every document written in place at
a `blob:` address of the page's own, a `<base>` in it where the document has
an address - right after its doctype, as before it a browser reads the
document in quirks mode (`WebDocument.document(_:base:)`) - and reports it by
its `data:` address.
