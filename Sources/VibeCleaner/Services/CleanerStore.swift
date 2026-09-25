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

@MainActor
final class CleanerStore: ObservableObject {
    static let shared = CleanerStore()

    @Published private(set) var candidates: [CleanupCandidate] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var scanWarnings: [String] = []
    @Published private(set) var cleanupProblems: [CleanProblem] = []
    @Published private(set) var lastCleanedBytes: Int64 = 0
    @Published private(set) var cleanupProgress: Double = 0
    @Published private(set) var cleanupCompletedCount = 0
    @Published private(set) var cleanupTotalCount = 0
    @Published private(set) var cleanupCurrentCandidateID: String?
    @Published private(set) var enabledCleanerIDs: Set<String>
    @Published private(set) var selectedIDs: Set<String>
    @Published private(set) var customPaths: [String]
    @Published private(set) var excludedPaths: [String]

    private let defaults = UserDefaults.standard
    private let candidatesKey = "cachedCandidates"
    private let hasSelectionKey = "hasSavedSelection"
    private let scanCatalogVersion = 5
    private var cleanupProgressSequence = 0

    private init() {
        defaults.register(defaults: ["scanIntervalHours": 6, "automaticScanningEnabled": true])
        let storedEnabled = defaults.stringArray(forKey: "enabledCleanerIDs")
        enabledCleanerIDs = storedEnabled.map { Set($0) } ?? CleanerEngine.defaultEnabledIDs()
        selectedIDs = Set(defaults.stringArray(forKey: "selectedCandidateIDs") ?? [])
        customPaths = defaults.stringArray(forKey: "customPaths") ?? []
        excludedPaths = defaults.stringArray(forKey: "excludedPaths") ?? []
        lastScanDate = defaults.object(forKey: "lastScanDate") as? Date

        if storedEnabled != nil && defaults.integer(forKey: "scanCatalogVersion") < 4 {
            enabledCleanerIDs.formUnion([
                "npm-npx-cache", "playwright-browsers", "puppeteer-browsers",
                "android-virtual-devices", "ollama-models", "huggingface-cache", "project-derived-data"
            ])
            defaults.set(Array(enabledCleanerIDs), forKey: "enabledCleanerIDs")
        }

        if let data = defaults.data(forKey: candidatesKey),
           let decoded = try? JSONDecoder().decode([CleanupCandidate].self, from: data) {
            candidates = decoded
        }
    }

    var safeBytes: Int64 {
        candidates.filter { $0.safety == .safe }.reduce(0) { $0 + $1.bytes }
    }

    var reviewBytes: Int64 {
        candidates.filter { $0.safety == .review }.reduce(0) { $0 + $1.bytes }
    }

    var managedBytes: Int64 {
        candidates.filter { $0.safety == .managed }.reduce(0) { $0 + $1.bytes }
    }

    var discoveredBytes: Int64 {
        safeBytes + reviewBytes + managedBytes
    }

    var reviewCount: Int {
        candidates.filter { $0.safety == .review }.count
    }

    var selectedCandidates: [CleanupCandidate] {
        candidates.filter { $0.safety != .managed && selectedIDs.contains($0.id) }
    }

    var selectedBytes: Int64 {
        selectedCandidates.reduce(0) { $0 + $1.bytes }
    }

    var cleanupCurrentCandidate: CleanupCandidate? {
        candidates.first { $0.id == cleanupCurrentCandidateID }
    }

    var menuBarValue: String {
        safeBytes > 0 ? VibeFormat.bytes(safeBytes) : ""
    }

    var lastScanDescription: String {
        guard let lastScanDate else { return VibeStrings.value("Not scanned yet") }
        let relativeDate = Date.now.timeIntervalSince(lastScanDate).magnitude < 60
            ? VibeStrings.value("Just now")
            : VibeFormat.relativeDate(lastScanDate)
        return String(format: VibeStrings.value("Last scan · %@"), relativeDate)
    }

    func scanIfStale() async {
        let hours = max(1, defaults.integer(forKey: "scanIntervalHours") == 0 ? 6 : defaults.integer(forKey: "scanIntervalHours"))
        guard defaults.integer(forKey: "scanCatalogVersion") < scanCatalogVersion
                || lastScanDate == nil
                || Date().timeIntervalSince(lastScanDate!) >= Double(hours * 3600) else { return }
        await scan()
    }

    func scan() async {
        guard !isScanning && !isCleaning else { return }
        isScanning = true
        scanWarnings = []
        let enabled = enabledCleanerIDs
        let custom = customPaths
        let exclusions = excludedPaths
        let previouslyVisibleIDs = Set(candidates.map(\.id))
        let report = await Task.detached(priority: .utility) {
            CleanerEngine.scan(enabledIDs: enabled, customPaths: custom, excludedPaths: exclusions)
        }.value

        candidates = report.candidates
        scanWarnings = report.warnings
        let availableIDs = Set(candidates.map(\.id))
        if defaults.bool(forKey: hasSelectionKey) {
            selectedIDs.formIntersection(availableIDs)
            for candidate in candidates where candidate.safety == .safe && !previouslyVisibleIDs.contains(candidate.id) {
                selectedIDs.insert(candidate.id)
            }
        } else {
            selectedIDs = Set(candidates.filter { $0.safety == .safe }.map(\.id))
            defaults.set(true, forKey: hasSelectionKey)
        }
        lastScanDate = .now
        defaults.set(lastScanDate, forKey: "lastScanDate")
        defaults.set(scanCatalogVersion, forKey: "scanCatalogVersion")
        if let data = try? JSONEncoder().encode(candidates) {
            defaults.set(data, forKey: candidatesKey)
        }
        persistSelection()
        isScanning = false
    }

    func runScheduledScans() async {
        while !Task.isCancelled {
            guard defaults.bool(forKey: "automaticScanningEnabled") else {
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000)
                continue
            }
            let stored = defaults.integer(forKey: "scanIntervalHours")
            let hours = max(1, stored == 0 ? 6 : stored)
            try? await Task.sleep(nanoseconds: UInt64(hours) * 60 * 60 * 1_000_000_000)
            if Task.isCancelled { break }
            await scan()
        }
    }

    func toggleSelection(for candidate: CleanupCandidate) {
        guard candidate.safety != .managed else { return }
        if selectedIDs.contains(candidate.id) {
            selectedIDs.remove(candidate.id)
        } else {
            selectedIDs.insert(candidate.id)
        }
        persistSelection()
    }

    func setSelection(for candidate: CleanupCandidate, selected: Bool) {
        guard !isCleaning, candidate.safety != .managed else { return }
        if selected { selectedIDs.insert(candidate.id) } else { selectedIDs.remove(candidate.id) }
        persistSelection()
    }

    func setAllReviewCandidatesSelected(_ selected: Bool) {
        guard !isCleaning else { return }
        let reviewIDs = Set(candidates.filter { $0.safety == .review }.map(\.id))
        if selected {
            selectedIDs.formUnion(reviewIDs)
        } else {
            selectedIDs.subtract(reviewIDs)
        }
        persistSelection()
    }

    var allReviewCandidatesSelected: Bool {
        let reviewIDs = Set(candidates.filter { $0.safety == .review }.map(\.id))
        return !reviewIDs.isEmpty && reviewIDs.isSubset(of: selectedIDs)
    }

    func isSelected(_ candidate: CleanupCandidate) -> Bool {
        selectedIDs.contains(candidate.id)
    }

    func setCleaner(_ id: String, enabled: Bool) {
        if enabled { enabledCleanerIDs.insert(id) } else { enabledCleanerIDs.remove(id) }
        defaults.set(Array(enabledCleanerIDs), forKey: "enabledCleanerIDs")
        Task { await scan() }
    }

    func isCleanerEnabled(_ id: String) -> Bool {
        enabledCleanerIDs.contains(id)
    }

    func addCustomPath(_ path: String) {
        let normalized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        guard !customPaths.contains(normalized), CleanerEngine.isAllowedCustomPath(normalized) else { return }
        customPaths.append(normalized)
        defaults.set(customPaths, forKey: "customPaths")
        Task { await scan() }
    }

    func removeCustomPath(_ path: String) {
        customPaths.removeAll { $0 == path }
        defaults.set(customPaths, forKey: "customPaths")
        Task { await scan() }
    }

    func addExclusion(_ path: String) {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !excludedPaths.contains(normalized) else { return }
        excludedPaths.append(normalized)
        defaults.set(excludedPaths, forKey: "excludedPaths")
        Task { await scan() }
    }

    func removeExclusion(_ path: String) {
        excludedPaths.removeAll { $0 == path }
        defaults.set(excludedPaths, forKey: "excludedPaths")
        Task { await scan() }
    }

    func cleanSelected() async {
        guard !selectedCandidates.isEmpty, !isCleaning, !isScanning else { return }
        isCleaning = true
        cleanupProblems = []
        lastCleanedBytes = 0
        cleanupProgress = 0
        cleanupCompletedCount = 0
        cleanupProgressSequence = 0
        let selection = selectedCandidates
        cleanupTotalCount = selection.count
        cleanupCurrentCandidateID = nil
        let custom = customPaths
        let exclusions = excludedPaths
        let progressHandler: @Sendable (CleanupProgress) -> Void = { [weak self] update in
            Task { @MainActor [weak self] in
                guard let self, self.isCleaning, update.sequence > self.cleanupProgressSequence else { return }
                self.cleanupProgressSequence = update.sequence
                self.cleanupProgress = update.fraction
                self.cleanupCompletedCount = update.completedCount
                self.cleanupTotalCount = update.totalCount
                self.cleanupCurrentCandidateID = update.currentCandidateID
            }
        }
        let report = await Task.detached(priority: .utility) {
            CleanerEngine.clean(
                candidates: selection,
                customPaths: custom,
                excludedPaths: exclusions,
                onProgress: progressHandler
            )
        }.value
        cleanupProgress = 1
        cleanupCompletedCount = selection.count
        cleanupCurrentCandidateID = nil
        lastCleanedBytes = report.removedBytes
        cleanupProblems = report.problems
        selectedIDs.subtract(report.cleanedIDs)
        persistSelection()
        isCleaning = false
        await scan()
    }

    func clearCleanupResult() {
        lastCleanedBytes = 0
        cleanupProblems = []
        cleanupProgress = 0
        cleanupCompletedCount = 0
        cleanupTotalCount = 0
        cleanupCurrentCandidateID = nil
    }

    private func persistSelection() {
        defaults.set(Array(selectedIDs), forKey: "selectedCandidateIDs")
    }
}
