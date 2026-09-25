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
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case cleaners
    case locations
    case about

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .general: "General"
        case .cleaners: "Scan sources"
        case .locations: "Locations"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .cleaners: "sparkles"
        case .locations: "folder"
        case .about: "info.circle"
        }
    }
}

private struct CleanerSettingsGroup: Identifiable {
    let group: CleanupGroup
    let settings: [CleanerSetting]
    var id: String { group.rawValue }
}

struct SettingsRootView: View {
    @State private var selection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(VibeStrings.value(section.titleKey), systemImage: section.symbol)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("VibeCleaner")
        } detail: {
            Group {
                switch selection ?? .general {
                case .general: GeneralSettingsView()
                case .cleaners: CleanersSettingsView()
                case .locations: LocationsSettingsView()
                case .about: AboutSettingsView()
                }
            }
            .frame(minWidth: 470, minHeight: 440)
        }
        .frame(minWidth: 690, minHeight: 520)
        .tint(VibePalette.accent)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var store: CleanerStore
    @EnvironmentObject private var loginManager: LoginItemManager
    @AppStorage("scanIntervalHours") private var scanIntervalHours = 6
    @AppStorage("automaticScanningEnabled") private var automaticScanningEnabled = true

    private let intervals = [2, 6, 12, 24]

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { loginManager.isEnabled },
                    set: { loginManager.setEnabled($0) }
                )) {
                    VibeText("Start at login")
                }
                Toggle(isOn: $automaticScanningEnabled) {
                    VibeText("Scan automatically")
                }
                Picker(selection: $scanIntervalHours) {
                    ForEach(intervals, id: \.self) { hours in
                        Text(verbatim: String(format: VibeStrings.value("Every %lld hours"), hours))
                            .tag(hours)
                    }
                } label: {
                    VibeText("Scan interval")
                }
                .disabled(!automaticScanningEnabled)
            } header: {
                VibeText("General")
            }

            Section {
                VibeText("VibeCleaner follows your Mac's preferred language. English and Portuguese are available.")
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            } header: {
                VibeText("Language")
            }

            Section {
                VibeText("VibeCleaner scans selected development folders, then waits quietly until you open it or the next scheduled scan is due.")
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
            } header: {
                VibeText("Background activity")
            }

            if let message = loginManager.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    VibeText("You can also manage this app in System Settings → General → Login Items.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    VibeText("Login item")
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .navigationTitle(VibeStrings.value("General"))
        .onChange(of: automaticScanningEnabled) { isEnabled in
            if isEnabled { Task { await store.scan() } }
        }
    }
}

private struct CleanersSettingsView: View {
    @EnvironmentObject private var store: CleanerStore

    private var groups: [CleanerSettingsGroup] {
        CleanupGroup.allCases.compactMap { group in
            let settings = CleanerEngine.cleanerSettings().filter { $0.group == group }
            return settings.isEmpty ? nil : CleanerSettingsGroup(group: group, settings: settings)
        }
    }

    var body: some View {
        Form {
            Section {
                VibeText("Managed storage is measured for context and cannot be cleaned by VibeCleaner.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(groups) { section in
                Section {
                    ForEach(section.settings) { setting in
                        Toggle(isOn: Binding(
                            get: { store.isCleanerEnabled(setting.id) },
                            set: { store.setCleaner(setting.id, enabled: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                VibeText(setting.nameKey)
                                VibeText(setting.detailKey)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                } header: {
                    VibeText(section.group.titleKey)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .navigationTitle(VibeStrings.value("Scan sources"))
    }
}

private struct LocationsSettingsView: View {
    @EnvironmentObject private var store: CleanerStore
    @State private var showingUnsafeLocation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Custom locations", detail: "Add a development folder to scan. Custom folders always need review before cleaning.")
                    if store.customPaths.isEmpty {
                        emptyRow("No custom folders yet.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(store.customPaths, id: \.self) { path in
                                HStack(spacing: 10) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(verbatim: URL(fileURLWithPath: path).lastPathComponent)
                                            .fontWeight(.medium)
                                        Text(verbatim: path)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    if let bytes = store.candidates.first(where: { $0.path == path })?.bytes {
                                        Text(verbatim: VibeFormat.bytes(bytes))
                                            .monospacedDigit()
                                    }
                                    Button(role: .destructive) {
                                        store.removeCustomPath(path)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(VibeStrings.value("Remove location"))
                                }
                                .padding(.vertical, 9)
                                if path != store.customPaths.last { Divider() }
                            }
                        }
                        .padding(.horizontal, 10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }
                    HStack {
                        Spacer()
                        Button {
                            if let url = chooseFolder(title: VibeStrings.value("Choose a folder to scan")), !store.customPaths.contains(url.path) {
                                let before = store.customPaths.count
                                store.addCustomPath(url.path)
                                if store.customPaths.count == before { showingUnsafeLocation = true }
                            }
                        } label: {
                            Label(VibeStrings.value("Add location"), systemImage: "plus")
                        }
                    }
                    VibeText("Home folders and broad personal folders are blocked. The selected folder stays in place; cleanup removes only its contents after confirmation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Exclusions", detail: "Excluded paths are skipped during scans and are preserved during cleanup.")
                    if store.excludedPaths.isEmpty {
                        emptyRow("No excluded folders.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(store.excludedPaths, id: \.self) { path in
                                HStack(spacing: 10) {
                                    Image(systemName: "hand.raised")
                                        .foregroundStyle(.secondary)
                                    Text(verbatim: path)
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button(role: .destructive) {
                                        store.removeExclusion(path)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(VibeStrings.value("Remove exclusion"))
                                }
                                .padding(.vertical, 9)
                                if path != store.excludedPaths.last { Divider() }
                            }
                        }
                        .padding(.horizontal, 10)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }
                    HStack {
                        Spacer()
                        Button {
                            if let url = chooseFolder(title: VibeStrings.value("Choose a folder to exclude"), allowFiles: true) {
                                store.addExclusion(url.path)
                            }
                        } label: {
                            Label(VibeStrings.value("Add exclusion"), systemImage: "plus")
                        }
                    }
                }
            }
            .padding(22)
        }
        .navigationTitle(VibeStrings.value("Locations"))
        .alert(VibeStrings.value("Choose a smaller development folder"), isPresented: $showingUnsafeLocation) {
            Button(VibeStrings.value("OK"), role: .cancel) { }
        } message: {
            VibeText("Home, system, and broad personal folders cannot be added. Choose a specific project cache or build folder.")
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VibeText(title).font(.system(size: 15, weight: .semibold))
            VibeText(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func emptyRow(_ message: String) -> some View {
        VibeText(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func chooseFolder(title: String, allowFiles: Bool = false) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = VibeStrings.value("Choose")
        panel.canChooseDirectories = true
        panel.canChooseFiles = allowFiles
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        return panel.runModal() == .OK ? panel.url : nil
    }
}

private struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let logo = VibeBrand.logo {
                Image(nsImage: logo)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(VibePalette.accent)
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
            }
            Text("VibeCleaner")
                .font(.system(size: 22, weight: .semibold))
            VibeText("A small macOS menu bar app for developer disk cleanup.")
                .foregroundStyle(.secondary)
            Text(verbatim: String(format: VibeStrings.value("Version %@"), version))
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(verbatim: VibeStrings.value("Made by"))
                    .foregroundStyle(.secondary)
                Link(VibeCreator.name, destination: VibeCreator.website)
                    .fontWeight(.medium)
            }
            Spacer()
            VibeText("Focused scans. Clear choices. Nothing hidden.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
        .navigationTitle(VibeStrings.value("About"))
    }
}
