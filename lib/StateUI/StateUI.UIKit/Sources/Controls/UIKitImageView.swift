// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An Image: a `UIImageView` showing one of the application's pictures - its dark one where the user's appearance is
/// dark - an icon, or bytes, filling its room as its aspect says.
@MainActor
final class UIKitImageView: UIImageView {
    private var source: ImageSource?

    init() {
        super.init(frame: .zero)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIKitImageView, _) in view.showPicture() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitImageView is made in code")
    }

    /// The picture and how it fills the room it stands in.
    func apply(source: ImageSource?, aspect: StateUI.ContentMode) {
        self.source = source
        contentMode = switch aspect {
        case .fit: .scaleAspectFit
        case .fill: .scaleAspectFill
        case .stretch: .scaleToFill
        case .center: .center
        }
        clipsToBounds = aspect == .fill
        showPicture()
    }

    private func showPicture() {
        guard let source else {
            image = nil
            return
        }
        let dark = traitCollection.userInterfaceStyle == .dark
        let picture = HostPicture(source, dark: dark)
        image = picture.flatMap(UIKitRenderer.image)
        // An icon is drawn in the colour of the words around it, not the accent.
        if case .icon = picture { tintColor = .label } else { tintColor = nil }
        invalidateIntrinsicContentSize()
    }
}
#endif
