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

import Foundation

struct CleanupProgress: Sendable {
    let sequence: Int
    let fraction: Double
    let completedCount: Int
    let totalCount: Int
    let currentCandidateID: String?
}

enum CleanerEngine {
    private struct CatalogEntry {
        let id: String
        let nameKey: String
        let detailKey: String
        let group: CleanupGroup
        let safety: CleanupSafety
        let relativePath: String
    }

    private struct TestDevice {
        let id: UUID
        let name: String
        let path: URL
        let state: String
        let isAvailable: Bool
    }

    private static let testDeviceRoot = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Developer/XCTestDevices", directoryHint: .isDirectory)
        .standardizedFileURL

    private static let catalog: [CatalogEntry] = [
        CatalogEntry(
            id: "xcode-derived-data",
            nameKey: "Derived Data",
            detailKey: "Build products and indexes; Xcode can recreate them.",
            group: .xcode,
            safety: .safe,
            relativePath: "Library/Developer/Xcode/DerivedData"
        ),
        CatalogEntry(
            id: "xcode-module-cache",
            nameKey: "Xcode module cache",
            detailKey: "Compiler module cache; it is rebuilt when needed.",
            group: .xcode,
            safety: .safe,
            relativePath: "Library/Developer/Xcode/ModuleCache.noindex"
        ),
        CatalogEntry(
            id: "xcode-cache",
            nameKey: "Xcode cache",
            detailKey: "Temporary Xcode cache files.",
            group: .xcode,
            safety: .safe,
            relativePath: "Library/Caches/com.apple.dt.Xcode"
        ),
        CatalogEntry(
            id: "gradle-cache",
            nameKey: "Gradle cache",
            detailKey: "Downloaded build dependencies; Gradle can fetch them again.",
            group: .android,
            safety: .safe,
            relativePath: ".gradle/caches"
        ),
        CatalogEntry(
            id: "android-cache",
            nameKey: "Android SDK cache",
            detailKey: "Temporary Android tooling cache; SDKs and virtual devices are kept.",
            group: .android,
            safety: .safe,
            relativePath: ".android/cache"
        ),
        CatalogEntry(
            id: "npm-cache",
            nameKey: "npm cache",
            detailKey: "Downloaded package data; npm can fetch it again.",
            group: .packages,
            safety: .safe,
            relativePath: ".npm/_cacache"
        ),
        CatalogEntry(
            id: "npm-npx-cache",
            nameKey: "npx temporary packages",
            detailKey: "Packages installed by npx; review if a command is still running.",
            group: .packages,
            safety: .review,
            relativePath: ".npm/_npx"
        ),
        CatalogEntry(
            id: "playwright-browsers",
            nameKey: "Playwright browsers",
            detailKey: "Downloaded test browsers; Playwright can install them again.",
            group: .packages,
            safety: .review,
            relativePath: "Library/Caches/ms-playwright"
        ),
        CatalogEntry(
            id: "puppeteer-browsers",
            nameKey: "Puppeteer browsers",
            detailKey: "Downloaded test browsers; Puppeteer can install them again.",
            group: .packages,
            safety: .review,
            relativePath: ".cache/puppeteer"
        ),
        CatalogEntry(
            id: "yarn-cache",
            nameKey: "Yarn cache",
            detailKey: "Downloaded package data; Yarn can fetch it again.",
            group: .packages,
            safety: .safe,
            relativePath: "Library/Caches/Yarn"
        ),
        CatalogEntry(
            id: "pnpm-cache",
            nameKey: "pnpm cache",
            detailKey: "Package store; review before removing if you work offline.",
            group: .packages,
            safety: .review,
            relativePath: "Library/pnpm/store"
        ),
        CatalogEntry(
            id: "swiftpm-cache",
            nameKey: "Swift package cache",
            detailKey: "Downloaded Swift package data; packages can be fetched again.",
            group: .packages,
            safety: .safe,
            relativePath: "Library/Caches/org.swift.swiftpm"
        ),
        CatalogEntry(
            id: "dart-pub-cache",
            nameKey: "Dart package cache",
            detailKey: "Downloaded Dart packages; review first if you work offline.",
            group: .packages,
            safety: .review,
            relativePath: ".pub-cache"
        ),
        CatalogEntry(
            id: "xcode-simulator-devices",
            nameKey: "Simulator devices",
            detailKey: "Installed simulators and their app data; manage them in Xcode.",
            group: .xcode,
            safety: .managed,
            relativePath: "Library/Developer/CoreSimulator/Devices"
        ),
        CatalogEntry(
            id: "xcode-device-support",
            nameKey: "iOS device support",
            detailKey: "Device symbols and support files; keep versions you still debug.",
            group: .xcode,
            safety: .managed,
            relativePath: "Library/Developer/Xcode/iOS DeviceSupport"
        ),
        CatalogEntry(
            id: "xcode-archives",
            nameKey: "Xcode archives",
            detailKey: "Release archives may be needed for distribution and symbolication.",
            group: .xcode,
            safety: .managed,
            relativePath: "Library/Developer/Xcode/Archives"
        ),
        CatalogEntry(
            id: "android-sdk",
            nameKey: "Android SDK and emulators",
            detailKey: "Installed Android SDKs and tools; manage them in Android Studio.",
            group: .android,
            safety: .managed,
            relativePath: "Library/Android/sdk"
        ),
        CatalogEntry(
            id: "android-virtual-devices",
            nameKey: "Android virtual devices",
            detailKey: "Emulators contain apps and settings; manage them in Android Studio.",
            group: .android,
            safety: .managed,
            relativePath: ".android/avd"
        ),
        CatalogEntry(
            id: "ollama-models",
            nameKey: "Ollama models",
            detailKey: "Downloaded AI models; these are not disposable logs.",
            group: .ai,
            safety: .managed,
            relativePath: ".ollama/models"
        ),
        CatalogEntry(
            id: "huggingface-cache",
            nameKey: "Hugging Face model cache",
            detailKey: "Downloaded model snapshots; review if you need them offline.",
            group: .ai,
            safety: .review,
            relativePath: ".cache/huggingface/hub"
        )
    ]

    static var cleanerIDs: [String] {
        catalog.map(\.id) + ["xcode-test-devices", "project-derived-data", "temporary-builds"]
    }

    static func defaultEnabledIDs() -> Set<String> {
        Set(cleanerIDs)
    }

    static func isAllowedCustomPath(_ rawPath: String) -> Bool {
        let url = URL(fileURLWithPath: rawPath, isDirectory: true).standardizedFileURL
        guard isInspectableDirectory(url) else { return false }
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let protectedRoots = [
            "/", "/System", "/Library", "/Applications", "/Users", "/private", "/Volumes",
            home,
            "\(home)/Library", "\(home)/Documents", "\(home)/Desktop", "\(home)/Downloads",
            "\(home)/Pictures", "\(home)/Movies", "\(home)/Music"
        ]
        return !protectedRoots.contains { root in
            url.path == root || (root != "/" && isSameOrDescendant(url.path, of: root))
        }
    }

    static func cleanerSettings() -> [CleanerSetting] {
        let builtIn = catalog.map { CleanerSetting(id: $0.id, nameKey: $0.nameKey, detailKey: $0.detailKey, group: $0.group) }
        return builtIn + [CleanerSetting(
            id: "xcode-test-devices",
            nameKey: "Xcode test devices",
            detailKey: "Inactive test clones are review-only; active or recent devices stay protected.",
            group: .xcode
        ), CleanerSetting(
            id: "project-derived-data",
            nameKey: "Project Derived Data",
            detailKey: "Generated Xcode data inside project .build folders in Documents.",
            group: .xcode
        ), CleanerSetting(
            id: "temporary-builds",
            nameKey: "Temporary build folders",
            detailKey: "Matching folders directly inside /private/tmp; always review before cleaning.",
            group: .temporary
        )]
    }

    static func scan(
        enabledIDs: Set<String>,
        customPaths: [String],
        excludedPaths: [String]
    ) -> ScanReport {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let normalizedExclusions = normalizedPaths(excludedPaths)
        var candidates: [CleanupCandidate] = []
        var warnings: [String] = []

        for entry in catalog where enabledIDs.contains(entry.id) {
            let url = home.appending(path: entry.relativePath).standardizedFileURL
            guard !isExcluded(url.path, by: normalizedExclusions), isInspectableDirectory(url) else { continue }
            let measured = directorySize(at: url, excluded: normalizedExclusions, warnings: &warnings)
            guard measured > 0 else { continue }
            candidates.append(CleanupCandidate(
                id: entry.id,
                nameKey: entry.nameKey,
                detailKey: entry.detailKey,
                group: entry.group,
                safety: entry.safety,
                origin: .catalog,
                path: url.path,
                bytes: measured
            ))
        }

        if enabledIDs.contains("xcode-test-devices") {
            candidates += scanTestDevices(excluded: normalizedExclusions, warnings: &warnings)
        }

        if enabledIDs.contains("project-derived-data") {
            candidates += scanProjectDerivedData(excluded: normalizedExclusions, warnings: &warnings)
        }

        if enabledIDs.contains("temporary-builds") {
            let temporaryRoot = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            if let folders = try? FileManager.default.contentsOfDirectory(
                at: temporaryRoot,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) {
                for folder in folders {
                    guard isInspectableDirectory(folder), isTemporaryBuildFolder(folder),
                          !isExcluded(folder.path, by: normalizedExclusions) else { continue }
                    let measured = directorySize(at: folder, excluded: normalizedExclusions, warnings: &warnings)
                    guard measured > 0 else { continue }
                    let isArchive = folder.pathExtension.lowercased() == "xcarchive"
                    candidates.append(CleanupCandidate(
                        id: "temporary:\(folder.path)",
                        nameKey: folder.lastPathComponent,
                        detailKey: isArchive
                            ? "Release archive · manage in Xcode."
                            : folder.pathExtension.lowercased() == "xcresult"
                                ? "Test result bundle · review before cleaning."
                                : "Temporary build folder · review before cleaning.",
                        group: .temporary,
                        safety: isArchive ? .managed : .review,
                        origin: .temporary,
                        path: folder.standardizedFileURL.path,
                        bytes: measured
                    ))
                }
            }
        }

        let knownPaths = Set(candidates.map { $0.url.path })
        for rawPath in customPaths {
            let url = URL(fileURLWithPath: rawPath, isDirectory: true).standardizedFileURL
            guard !knownPaths.contains(url.path), !isExcluded(url.path, by: normalizedExclusions),
                  isInspectableDirectory(url) else { continue }
            let measured = directorySize(at: url, excluded: normalizedExclusions, warnings: &warnings)
            guard measured > 0 else { continue }
            candidates.append(CleanupCandidate(
                id: "custom:\(url.path)",
                nameKey: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                detailKey: "Custom folder · review before cleaning.",
                group: .custom,
                safety: .review,
                origin: .custom,
                path: url.path,
                bytes: measured
            ))
        }

        candidates.sort {
            if $0.group.rawValue != $1.group.rawValue { return $0.group.rawValue < $1.group.rawValue }
            if $0.bytes != $1.bytes { return $0.bytes > $1.bytes }
            return $0.nameKey.localizedStandardCompare($1.nameKey) == .orderedAscending
        }
        return ScanReport(candidates: candidates, warnings: Array(Set(warnings)).sorted())
    }

    static func clean(
        candidates: [CleanupCandidate],
        customPaths: [String],
        excludedPaths: [String],
        onProgress: @escaping @Sendable (CleanupProgress) -> Void
    ) -> CleanReport {
        let exclusions = normalizedPaths(excludedPaths)
        let normalizedCustomPaths = Set(normalizedPaths(customPaths))
        var removedBytes: Int64 = 0
        var cleanedIDs: [String] = []
        var problems: [CleanProblem] = []
        var completedCount = 0
        var sequence = 0
        var lastUpdate = Date.distantPast
        let totalBytes = candidates.reduce(Int64(0)) { $0 + max(0, $1.bytes) }

        func publish(currentID: String?, force: Bool = false) {
            let now = Date()
            guard force || now.timeIntervalSince(lastUpdate) >= 0.12 else { return }
            lastUpdate = now
            sequence += 1
            let itemFraction = candidates.isEmpty ? 1 : Double(completedCount) / Double(candidates.count)
            let byteFraction = totalBytes > 0 ? Double(removedBytes) / Double(totalBytes) : 0
            onProgress(CleanupProgress(
                sequence: sequence,
                fraction: completedCount == candidates.count ? 1 : min(0.98, max(itemFraction, byteFraction)),
                completedCount: completedCount,
                totalCount: candidates.count,
                currentCandidateID: currentID
            ))
        }

        for candidate in candidates {
            let url = candidate.url
            publish(currentID: candidate.id, force: true)
            guard candidate.safety != .managed,
                  isAuthorized(candidate, normalizedCustomPaths: normalizedCustomPaths),
                  !isExcluded(url.path, by: exclusions),
                  !(candidate.origin == .testDevice && containsExcludedDescendant(url.path, exclusions: exclusions)),
                  isInspectableDirectory(url) else {
                problems.append(CleanProblem(path: candidate.path, message: "This location is no longer available or is outside the cleanup catalog."))
                completedCount += 1
                publish(currentID: nil, force: true)
                continue
            }
            do {
                if candidate.origin == .testDevice {
                    try deleteTestDevice(candidate)
                    removedBytes += candidate.bytes
                    publish(currentID: candidate.id)
                } else {
                    try removeContents(at: url, excluded: exclusions) { amount in
                        removedBytes += amount
                        publish(currentID: candidate.id)
                    }
                }
                cleanedIDs.append(candidate.id)
            } catch {
                problems.append(CleanProblem(path: candidate.path, message: error.localizedDescription))
            }
            completedCount += 1
            publish(currentID: nil, force: true)
        }
        return CleanReport(removedBytes: removedBytes, cleanedIDs: cleanedIDs, problems: problems)
    }

    private static func isAuthorized(_ candidate: CleanupCandidate, normalizedCustomPaths: Set<String>) -> Bool {
        switch candidate.origin {
        case .catalog:
            guard let entry = catalog.first(where: { $0.id == candidate.id }) else { return false }
            let expected = FileManager.default.homeDirectoryForCurrentUser.appending(path: entry.relativePath).standardizedFileURL.path
            return entry.safety != .managed && candidate.path == expected && candidate.safety == entry.safety
        case .temporary:
            let url = candidate.url
            let temporaryRoot = URL(fileURLWithPath: "/private/tmp", isDirectory: true).resolvingSymlinksInPath().path
            return url.deletingLastPathComponent().resolvingSymlinksInPath().path == temporaryRoot
                && isTemporaryBuildFolder(url)
                && candidate.safety == .review
        case .custom:
            return normalizedCustomPaths.contains(candidate.url.path)
                && isAllowedCustomPath(candidate.url.path)
                && candidate.safety == .review
        case .testDevice:
            return isReviewableTestDevice(candidate)
        case .projectDerivedData:
            return candidate.safety == .review && isAllowedProjectDerivedData(candidate.url)
        }
    }

    private static func scanTestDevices(excluded: [String], warnings: inout [String]) -> [CleanupCandidate] {
        guard isInspectableDirectory(testDeviceRoot), !isExcluded(testDeviceRoot.path, by: excluded) else { return [] }
        guard let devices = listedTestDevices() else {
            let bytes = directorySize(at: testDeviceRoot, excluded: excluded, warnings: &warnings)
            guard bytes > 0 else { return [] }
            return [CleanupCandidate(
                id: "xcode-test-devices-unavailable",
                nameKey: "Xcode test devices",
                detailKey: "Test clones could not be verified; open Xcode to manage them.",
                group: .xcode,
                safety: .managed,
                origin: .testDevice,
                path: testDeviceRoot.path,
                bytes: bytes
            )]
        }

        var candidates: [CleanupCandidate] = []
        for device in devices {
            guard isInspectableDirectory(device.path), !isExcluded(device.path.path, by: excluded) else { continue }
            let bytes = directorySize(at: device.path, excluded: excluded, warnings: &warnings)
            guard bytes > 0 else { continue }
            let canReview = isOldInactiveClone(device) && !containsExcludedDescendant(device.path.path, exclusions: excluded)
            candidates.append(CleanupCandidate(
                id: "xctest-device:\(device.id.uuidString)",
                nameKey: "\(device.name) · \(device.id.uuidString.prefix(8))",
                detailKey: canReview
                    ? "Inactive test clone; removing it also removes its installed apps and test state."
                    : "Recent or active test device; kept under Xcode management.",
                group: .xcode,
                safety: canReview ? .review : .managed,
                origin: .testDevice,
                path: device.path.path,
                bytes: bytes
            ))
        }
        return candidates
    }

    private static func listedTestDevices() -> [TestDevice]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "--set", testDeviceRoot.path, "list", "devices", "-j"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let groups = json["devices"] as? [String: [[String: Any]]] else { return nil }
            return groups.values.flatMap { $0 }.compactMap { record in
                guard let idString = record["udid"] as? String,
                      let id = UUID(uuidString: idString),
                      let name = record["name"] as? String,
                      let state = record["state"] as? String,
                      let isAvailable = record["isAvailable"] as? Bool,
                      let dataPath = record["dataPath"] as? String else { return nil }
                let path = testDeviceRoot.appending(path: id.uuidString, directoryHint: .isDirectory).standardizedFileURL
                guard dataPath == path.appending(path: "data").path else { return nil }
                return TestDevice(id: id, name: name, path: path, state: state, isAvailable: isAvailable)
            }
        } catch {
            return nil
        }
    }

    private static func isOldInactiveClone(_ device: TestDevice) -> Bool {
        guard device.name.hasPrefix("Clone "), device.state == "Shutdown", device.isAvailable,
              isInspectableDirectory(device.path),
              let folderValues = try? device.path.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) else { return false }
        // CoreSimulator may update every data directory together while mounting runtimes.
        // The device directory itself gives a more useful guard against newly created clones.
        let latestActivity = [folderValues.creationDate, folderValues.contentModificationDate].compactMap { $0 }.max() ?? .now
        return Date().timeIntervalSince(latestActivity) >= 24 * 60 * 60
    }

    private static func isReviewableTestDevice(_ candidate: CleanupCandidate) -> Bool {
        guard candidate.safety == .review,
              let idString = candidate.id.split(separator: ":").last,
              let id = UUID(uuidString: String(idString)),
              candidate.path == testDeviceRoot.appending(path: id.uuidString).standardizedFileURL.path,
              let device = listedTestDevices()?.first(where: { $0.id == id }) else { return false }
        return isOldInactiveClone(device)
    }

    private static func deleteTestDevice(_ candidate: CleanupCandidate) throws {
        guard isReviewableTestDevice(candidate),
              let idString = candidate.id.split(separator: ":").last,
              let id = UUID(uuidString: String(idString)) else {
            throw NSError(domain: "VibeCleaner", code: 1, userInfo: [NSLocalizedDescriptionKey: "The test device changed since the scan. Scan again before cleaning."])
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "--set", testDeviceRoot.path, "delete", id.uuidString]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "VibeCleaner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Xcode could not remove this test device. Try again after closing tests."])
        }
    }

    private static func scanProjectDerivedData(excluded: [String], warnings: inout [String]) -> [CleanupCandidate] {
        let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Documents", directoryHint: .isDirectory).standardizedFileURL
        guard isInspectableDirectory(root), !isExcluded(root.path, by: excluded) else { return [] }
        var queue: [(URL, Int)] = [(root, 0)]
        var candidates: [CleanupCandidate] = []
        var visited = 0
        while !queue.isEmpty && visited < 5000 {
            let (directory, depth) = queue.removeFirst()
            visited += 1
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []
            ) else { continue }
            for child in children where isInspectableDirectory(child) && !isExcluded(child.path, by: excluded) {
                if child.lastPathComponent == ".build" {
                    guard let artifacts = try? FileManager.default.contentsOfDirectory(
                        at: child,
                        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                        options: []
                    ) else { continue }
                    for artifact in artifacts where isAllowedProjectDerivedData(artifact) && !isExcluded(artifact.path, by: excluded) {
                        let bytes = directorySize(at: artifact, excluded: excluded, warnings: &warnings)
                        guard bytes > 0 else { continue }
                        candidates.append(CleanupCandidate(
                            id: "project-derived:\(artifact.path)",
                            nameKey: "\(directory.lastPathComponent) / \(artifact.lastPathComponent)",
                            detailKey: "Generated project build data; verify no build is running.",
                            group: .xcode,
                            safety: .review,
                            origin: .projectDerivedData,
                            path: artifact.standardizedFileURL.path,
                            bytes: bytes
                        ))
                    }
                } else if depth < 5 && !child.lastPathComponent.hasPrefix(".")
                            && !["node_modules", "Pods", "vendor", "dist", "build"].contains(child.lastPathComponent) {
                    queue.append((child, depth + 1))
                }
            }
        }
        return candidates
    }

    private static func isAllowedProjectDerivedData(_ url: URL) -> Bool {
        let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Documents", directoryHint: .isDirectory).standardizedFileURL
        let standardized = url.standardizedFileURL
        let name = standardized.lastPathComponent.lowercased()
        guard isInspectableDirectory(standardized), standardized.deletingLastPathComponent().lastPathComponent == ".build",
              name == "deriveddata" || name.hasSuffix("deriveddata") || name.hasSuffix("-derived"),
              isSameOrDescendant(standardized.path, of: root.path) else { return false }
        return isSameOrDescendant(standardized.resolvingSymlinksInPath().path, of: root.resolvingSymlinksInPath().path)
    }

    private static func isTemporaryBuildFolder(_ url: URL) -> Bool {
        let value = url.lastPathComponent.lowercased()
        if ["xcresult", "xcarchive"].contains(url.pathExtension.lowercased()) {
            return true
        }
        if ["derived", "build", "packages", "resolve"].contains(where: { value.contains($0) }) {
            return true
        }
        let manager = FileManager.default
        return manager.fileExists(atPath: url.appending(path: "info.plist").path)
            && manager.fileExists(atPath: url.appending(path: "Build").path)
    }

    private static func isInspectableDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private static func normalizedPaths(_ paths: [String]) -> [String] {
        paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
    }

    private static func isExcluded(_ path: String, by exclusions: [String]) -> Bool {
        exclusions.contains { isSameOrDescendant(path, of: $0) }
    }

    private static func isSameOrDescendant(_ path: String, of parent: String) -> Bool {
        let pathParts = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        let parentParts = URL(fileURLWithPath: parent).standardizedFileURL.pathComponents
        return pathParts.count >= parentParts.count && Array(pathParts.prefix(parentParts.count)) == parentParts
    }

    private static func containsExcludedDescendant(_ path: String, exclusions: [String]) -> Bool {
        exclusions.contains { isSameOrDescendant($0, of: path) && $0 != path }
    }

    private static func directorySize(at root: URL, excluded: [String], warnings: inout [String]) -> Int64 {
        guard !isExcluded(root.path, by: excluded),
              let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey],
                options: []
              ) else { return 0 }

        var total: Int64 = 0
        while let item = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            if isExcluded(item.path, by: excluded) {
                enumerator.skipDescendants()
                continue
            }
            do {
                let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey])
                if values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard values.isRegularFile == true else { continue }
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            } catch {
                warnings.append(item.path)
            }
        }
        return total
    }

    private static func removeContents(
        at root: URL,
        excluded: [String],
        onRemoved: (Int64) -> Void
    ) throws {
        guard isInspectableDirectory(root) else { return }
        let children = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey],
            options: []
        )
        for child in children {
            if isExcluded(child.path, by: excluded) { continue }
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey])
            if values?.isSymbolicLink == true { continue }
            if values?.isDirectory == true && containsExcludedDescendant(child.path, exclusions: excluded) {
                try removeContents(at: child, excluded: excluded, onRemoved: onRemoved)
                continue
            }
            let amount = values?.isDirectory == true
                ? directorySizeForRemoval(child)
                : Int64(values?.fileAllocatedSize ?? 0)
            try FileManager.default.removeItem(at: child)
            onRemoved(amount)
        }
    }

    private static func directorySizeForRemoval(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: []
        ) else { return 0 }
        var total: Int64 = 0
        while let item = enumerator.nextObject() as? URL {
            if let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey]),
               values.isRegularFile == true, values.isSymbolicLink != true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }
}
