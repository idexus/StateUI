// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// A controller that can stand as a sheet, telling the window's root as it leaves the screen.
/// Design: docs/design/platforms/uikit/pages.md#sheets
@MainActor
protocol UIKitSheetStanding: UIViewController {
    var leftScreen: (() -> Void)? { get set }
}
#endif
