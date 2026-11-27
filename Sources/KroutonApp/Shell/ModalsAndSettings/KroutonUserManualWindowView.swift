import DriveKit
import Foundation
import SwiftUI

// MARK: - User Manual Window (chapters from Resources/Manual, see KroutonUserManual.swift)

struct KroutonUserManualWindowView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var tutorialController = KroutonGuidedTutorialController.shared

    @State private var selectedChapter: KroutonManualChapter = .gettingStarted
    @State private var searchQuery: String = ""

    private var filteredChapters: [KroutonManualChapter] {
        let list = KroutonManualChapter.allCases.filter { $0.matches(query: searchQuery) }
        return list.isEmpty ? KroutonManualChapter.allCases : list
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search the manual", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.kroutonControlSurface)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(.horizontal, 10)
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CHAPTERS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)

                        ForEach(filteredChapters) { chapter in
                            let isSelected = (selectedChapter == chapter)
                            Button {
                                selectedChapter = chapter
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: chapter.sfSymbol)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isSelected ? store.activeOnAccentText : store.activeAccent)
                                        .frame(width: 18)
                                    Text(chapter.title)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                        .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(isSelected ? store.activeAccent : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.vertical, 6)

                        Text("GUIDED TOURS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        ForEach(KroutonGuidedTutorialID.allCases) { tour in
                            Button {
                                KroutonWindowManager.shared.startGuidedTutorialOnMainWorkspace(tour)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: tour.sfSymbol)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(store.uiSecondaryAccent)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(tour.title)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text("Highlights the controls on screen")
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "play.circle.fill")
                                        .foregroundStyle(store.uiSecondaryAccent)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.kroutonControlSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 270, max: 310)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: selectedChapter.sfSymbol)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(store.activeAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedChapter.title)
                                .font(.title2.bold())
                            Link("Read this chapter on krouton.app", destination: selectedChapter.onlineURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let tour = selectedChapter.associatedTutorial {
                            Button {
                                KroutonWindowManager.shared.startGuidedTutorialOnMainWorkspace(tour)
                            } label: {
                                Label("Start the Guided Tour", systemImage: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(store.activeAccent)
                        }
                    }

                    Divider()

                    ForEach(Array(selectedChapter.document.blocks.enumerated()), id: \.offset) { _, block in
                        manualBlock(block)
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.kroutonWindowSurface)
        }
        .frame(minWidth: 880, idealWidth: 980, minHeight: 540, idealHeight: 660)
        .preferredColorScheme(store.resolvedColorScheme)
        .tint(store.activeAccent)
    }
    // MARK: - Chapter Blocks

    @ViewBuilder
    private func manualBlock(_ block: KroutonManualDocument.Block) -> some View {
        switch block {
        case .heading(let text):
            Text(KroutonManualDocument.inline(text))
                .font(.title3.bold())
                .foregroundStyle(store.activeAccent)
                .padding(.top, 6)
        case .paragraph(let text):
            Text(KroutonManualDocument.inline(text))
                .font(.system(size: 13))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    manualListRow(marker: "•", text: item)
                }
            }
        case .steps(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    manualListRow(marker: "\(index + 1).", text: item)
                }
            }
        }
    }

    private func manualListRow(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(store.activeAccent)
                .frame(minWidth: 16, alignment: .trailing)
            Text(KroutonManualDocument.inline(text))
                .font(.system(size: 13))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
