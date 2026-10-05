// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An Image: the browser's `<img>` showing one of the application's pictures, served beside the page in Images/,
/// fitted in its room as its content mode says - its own size the picture's, which a room wider than it leaves as
/// tall as the picture is, as on every host.
/// Design: docs/design/platforms/web/controls.md#pictures
@MainActor
final class WebImageView: WebDOMView {
    /// The files the picture's name may stand for, those not tried yet, in order.
    private var candidates: [String] = []

    /// The picture's name as last given.
    private var file: String?

    init() {
        super.init(tag: "img")
        attribute("alt", "")
        attribute("class", "stateui-picture")
        listen("error") { [weak self] in self?.tryNext() }
        listen("load") { [weak self] in self?.sizeAsLoaded() }
    }

    /// Shows the picture `source` names, fitted as `aspect` says; the same name again changes nothing.
    func apply(source: ImageSource?, aspect: ContentMode) {
        style("object-fit", Self.fit(aspect))
        guard source?.file != file else { return }
        file = source?.file
        attribute("data-source", file)
        candidates = source.map { PictureArithmetic.files(for: $0.file) } ?? []
        tryNext()
    }

    /// The picture's own size, which the view stands at where its layout gives it none - its proportions binding
    /// neither length to the other.
    private func sizeAsLoaded() {
        let width = WebRelay.number(of: node, "naturalWidth"), height = WebRelay.number(of: node, "naturalHeight")
        style("contain-intrinsic-size", "\(WebCSS.pixels(width) ?? "0px") \(WebCSS.pixels(height) ?? "0px")")
    }

    /// Shows the next file the name may stand for: a PNG not found gives way to its SVG.
    private func tryNext() {
        guard !candidates.isEmpty else { return attribute("src", nil) }
        attribute("src", "Images/" + candidates.removeFirst())
    }

    private static func fit(_ aspect: ContentMode) -> String {
        switch aspect {
        case .fit: "contain"
        case .fill: "cover"
        case .stretch: "fill"
        case .center: "none"
        }
    }
}
