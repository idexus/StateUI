# The web view on Apple's platforms

AppKit and UIKit realize a WebView alike, as the package they share,
`lib/StateUI/StateUI.Apple`, writes it once (`WebKitView`): WebKit's own web
view is the same on both, and nothing of it is a view of one platform.

## A web view

A WebView is WebKit's own web view ([the host layer's web rules](../../host/web.md)).
A page at an address is loaded; a document written in place with an address
of its own is shown there, and one with none is gone to as a `data:` address -
WebKit keeps no history of a document shown without one, and the user's way
back and forward is the page's history. What the page does comes back as the
element's events: a navigation as it starts, with why, and as it ends, with
how; whether there is a page behind and ahead, said as a whole as a
navigation commits and ends - the way back first, and only a flag that
changed; its web process dying. A step back, forward or a load again the
program asks for carries that as its cause; a page still coming, which WebKit
reloads without asking, is asked for again. Its complete source is kept
by `WebReloadSource` until that native navigation commits. HTML with a base keeps its source
after commit too: fetching the base address does not reproduce the authored
HTML, even when only the document's resources are still loading. Reload
reissues that HTML with the same base while it remains the authored page.
An address or a document carried in a data address uses native reload after
commit. The native navigation's identity keeps an older callback from
clearing the current reload source. A navigation started natively takes
over from the authored source and keeps native reload and history. The
host keeps navigation identities, not the navigation objects themselves.
A script's value is written as JSON and answers as text by the host layer's
rule. A value JSON cannot say - not a number, a date - answers nothing:
Foundation raises on it rather than throwing, so its validity is asked
first, and a script never stops the application.

macOS's WebKit also declares a legacy `WebNavigationKind` and `WebHistory`, so
the shared code names StateUI's and the host layer's in full
(`StateUI.WebNavigationKind`, `StateUIHost.WebHistory`).
