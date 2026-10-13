// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// Each icon as the platform's own drawable, `android.R.drawable`, which every Android ships.
/// Design: docs/design/platforms/android/drawing.md#icons
extension Icon {
    /// The name of the platform's drawable; nil where Android ships none.
    var androidDrawable: String? {
        switch self {
        case .add: "ic_menu_add"
        case .close: "ic_menu_close_clear_cancel"
        case .search: "ic_menu_search"
        case .share: "ic_menu_share"
        case .edit: "ic_menu_edit"
        case .delete: "ic_menu_delete"
        case .settings: "ic_menu_preferences"
        case .info: "ic_menu_info_details"
        case .warning: "ic_dialog_alert"
        case .up: "arrow_up_float"
        case .down: "arrow_down_float"
        case .more: "ic_menu_more"
        case .refresh: "ic_popup_sync"
        case .download: "stat_sys_download_done"
        case .upload: "ic_menu_upload"
        case .star: "star_big_on"
        case .mail: "ic_dialog_email"
        case .calendar: "ic_menu_my_calendar"
        case .clock: "ic_menu_recent_history"
        case .lock: "ic_lock_lock"
        case .play: "ic_media_play"
        case .pause: "ic_media_pause"
        case .remove, .checkmark, .home, .back, .forward, .menu, .copy, .heart, .person, .link: nil
        }
    }

    /// The icons Android ships no drawable for, in words for the register.
    static var missingOnAndroid: String {
        allCases.filter { $0.androidDrawable == nil }.map { "`.\($0)`" }.joined(separator: ", ")
    }
}
