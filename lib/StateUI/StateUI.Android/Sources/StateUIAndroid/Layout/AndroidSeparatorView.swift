// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A separator in a stack: a plain view drawn with the theme's list divider, as thick as that line both ways - the
/// stack stretches it across, its axis keeps it thin.
/// Design: docs/design/host/layout.md#a-separator-in-a-stack
@MainActor
final class AndroidSeparatorView: AndroidView {
    init() {
        super.init { _ in
            Java.frame {
                Java.callStaticObject(JavaAPI.views, JavaAPI.separator, .object(AndroidRenderer.context))
                    .map(JavaObject.init)
            }!
        }
    }

    override func measure(width: Int32, height: Int32) -> (width: Int32, height: Int32) {
        super.measure(width: ViewConstants.exactOnly(width), height: ViewConstants.exactOnly(height))
    }
}
