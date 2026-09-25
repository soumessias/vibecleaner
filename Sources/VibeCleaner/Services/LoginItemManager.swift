// Copyright 2026 soumessias
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published private(set) var isEnabled = false
    @Published private(set) var errorMessage: String?

    private init() {
        refresh()
    }

    func enableByDefaultOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "loginItemSetupAttempted") == nil else {
            refresh()
            return
        }
        defaults.set(true, forKey: "loginItemSetupAttempted")
        setEnabled(true)
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
