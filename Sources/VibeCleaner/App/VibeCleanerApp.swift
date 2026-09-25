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

import SwiftUI

@main
@MainActor
struct VibeCleanerApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController
    @StateObject private var store: CleanerStore
    @StateObject private var loginItemManager: LoginItemManager

    init() {
        _store = StateObject(wrappedValue: CleanerStore.shared)
        _loginItemManager = StateObject(wrappedValue: LoginItemManager.shared)
        LoginItemManager.shared.enableByDefaultOnFirstLaunch()
        Task { await CleanerStore.shared.scanIfStale() }
        Task { await CleanerStore.shared.runScheduledScans() }
    }

    var body: some Scene {
        Settings {
            SettingsRootView()
                .environmentObject(store)
                .environmentObject(loginItemManager)
        }
    }
}
