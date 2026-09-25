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

struct CleanupConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: CleanerStore
    @State private var hasStarted = false
    @State private var hasFinished = false
    @State private var broomSwings = false

    let candidates: [CleanupCandidate]
    let totalBytes: Int64
    let onConfirm: () async -> Void

    private var developerToolsOpen: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleID = app.bundleIdentifier?.lowercased() else { return false }
            return bundleID == "com.apple.dt.xcode" || bundleID.contains("androidstudio") || bundleID == "com.google.android.studio"
        }
    }

    private var touchesBuildCaches: Bool {
        candidates.contains {
            ["xcode-derived-data", "xcode-module-cache", "xcode-cache", "gradle-cache"].contains($0.id)
                || $0.origin == .testDevice || $0.origin == .simulatorDevice || $0.origin == .projectDerivedData
        }
    }

    var body: some View {
        Group {
            if hasFinished {
                resultContent
            } else if hasStarted {
                progressContent
            } else {
                confirmationContent
            }
        }
        .padding(20)
        .tint(VibePalette.accent)
        .interactiveDismissDisabled(hasStarted && !hasFinished)
    }

    private var confirmationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(VibePalette.accent)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 4) {
                    VibeText("Ready to clean?")
                        .font(.system(size: 18, weight: .semibold))
                    Text(verbatim: candidates.count == 1
                        ? VibeStrings.value("1 item selected")
                        : String(format: VibeStrings.value("%@ items selected"), "\(candidates.count)"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            List(candidates) { candidate in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        candidateTitle(candidate)
                            .fontWeight(.medium)
                        Spacer()
                        Text(verbatim: VibeFormat.bytes(candidate.bytes))
                            .monospacedDigit()
                    }
                    Text(verbatim: candidate.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 3)
            }
            .listStyle(.inset)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VibeText("Selected total")
                        .fontWeight(.medium)
                    Spacer()
                    Text(verbatim: VibeFormat.bytes(totalBytes))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                VibeText("Archives and current or active simulators stay protected. Selected older simulators and test clones lose their installed apps and device data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if developerToolsOpen && touchesBuildCaches {
                    Label {
                        VibeText("A development tool is open. Wait until builds finish before cleaning its cache.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Button(VibeStrings.value("Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(role: .destructive) {
                    hasStarted = true
                    Task {
                        await onConfirm()
                        hasFinished = true
                    }
                } label: {
                    Text(verbatim: String(format: VibeStrings.value("Clean %@"), VibeFormat.bytes(totalBytes)))
                        .fontWeight(.semibold)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(candidates.isEmpty)
            }
        }
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()

            if let logo = VibeBrand.logo {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(broomSwings ? -10 : 10))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: broomSwings
                    )
                    .onAppear { broomSwings = !reduceMotion }
                    .onDisappear { broomSwings = false }
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(VibePalette.accent)
                    .accessibilityHidden(true)
            }

            VibeText(store.isScanning ? "Updating results…" : "Cleaning in progress")
                .font(.system(size: 20, weight: .semibold))

            if store.isScanning {
                ProgressView()
                    .progressViewStyle(.linear)
                    .accessibilityLabel(VibeStrings.value("Updating results…"))
            } else {
                ProgressView(value: store.cleanupProgress, total: 1)
                    .progressViewStyle(.linear)
                    .accessibilityLabel(VibeStrings.value("Cleaning progress"))
                    .accessibilityValue("\(Int(store.cleanupProgress * 100))%")
            }

            Text(verbatim: String(
                format: VibeStrings.value("%@ of %@ locations processed"),
                "\(store.cleanupCompletedCount)",
                "\(store.cleanupTotalCount == 0 ? candidates.count : store.cleanupTotalCount)"
            ))
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()

            if !store.isScanning {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                    if let current = store.cleanupCurrentCandidate {
                        VibeText("Now cleaning")
                            .foregroundStyle(.secondary)
                        candidateTitle(current)
                    } else {
                        VibeText("Preparing next location…")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12))
                .lineLimit(1)
            }

            VibeText("Keep this window open to follow the cleanup.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: store.cleanupProblems.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(store.cleanupProblems.isEmpty ? VibePalette.accent : VibePalette.review)
                .accessibilityHidden(true)

            VibeText(store.cleanupProblems.isEmpty ? "Cleanup complete" : "Some items were not cleaned")
                .font(.system(size: 20, weight: .semibold))

            Text(verbatim: String(
                format: VibeStrings.value("Approximately %@ freed"),
                VibeFormat.bytes(store.lastCleanedBytes)
            ))
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .monospacedDigit()

            if store.cleanupProblems.isEmpty {
                VibeText("Your development folders have been scanned again.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(store.cleanupProblems) { problem in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: problem.path)
                                    .font(.system(size: 10, design: .monospaced))
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                                Text(verbatim: VibeStrings.value(problem.message))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button(VibeStrings.value("Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func candidateTitle(_ candidate: CleanupCandidate) -> some View {
        if candidate.origin == .catalog {
            VibeText(candidate.nameKey)
        } else {
            Text(verbatim: candidate.nameKey)
        }
    }
}
