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

enum CleanupSafety: String, Codable, Sendable {
    case safe
    case review
    case managed
}

enum CleanupGroup: String, CaseIterable, Codable, Sendable {
    case xcode
    case android
    case packages
    case temporary
    case custom

    var titleKey: String {
        switch self {
        case .xcode: "Xcode"
        case .android: "Android"
        case .packages: "Package managers"
        case .temporary: "Temporary builds"
        case .custom: "Custom locations"
        }
    }
}

enum CandidateOrigin: String, Codable, Sendable {
    case catalog
    case temporary
    case custom
}

struct CleanupCandidate: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nameKey: String
    let detailKey: String
    let group: CleanupGroup
    let safety: CleanupSafety
    let origin: CandidateOrigin
    let path: String
    let bytes: Int64

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }
}

struct ScanReport: Sendable {
    let candidates: [CleanupCandidate]
    let warnings: [String]
}

struct CleanProblem: Identifiable, Hashable, Sendable {
    let path: String
    let message: String
    var id: String { path }
}

struct CleanReport: Sendable {
    let removedBytes: Int64
    let cleanedIDs: [String]
    let problems: [CleanProblem]
}

struct CleanerSetting: Identifiable, Hashable, Sendable {
    let id: String
    let nameKey: String
    let detailKey: String
    let group: CleanupGroup
}
