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
import android.widget.FrameLayout;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONTokener;
import java.util.Objects;

/**
 * A WebView: the page at an address, or a document written in place. What the page does reaches the Swift
 * view by its number - a navigation starting and ending, and why; whether there is a page behind and ahead;
 * the web process dying - and back, forward, reload and a script run on its behalf. The web view stands in
 * this holder, which makes it again, blank, where its web process died.
 */
final class StateUIWebView extends FrameLayout {
    /** Why a navigation happens, as StateUI numbers it. */
    private static final int BACK = 1, FORWARD = 2, NEW_PAGE = 3, REFRESH = 4;

    /** How a navigation ended, as StateUI numbers it. */
    private static final int SUCCESS = 1, TIMEOUT = 3, FAILURE = 4;

    private final long view;
    private WebView web;
    private String userAgent;

    /** Why the next navigation happens, and how the one under way failed - none yet. */
    private int cause = NEW_PAGE;
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
        addView(web, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
    }

    /**
     * Fetches the page at `address`, asking as `agent`. The agent is written first: written while the page
     * loads, Android leaves the page out of the history, and there is no way back to it.
     */
    void load(String agent, String address) {
        setUserAgent(agent);
        cause = NEW_PAGE;
        web.loadUrl(address);
    }

    /** Shows `document`, its relative links resolved against `base` where there is one, as `load` does. */
    void show(String agent, String document, String base) {
        setUserAgent(agent);
        cause = NEW_PAGE;
        web.loadDataWithBaseURL(base, document, "text/html", "UTF-8", null);
    }

    /** What the view calls itself to a server from the next page on; none for the platform's own. */
    void setUserAgent(String agent) {
        if (Objects.equals(agent, userAgent)) return;
        userAgent = agent;
        web.getSettings().setUserAgentString(agent);
    }

    void goBack() {
        if (!web.canGoBack()) return;
        cause = BACK;
        web.goBack();
    }

    void goForward() {
        if (!web.canGoForward()) return;
        cause = FORWARD;
        web.goForward();
    }

    void reload() {
        cause = REFRESH;
        web.reload();
    }

    /** Runs `script` in the page; what it evaluated to answers `ticket`, as text. */
    void evaluate(String script, long ticket) {
        web.evaluateJavascript(script, value -> StateUIHost.answered(ticket, true, text(value)));
    }

    /** The web view let go of: nothing it holds calls back any more. */
    void release() {
        removeView(web);
        web.destroy();
    }

    /** A script's value as text: a string as itself, none for null, anything else as JSON writes it. */
    static String text(String json) {
        if (json == null) return null;
        try {
            Object value = new JSONTokener(json).nextValue();
            return value == JSONObject.NULL ? null : value.toString();
        } catch (JSONException malformed) {
            return json;
        }
    }

    // What the client hears, said to the Swift view.

    void started(String address) {
        failure = 0;
        StateUIHost.webNavigating(view, cause, address);
    }

    void failed(int error) {
        failure = error == WebViewClient.ERROR_TIMEOUT ? TIMEOUT : FAILURE;
    }

    void finished(String address) {
        StateUIHost.webNavigated(view, failure == 0 ? SUCCESS : failure, cause, address);
        cause = NEW_PAGE;
        historyChanged();
    }

    void historyChanged() {
        StateUIHost.webHistory(view, web.canGoBack(), web.canGoForward());
    }

    void processGone() {
        release();
        make();
        StateUIHost.webProcessGone(view);
        historyChanged();
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
