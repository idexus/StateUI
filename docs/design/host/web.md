# A web view, on every host

What every host decides alike about a `WebView`, whatever web engine it
drives: what a script answers, when the way back and forward are said, and
why a navigation began. Where a document written in place is shown is each
engine's own.

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
begins for what is told again (`WebNavigationCause`).

## A document with no address

A document written in place with an address of its own is shown at that
address. One with none is gone to at an address holding it, because a web
view keeps no history of a document shown without an address, and the way
back and forward is the page's history like any other. On a WebKit web view
and on Android's it is a `data:` address - its words as UTF-8, in base64
(`WebDocument`), from which the document is read back; WebView2 goes to an
address its backend answers with the document. A navigation reports the
address the page stands at.
