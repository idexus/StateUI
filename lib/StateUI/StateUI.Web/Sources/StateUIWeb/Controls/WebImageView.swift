// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An Image: the browser's `<img>` showing one of the application's pictures, served beside the page in Images/,
/// fitted in its room as its content mode says - its own size the picture's, which a room wider than it leaves as
/// tall as the picture is.
/// Design: docs/design/platforms/web/controls.md#pictures
@MainActor
final class WebImageView: WebDOMView {
    /// The files the picture's name may stand for, those not tried yet, in order.
    private var candidates: [String] = []

    /// The picture as last given, by its identity.
    private var given: String?

    /// The file shown now, and how it fills its room.
    private var shown: String?
    private var aspect = ContentMode.fit

    /// What its layout wrote of the lengths a filling picture reaches past, as written.
    private var laid: [String: String?] = [:]

    init() {
        super.init(tag: "img")
        attribute("alt", "")
        attribute("class", "stateui-picture")
        listen("error") { [weak self] in self?.tryNext() }
        listen("load") { [weak self] in self?.sizeAsLoaded() }
    }

    /// Shows `picture`, fitted as `aspect` says - a file served beside the page, an icon of the Web's own as a mask
    /// over the words' colour, or bytes as a `data:` URL; the same picture again is shown anew only where the aspect
    /// turns to or from stretched.
    func apply(picture: HostPicture?, aspect: ContentMode) {
        style("object-fit", Self.fit(aspect))
        let restretched = (aspect == .stretch) != (self.aspect == .stretch)
        let refilled = (aspect == .fill) != (self.aspect == .fill)
        self.aspect = aspect
        if refilled { for name in Self.reached { style(name, laid[name] ?? nil) } }
        guard picture?.identity != given else { return restretched ? showFile() : () }
        given = picture?.identity
        attribute("data-source", picture?.file ?? picture.map { if case .icon(let icon) = $0 { "icon:\(icon)" } else { "" } })
        mask(picture.flatMap { if case .icon(let icon) = $0 { icon } else { nil } })
        switch picture {
        case .icon:
            candidates = []
            shown = nil
            attribute("src", WebIcons.room)
        case .bytes(let bytes):
            candidates = []
            shown = nil
            attribute("src", WebPictureData.url(bytes))
        case .file(let file):
            candidates = PictureArithmetic.files(for: file)
            tryNext()
        case nil:
            candidates = []
            tryNext()
        }
    }

    /// Wears `icon` as a mask over the colour of the words around it; nil wears none.
    private func mask(_ icon: Icon?) {
        let url = icon.map(WebIcons.url)
        for name in ["mask-image", "-webkit-mask-image"] { style(name, url) }
        for name in ["mask-size", "-webkit-mask-size"] { style(name, icon == nil ? nil : "contain") }
        for name in ["mask-repeat", "-webkit-mask-repeat"] { style(name, icon == nil ? nil : "no-repeat") }
        for name in ["mask-position", "-webkit-mask-position"] { style(name, icon == nil ? nil : "center") }
        style("background-color", icon == nil ? nil : "currentColor")
    }

    /// The picture's own size, which the view stands at where its layout gives it none - its proportions binding
    /// neither length to the other.
    private func sizeAsLoaded() {
        let width = WebRelay.number(of: node, "naturalWidth"), height = WebRelay.number(of: node, "naturalHeight")
        style("contain-intrinsic-size", "\(WebCSS.pixels(width) ?? "0px") \(WebCSS.pixels(height) ?? "0px")")
    }

    /// Shows the next file the name may stand for: a PNG not found gives way to its SVG.
    private func tryNext() {
        shown = candidates.isEmpty ? nil : candidates.removeFirst()
        showFile()
    }

    /// Shows the file: a drawing stretched across its room is told to give up its own proportions, which it keeps
    /// inside any room it is given.
    /// Design: docs/design/platforms/web/controls.md#pictures
    private func showFile() {
        guard let shown else { return attribute("src", nil) }
        let unproportioned = aspect == .stretch && shown.hasSuffix(".svg")
        attribute("src", "Images/" + shown + (unproportioned ? "#svgView(preserveAspectRatio(none))" : ""))
    }

    /// A filling picture reaches two pixels past each edge of its room, under its parent's clip: WebKit draws a
    /// covering picture rounded inward - by more than a pixel on a turned card - and what lies over it would show
    /// at the seam.
    /// Design: docs/design/platforms/web/controls.md#pictures
    override func style(_ name: String, _ value: String?) {
        guard Self.reached.contains(name) else { return super.style(name, value) }
        laid[name] = value
        guard aspect == .fill else { return super.style(name, value) }
        super.style(name, name.hasPrefix("margin-") ? value.map { "calc(\($0) - 2px)" } ?? "-2px"
            : value.map { "calc(\($0) + 4px)" })
    }

    override var reach: Double { aspect == .fill ? 2 : 0 }

    /// The lengths a filling picture reaches past: its margins, and the sizes its room bounds it to.
    private static let reached = ["inline-start", "block-start", "inline-end", "block-end"].map { "margin-" + $0 }
        + ["width", "height", "max-width", "max-height"]

    private static func fit(_ aspect: ContentMode) -> String {
        switch aspect {
        case .fit: "contain"
        case .fill: "cover"
        case .stretch: "fill"
        case .center: "none"
        }
    }
}
