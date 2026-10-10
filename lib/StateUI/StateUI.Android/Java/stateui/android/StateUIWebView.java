// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.content.Context;
import android.graphics.Bitmap;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.view.MotionEvent;
import android.widget.FrameLayout;
import java.util.Objects;

/**
 * A WebView: the page at an address, or a document written in place. What the page does reaches the Swift
 * view by its number - a navigation starting and ending; whether there is a page behind and ahead; the web
 * process dying; a script's value as JSON - and Swift tells why and what it says. The web view stands in this
 * holder, which makes it again, blank, where its web process died, and shows that page again as it is reloaded.
 */
final class StateUIWebView extends FrameLayout {
    /** How a navigation ended, as StateUI numbers it. */
    private static final int SUCCESS = 1, TIMEOUT = 3, FAILURE = 4;

    private final long view;
    private WebView web;
    /** What hears the page take the keyboard and lose it; none before anything listens. */
    private OnFocusChangeListener focusListener;
    private String userAgent;

    /** The document shown last at its own address, `base`; null after an address was fetched. */
    private String document, base;

    /** Where the page stood as its web process died; null while a page stands. */
    private String lost;

    /** What sees the page's touches and hovering first: its element's gestures. */
    private final StateUIWatch watch = new StateUIWatch();

    /** How the navigation under way failed - none yet. */
    private int failure;

    StateUIWebView(Context context, long view) {
        super(context);
        this.view = view;
        make();
    }

    private void make() {
        web = new WebView(getContext());
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        if (userAgent != null) settings.setUserAgentString(userAgent);
        web.setWebViewClient(new Client());
        web.setOnFocusChangeListener(focusListener);
        addView(web, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
    }

    /**
     * Fetches the page at `address`, asking as `agent`. The agent is written first: written while the page
     * loads, Android leaves the page out of the history, and there is no way back to it.
     */
    void load(String agent, String address) {
        setUserAgent(agent);
        document = null;
        lost = null;
        web.loadUrl(address);
    }

    /** Shows `document` at its own address, `base`, its relative links resolved against it, as `load` does. */
    void show(String agent, String document, String base) {
        setUserAgent(agent);
        this.document = document;
        this.base = base;
        lost = null;
        web.loadDataWithBaseURL(base, document, "text/html", "UTF-8", null);
    }

    /**
     * The page takes the keyboard, not the frame holding it: what hears the frame's focus hears the page's, and the
     * page made again after its process died.
     */
    @Override
    public void setOnFocusChangeListener(OnFocusChangeListener listener) {
        focusListener = listener;
        web.setOnFocusChangeListener(listener);
    }

    /** What the view calls itself to a server from the next page on; none for the platform's own. */
    void setUserAgent(String agent) {
        if (Objects.equals(agent, userAgent)) return;
        userAgent = agent;
        web.getSettings().setUserAgentString(agent);
    }

    /** Steps back in the history; whether there was a page behind. */
    boolean goBack() {
        if (!web.canGoBack()) return false;
        web.goBack();
        return true;
    }

    /** Steps forward in the history; whether there was a page ahead. */
    boolean goForward() {
        if (!web.canGoForward()) return false;
        web.goForward();
        return true;
    }

    /** Loads the page again - in a web view made again after its process died, the page it stood at. */
    void reload() {
        if (lost != null) {
            showAgain();
            return;
        }
        web.reload();
    }

    /** Runs `script` in the page; what it evaluated to answers `ticket`, as JSON. */
    void evaluate(String script, long ticket) {
        web.evaluateJavascript(script, value -> StateUIHost.answered(ticket, true, value));
    }

    /** The web view let go of: nothing it holds calls back any more. */
    void release() {
        removeView(web);
        web.destroy();
    }

    // What the client hears, said to the Swift view.

    void started(String address) {
        failure = 0;
        StateUIHost.webNavigating(view, address);
    }

    void failed(int error) {
        failure = error == WebViewClient.ERROR_TIMEOUT ? TIMEOUT : FAILURE;
    }

    void finished(String address) {
        StateUIHost.webNavigated(view, failure == 0 ? SUCCESS : failure, address);
        historyChanged();
    }

    void historyChanged() {
        StateUIHost.webHistory(view, web.canGoBack(), web.canGoForward());
    }

    void processGone() {
        lost = web.getUrl() != null ? web.getUrl() : document != null ? base : "";
        release();
        make();
        StateUIHost.webProcessGone(view);
        historyChanged();
    }

    /** Shows the page the web view stood at as its process died: the document shown last, or the address. */
    private void showAgain() {
        String at = lost;
        lost = null;
        if (document != null && (at.isEmpty() || at.equals(base) || at.startsWith("data:"))) {
            web.loadDataWithBaseURL(base, document, "text/html", "UTF-8", null);
        } else if (!at.isEmpty()) {
            web.loadUrl(at);
        }
    }

    /** Lets `listener`'s gestures see what the page gets. */
    void watch(StateUIListener listener) {
        watch.watch(listener);
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        return watch.touch(this, event, super::dispatchTouchEvent);
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        return watch.hover(this, event, super::dispatchGenericMotionEvent);
    }

    private final class Client extends WebViewClient {
        @Override
        public void onPageStarted(WebView page, String address, Bitmap icon) {
            started(address);
        }

        @Override
        public void onReceivedError(WebView page, WebResourceRequest request, WebResourceError error) {
            if (request.isForMainFrame()) failed(error.getErrorCode());
        }

        @Override
        public void onPageFinished(WebView page, String address) {
            finished(address);
        }

        @Override
        public void doUpdateVisitedHistory(WebView page, String address, boolean reloading) {
            historyChanged();
        }

        /** The web process died, or was killed: the view it drew is made again, blank. */
        @Override
        public boolean onRenderProcessGone(WebView page, RenderProcessGoneDetail detail) {
            processGone();
            return true;
        }
    }
}
