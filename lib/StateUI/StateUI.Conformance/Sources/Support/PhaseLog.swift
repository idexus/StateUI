// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

extension View {
    /// This view, writing each phase of the life of the page it stands on into `log` as `name` and the phase -
    /// "Root appearing", "Root navigatedTo".
    public func loggingPhases(_ log: Received<String>?, as name: String) -> some View {
        onAppearing { log?.values.append("\(name) appearing") }
            .onDisappearing { log?.values.append("\(name) disappearing") }
            .onNavigatedTo { log?.values.append("\(name) navigatedTo") }
            .onNavigatingFrom { log?.values.append("\(name) navigatingFrom") }
            .onNavigatedFrom { log?.values.append("\(name) navigatedFrom") }
    }
}
