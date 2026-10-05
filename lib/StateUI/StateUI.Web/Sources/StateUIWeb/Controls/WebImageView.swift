// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An Image: the browser's `<img>` showing one of the application's pictures, served beside the page in Images/,
/// fitted in its room as its content mode says.
/// Design: docs/design/platforms/web/controls.md#pictures
@MainActor
final class WebImageView: WebDOMView {
    /// The files the picture's name may stand for, those not tried yet, in order.
    private var candidates: [String] = []

    init() {
        super.init(tag: "img")
        attribute("alt", "")
        listen("error") { [weak self] in self?.tryNext() }
    }

    func apply(source: ImageSource?, aspect: ContentMode) {
        candidates = source.map { PictureArithmetic.files(for: $0.file) } ?? []
        tryNext()
        style("object-fit", Self.fit(aspect))
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
