// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view showing web content - a page fetched by URL, or HTML written here.
public enum WebViewContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .webView

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A web view is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// Whether there is a page behind this one changed, to the value it
    /// carries.
    public static let canGoBackChanged = ElementEvent<Self, Bool>("canGoBackChanged", layer: .native)

    /// Whether there is a page ahead of this one changed, to the value it
    /// carries.
    public static let canGoForwardChanged = ElementEvent<Self, Bool>("canGoForwardChanged", layer: .native)

    /// Runs JavaScript in the page, answering what it evaluated to, as text.
    public static let evaluateJavaScript = ElementAct<Self, String, String?>("evaluateJavaScript")

    /// Steps back through the page's history.
    public static let goBack = ElementAct<Self, Void, Void>("goBack")

    /// Steps forward through the page's history.
    public static let goForward = ElementAct<Self, Void, Void>("goForward")

    /// A navigation finished: how it ended, why it happened, and where it went.
    public static let navigated = ElementEvent<Self, (WebNavigationResult, WebNavigationEvent, String)>(
        "navigated", layer: .native)

    /// A navigation started: why, and where it is going.
    public static let navigating = ElementEvent<Self, (WebNavigationEvent, String)>(
        "navigating", layer: .native)

    /// The platform's web process died under the view.
    public static let processTerminated = ElementEvent<Self, Void>("processTerminated", layer: .native)

    /// Loads the page again.
    public static let reload = ElementAct<Self, Void, Void>("reload")

    /// The page it shows: fetched from an address, or written here.
    public static let source = ElementProperty<Self, WebViewSource>("source", layer: .native)

    /// What the view calls itself to the server it asks.
    public static let userAgent = ElementProperty<Self, String>("userAgent", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        canGoBackChanged, canGoForwardChanged, evaluateJavaScript, goBack, goForward, navigated, navigating,
        processTerminated, reload, source, userAgent,
    ]
}
