// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A color picker: AppKit's color well, which opens the system's color panel; each color the user chooses there is
/// reported as the host layer reports it.
/// Design: docs/design/platforms/appkit/views.md#a-color-picker
@MainActor
final class AppKitColorPickerView: NSColorWell {
    /// What a color the user chose does: the host layer carries it.
    var onChosen: ((Color) -> Void)?

    /// The actions the tree gives VoiceOver, which the well answers beside its own.
    private var readerActions: [NSAccessibilityCustomAction] = []

    init() {
        super.init(frame: .zero)
        colorWellStyle = .default
        target = self
        action = #selector(chosen)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitColorPickerView is created in code")
    }

    /// The color it shows where `write` says the tree changed it, whether the panel offers opacity, and whether it
    /// can be opened.
    func apply(color: Color, write: Bool, choosesOpacity: Bool, enabled: Bool) {
        supportsAlpha = choosesOpacity
        if write { self.color = nsColor(color.propValue) ?? .black }
        isEnabled = enabled
    }

    // AppKit's well answers with its own action alone, whatever is set on it.
    override func setAccessibilityCustomActions(_ actions: [NSAccessibilityCustomAction]?) {
        readerActions = actions ?? []
    }

    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        readerActions + (super.accessibilityCustomActions() ?? [])
    }

    @objc private func chosen() {
        let chosen = color.usingColorSpace(.sRGB) ?? color
        onChosen?(ColorChoice.reported(
            (Double(chosen.redComponent), Double(chosen.greenComponent), Double(chosen.blueComponent),
             Double(chosen.alphaComponent)),
            choosesOpacity: supportsAlpha))
    }
}
#endif
