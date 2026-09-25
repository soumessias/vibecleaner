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

import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?
    private var candidatesSubscription: AnyCancellable?
    private var isConfirmingCleanup = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            button.imagePosition = .imageLeft
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.toolTip = VibeStrings.value("VibeCleaner menu bar item")
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView { [weak self] isPresented in
                self?.isConfirmingCleanup = isPresented
            }
            .environmentObject(CleanerStore.shared)
        )

        candidatesSubscription = CleanerStore.shared.$candidates.sink { [weak self] candidates in
            let safeBytes = candidates.filter { $0.safety == .safe }.reduce(Int64(0)) { $0 + $1.bytes }
            self?.statusItem?.button?.title = safeBytes > 0 ? VibeFormat.bytes(safeBytes) : "VC"
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in self?.closeIfIdle() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            closeIfIdle()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func closeIfIdle() {
        guard popover.isShown, !isConfirmingCleanup, !CleanerStore.shared.isCleaning else { return }
        popover.performClose(nil)
    }
}
