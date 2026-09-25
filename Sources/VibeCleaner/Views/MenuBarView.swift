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

private enum MenuFilter: String, CaseIterable, Identifiable {
    case all
    case xcode
    case android
    case packages
    case temporary
    case others

    var id: String { rawValue }

    var group: CleanupGroup? {
        switch self {
        case .all: nil
        case .xcode: .xcode
        case .android: .android
        case .packages: .packages
        case .temporary: .temporary
        case .others: .custom
        }
    }

    var titleKey: String {
        switch self {
        case .all: "All"
        case .xcode: "Xcode"
        case .android: "Android"
        case .packages: "Package managers"
        case .temporary: "Temporary"
        case .others: "Others"
        }
    }

    var symbolName: String? {
        switch self {
        case .all: nil
        case .xcode: "hammer.fill"
        case .android: "cpu.fill"
        case .packages: "shippingbox.fill"
        case .temporary: "doc.text.fill"
        case .others: "ellipsis"
        }
    }
}

private struct CandidateGroup: Identifiable {
    let group: CleanupGroup
    let candidates: [CleanupCandidate]
    var id: String { group.rawValue }
}

struct MenuBarView: View {
    @EnvironmentObject private var store: CleanerStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var selectedFilter: MenuFilter = .all
    @State private var showingReviewOnly = false
    @State private var showingConfirmation = false

    private var popoverWidth: CGFloat {
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1280
        let target = min(440, max(360, screenWidth * 0.30))
        return min(target, screenWidth - 24)
    }

    private var popoverHeight: CGFloat {
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 920
        let target = min(520, max(400, availableHeight * 0.58))
        return min(target, availableHeight - 64)
    }

    private var matchingCandidates: [CleanupCandidate] {
        store.candidates.filter { candidate in
            let matchesGroup = selectedFilter.group.map { candidate.group == $0 } ?? true
            return matchesGroup && (!showingReviewOnly || candidate.safety == .review)
        }
    }

    private var groups: [CandidateGroup] {
        CleanupGroup.allCases.compactMap { group in
            let items = matchingCandidates.filter { $0.group == group }.sorted { $0.bytes > $1.bytes }
            return items.isEmpty ? nil : CandidateGroup(group: group, candidates: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    summaryCard
                    filterRail

                    if showingReviewOnly {
                        reviewHeading
                    }

                    if store.isScanning && store.candidates.isEmpty {
                        scanningState
                    } else if store.candidates.isEmpty {
                        emptyState
                    } else if groups.isEmpty {
                        filteredEmptyState
                    } else {
                        candidateGroups
                    }

                    safetyNote

                    if !store.scanWarnings.isEmpty {
                        scanWarnings
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
            }
            .scrollIndicators(.visible)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            footer
        }
        .frame(width: popoverWidth, height: popoverHeight)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        LinearGradient(
                            colors: [Color.blue.opacity(0.10), .clear, Color.cyan.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            }
        }
        .tint(VibePalette.accent)
        .sheet(isPresented: $showingConfirmation) {
            CleanupConfirmationView(
                candidates: store.selectedCandidates,
                totalBytes: store.selectedBytes
            ) {
                await store.cleanSelected()
            }
            .environmentObject(store)
            .frame(width: 430, height: 480)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            if let logo = VibeBrand.logo {
                Image(nsImage: logo)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(VibePalette.accent)
                    .frame(width: 38, height: 38)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("VibeCleaner")
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(-0.3)
                VibeText("Keep your Mac vibe coding.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            MenuIconButton(systemName: "gearshape", titleKey: "Settings") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            MenuIconButton(
                systemName: "arrow.clockwise",
                titleKey: "Scan now",
                isDisabled: store.isScanning || store.isCleaning
            ) {
                Task { await store.scan() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 12)
        }
    }

    private var summaryCard: some View {
        SummaryCard(isCompact: popoverWidth < 470) {
            selectedFilter = .all
            showingReviewOnly = true
        }
        .environmentObject(store)
    }

    private var filterRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 5) {
                ForEach(MenuFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter && !showingReviewOnly

                    Button {
                        selectedFilter = filter
                        showingReviewOnly = false
                    } label: {
                        HStack(spacing: 5) {
                            if let symbol = filter.symbolName {
                                Image(systemName: symbol)
                                    .font(.system(size: 10, weight: .medium))
                                    .accessibilityHidden(true)
                            }
                            VibeText(filter.titleKey)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        }
                        .padding(.horizontal, 9)
                        .frame(minHeight: 28)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.78))
                    .background {
                        Capsule()
                            .fill(isSelected ? VibePalette.action.opacity(0.82) : Color.primary.opacity(0.045))
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(isSelected ? Color.cyan.opacity(0.68) : Color.primary.opacity(0.10), lineWidth: 0.8)
                    }
                    .shadow(color: isSelected ? VibePalette.action.opacity(0.28) : .clear, radius: 9, x: 0, y: 3)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .frame(height: 31)
        .accessibilityLabel(VibeStrings.value("Filter cleanup items"))
    }

    private var reviewHeading: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VibeText("Review queue")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    selectedFilter = .all
                    showingReviewOnly = false
                } label: {
                    VibeText("Show all items")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(VibePalette.accent)
            }

            HStack(spacing: 8) {
                Button {
                    store.setAllReviewCandidatesSelected(!store.allReviewCandidatesSelected)
                } label: {
                    Label(
                        VibeStrings.value(store.allReviewCandidatesSelected
                            ? "Deselect all review items"
                            : "Select all review items"),
                        systemImage: store.allReviewCandidatesSelected ? "checkmark.square.fill" : "square"
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(VibePalette.accent)
                .disabled(store.reviewCount == 0 || store.isCleaning)

                Spacer(minLength: 4)
                VibeText("Check paths before cleaning")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.top, 1)
    }

    private var candidateGroups: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(groups) { section in
                VStack(alignment: .leading, spacing: 5) {
                    GroupHeading(group: section.group, candidates: section.candidates)
                        .environmentObject(store)

                    LazyVStack(spacing: 4) {
                        ForEach(section.candidates) { candidate in
                            CandidateRow(candidate: candidate)
                                .environmentObject(store)
                        }
                    }
                }
            }
        }
    }

    private var scanningState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 3) {
                VibeText("Checking known development folders…")
                    .font(.system(size: 14, weight: .medium))
                VibeText("VibeCleaner follows the folders you selected.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(VibePalette.accent)
                .accessibilityHidden(true)
            VibeText("You're all clear")
                .font(.system(size: 17, weight: .semibold))
            VibeText("No cleanup candidates in the folders you selected.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button {
                Task { await store.scan() }
            } label: {
                Label(VibeStrings.value("Scan now"), systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 13)
                    .frame(minHeight: 36)
            }
            .vibeGlassButton()
            .padding(.top, 3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var filteredEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            VibeText("No items match this filter.")
                .font(.system(size: 14, weight: .medium))
            Button {
                selectedFilter = .all
                showingReviewOnly = false
            } label: {
                VibeText("Show all items")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(VibePalette.accent)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var safetyNote: some View {
        Label {
            VibeText("Managed storage is never cleaned by VibeCleaner.")
        } icon: {
            Image(systemName: "checkmark.shield")
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 1)
    }

    private var scanWarnings: some View {
        Label {
            VibeText("Some folders could not be read. Check folder access in Settings.")
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.system(size: 12))
        .foregroundStyle(VibePalette.review)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var cleanButtonTitle: String {
        if store.isCleaning {
            return VibeStrings.value("Cleaning…")
        }
        if store.isScanning {
            return VibeStrings.value("Checking folders…")
        }
        if store.candidates.isEmpty {
            return VibeStrings.value("Nothing to clean")
        }
        if store.selectedCandidates.isEmpty {
            return VibeStrings.value("Select items above to clean")
        }
        return String(format: VibeStrings.value("Clean %@"), VibeFormat.bytes(store.selectedBytes))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            CleanActionButton(
                title: cleanButtonTitle,
                isEnabled: !store.selectedCandidates.isEmpty && !store.isScanning && !store.isCleaning,
                isCleaning: store.isCleaning
            ) {
                showingConfirmation = true
            }
            .accessibilityHint(VibeStrings.value("Review selected items before cleaning"))

            HStack(spacing: 8) {
                Label {
                    Text(verbatim: store.lastScanDescription)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .layoutPriority(1)

                Spacer(minLength: 6)

                HStack(spacing: 5) {
                    Text(verbatim: VibeStrings.value("Made by"))
                        .foregroundStyle(.secondary)
                    Link(VibeCreator.name, destination: VibeCreator.website)
                        .fontWeight(.medium)
                }
                .font(.system(size: 10))
                .lineLimit(1)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(VibeStrings.value("Quit VibeCleaner"))
                .help(VibeStrings.value("Quit"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }
}

private struct CleanActionButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let isEnabled: Bool
    let isCleaning: Bool
    let action: () -> Void

    @State private var sweep = false
    @State private var broomSwing = false
    @State private var tapBroom = false

    var body: some View {
        Button {
            if !reduceMotion {
                tapBroom = false
                withAnimation(.spring(response: 0.24, dampingFraction: 0.42)) {
                    tapBroom = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        tapBroom = false
                    }
                }
            }
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled || isCleaning
                                ? [Color.cyan.opacity(0.78), Color.blue.opacity(0.88), Color.indigo.opacity(0.78)]
                                : [Color.blue.opacity(0.36), Color.indigo.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if isCleaning && !reduceMotion {
                    GeometryReader { geometry in
                        Capsule()
                            .fill(Color.white.opacity(0.36))
                            .frame(width: 72, height: 150)
                            .blur(radius: 20)
                            .rotationEffect(.degrees(24))
                            .offset(x: sweep ? geometry.size.width + 100 : -130, y: -38)
                    }
                    .clipped()
                }

                HStack(spacing: 9) {
                    Spacer(minLength: 28)

                    Group {
                        if let logo = VibeBrand.logo {
                            Image(nsImage: logo)
                                .renderingMode(.original)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                        } else {
                            Image(systemName: "broom.fill")
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(broomSwing ? -17 : (tapBroom ? -26 : 8)))
                    .accessibilityHidden(true)

                    Text(verbatim: title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .monospacedDigit()

                    Spacer(minLength: 6)

                    Image(systemName: isCleaning ? "sparkles" : "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 29, height: 29)
                        .background(Color.white.opacity(0.11), in: Circle())
                        .overlay { Circle().stroke(Color.white.opacity(0.27), lineWidth: 0.7) }
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
            }
            .frame(height: 60)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.60 : 0.18), lineWidth: 1)
            }
            .shadow(color: VibePalette.action.opacity(isEnabled ? 0.30 : 0), radius: 14, x: 0, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(CleanPressStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .onChange(of: isCleaning) { active in
            if active && !reduceMotion {
                sweep = false
                broomSwing = false
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    sweep = true
                }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    broomSwing = true
                }
            } else {
                sweep = false
                broomSwing = false
            }
        }
    }
}

private struct CleanPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .brightness(configuration.isPressed ? 0.09 : 0)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct SummaryCard: View {
    @EnvironmentObject private var store: CleanerStore
    @State private var showingManagedInfo = false
    let isCompact: Bool
    let onReview: () -> Void

    private var reviewCountLabel: String {
        String(format: VibeStrings.value("Review · %@"), "\(store.reviewCount)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 7) {
                VStack(alignment: .leading, spacing: 4) {
                    VibeText("Development storage found")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.75)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Text(verbatim: VibeFormat.bytes(store.discoveredBytes))
                        .font(.system(size: isCompact ? 30 : 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.8)
                        .foregroundStyle(.primary)
                        .accessibilityLabel("\(VibeStrings.value("Development storage found")): \(VibeFormat.bytes(store.discoveredBytes))")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StorageStackIllustration()
                    .scaleEffect(isCompact ? 0.55 : 0.65)
                    .frame(width: isCompact ? 65 : 78, height: 62)

                if !isCompact {
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1, height: 52)
                        .padding(.horizontal, 3)

                    VibeText("More space. More ideas.")
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 90, alignment: .leading)
                }
            }

            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 7) {
                metric(VibeStrings.value("Ready to clean"), bytes: store.safeBytes, color: VibePalette.accent)

                Button(action: onReview) {
                    metric(reviewCountLabel, bytes: store.reviewBytes, color: VibePalette.review)
                }
                .buttonStyle(.plain)
                .disabled(store.reviewCount == 0)
                .accessibilityHint(VibeStrings.value("Show items that need review"))

                Button {
                    showingManagedInfo = true
                } label: {
                    metric(VibeStrings.value("Managed by tools"), bytes: store.managedBytes, color: .secondary)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                }
                .buttonStyle(.plain)
                .help(VibeStrings.value("About managed storage"))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.12), Color.cyan.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
        }
        .alert(VibeStrings.value("About managed storage"), isPresented: $showingManagedInfo) {
            Button(VibeStrings.value("OK"), role: .cancel) { }
        } message: {
            Text(verbatim: VibeStrings.value("Managed storage includes simulators, test devices, device support, archives and Android SDKs. These are not just logs. VibeCleaner never selects or deletes them."))
        }
    }

    private func metric(_ label: String, bytes: Int64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: VibeFormat.bytes(bytes))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(verbatim: label)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StorageStackIllustration: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [VibePalette.accent.opacity(0.38), Color.blue.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 116, height: 28)
                .shadow(color: VibePalette.accent.opacity(0.22), radius: 12, x: 0, y: 8)
                .offset(y: 34)

            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(index == 2 ? 0.84 : 0.58),
                                VibePalette.accent.opacity(index == 2 ? 0.58 : 0.36),
                                Color.blue.opacity(0.34)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 54, height: 1)
                            .padding(.top, 8)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
                    }
                    .frame(width: 90, height: 48)
                    .offset(x: index == 1 ? 7 : -4, y: CGFloat(27 - index * 21))
                    .zIndex(Double(index))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GroupHeading: View {
    @EnvironmentObject private var store: CleanerStore
    let group: CleanupGroup
    let candidates: [CleanupCandidate]

    private var selectedCandidates: [CleanupCandidate] {
        candidates.filter { store.isSelected($0) }
    }

    private var selectedCountDescription: String {
        if selectedCandidates.count == 1 {
            return VibeStrings.value("1 item selected")
        }
        return String(format: VibeStrings.value("%@ items selected"), "\(selectedCandidates.count)")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VibeText(group.titleKey)
                .font(.system(size: 11.5, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.75)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(verbatim: selectedCandidates.isEmpty
                ? VibeFormat.bytes(candidates.reduce(0) { $0 + $1.bytes })
                : "\(VibeFormat.bytes(candidates.reduce(0) { $0 + $1.bytes })) · \(selectedCountDescription)")
                .font(.system(size: 10.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

private struct CandidateRow: View {
    @EnvironmentObject private var store: CleanerStore
    let candidate: CleanupCandidate

    private var symbolName: String {
        switch candidate.id {
        case "xcode-test-devices": return "testtube.2"
        case "xcode-simulator-devices": return "iphone"
        case "xcode-device-support": return "externaldrive"
        case "xcode-archives": return "archivebox.fill"
        default: break
        }
        return switch candidate.group {
        case .xcode: "hammer.fill"
        case .android: "cpu.fill"
        case .packages: "shippingbox.fill"
        case .temporary: "clock.arrow.circlepath"
        case .custom: "folder.fill"
        }
    }

    private var symbolColor: Color {
        switch candidate.group {
        case .xcode: Color.blue
        case .android: Color.green
        case .packages: Color.orange
        case .temporary: Color.purple
        case .custom: VibePalette.accent
        }
    }

    @ViewBuilder private var candidateName: some View {
        if candidate.origin == .catalog {
            VibeText(candidate.nameKey)
        } else {
            Text(verbatim: candidate.nameKey)
        }
    }

    @ViewBuilder private var candidateDetail: some View {
        VibeText(candidate.detailKey)
    }

    private var safetyKey: String {
        switch candidate.safety {
        case .safe: "Safe to clean"
        case .review: "Review before cleaning"
        case .managed: "Managed by tools"
        }
    }

    private var safetySymbol: String {
        switch candidate.safety {
        case .safe: "checkmark.circle.fill"
        case .review: "eye"
        case .managed: "lock.shield"
        }
    }

    private var safetyColor: Color {
        switch candidate.safety {
        case .safe: VibePalette.accent
        case .review: VibePalette.review
        case .managed: .secondary
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            if candidate.safety == .managed {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .accessibilityLabel(VibeStrings.value("Managed by tools"))
            } else {
                Toggle(isOn: Binding(
                    get: { store.isSelected(candidate) },
                    set: { store.setSelection(for: candidate, selected: $0) }
                )) {
                    EmptyView()
                }
                .labelsHidden()
                .toggleStyle(.checkbox)
                .controlSize(.regular)
                .accessibilityLabel(VibeStrings.value(candidate.nameKey))
            }

            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(symbolColor)
                .frame(width: 29, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                candidateName
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: safetySymbol)
                        .foregroundStyle(safetyColor)
                        .accessibilityHidden(true)
                    VibeText(safetyKey)
                        .fontWeight(.medium)
                    Text("·")
                    candidateDetail
                        .lineLimit(1)
                }
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)

                if candidate.origin != .catalog {
                    Text(verbatim: candidate.path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(candidate.path)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 5)

            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: VibeFormat.bytes(candidate.bytes))
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([candidate.url])
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(VibeStrings.value("Show in Finder"))
                .help(VibeStrings.value("Show in Finder"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 61)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        }
    }
}

private struct MenuIconButton: View {
    let systemName: String
    let titleKey: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Circle())
        .overlay { Circle().stroke(Color.primary.opacity(0.10), lineWidth: 0.8) }
        .disabled(isDisabled)
        .help(VibeStrings.value(titleKey))
        .accessibilityLabel(VibeStrings.value(titleKey))
    }
}

private struct VibeGlassButtonModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private extension View {
    func vibeGlassButton(prominent: Bool = false) -> some View {
        modifier(VibeGlassButtonModifier(prominent: prominent))
    }
}
