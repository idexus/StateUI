// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// Where GTK's host writes its log: GLib's, a message of the StateUI domain, which a terminal shows and the journal
/// keeps, as GNOME's applications log.
/// Design: docs/design/host/runtime.md#the-log
enum GTKLog {
    /// Writes `line` to GLib's log.
    @Sendable static func write(_ line: String) {
        let words = line.hasSuffix("\n") ? String(line.dropLast()) : line
        "GLIB_DOMAIN".withCString { domainKey in
            "StateUI".withCString { domain in
                "MESSAGE".withCString { messageKey in
                    words.withCString { message in
                        var fields = [
                            GLogField(key: domainKey, value: UnsafeRawPointer(domain), length: -1),
                            GLogField(key: messageKey, value: UnsafeRawPointer(message), length: -1),
                        ]
                        g_log_structured_array(STATEUI_LOG_LEVEL_MESSAGE, &fields, gsize(fields.count))
                    }
                }
            }
        }
    }
}
