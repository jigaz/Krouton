import DriveKit
import Foundation
import OpticalCore
import SwiftUI

// MARK: - Live Graphical Spotlight & Coach-Mark Overlay View

struct KroutonGuidedTutorialOverlayView: View {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var tutorialController = KroutonGuidedTutorialController.shared
    let leftWidth: CGFloat
    let centerWidth: CGFloat
    let rightWidth: CGFloat
    let totalSize: CGSize

    private func highlightFrame(for zone: KroutonTutorialTargetZone) -> CGRect {
        let topBarH: CGFloat = 52
        let bodyH = max(200, totalSize.height - topBarH)
        let centerX = leftWidth + 11
        let rightX = leftWidth + centerWidth + 22
        switch zone {
        case .leftFormatSidebar:
            return CGRect(x: 6, y: topBarH + 6, width: max(160, leftWidth - 10), height: bodyH - 12)
        case .centerMasteringDeck:
            return CGRect(x: centerX + 12, y: topBarH + 12, width: max(280, centerWidth - 24), height: min(155, bodyH * 0.28))
        case .centerWorkspaceBody:
            return CGRect(x: centerX + 12, y: topBarH + 110, width: max(280, centerWidth - 24), height: max(180, bodyH - 190))
        case .centerCapacityBar:
            return CGRect(x: centerX + 12, y: max(topBarH + 120, totalSize.height - 96), width: max(280, centerWidth - 24), height: 78)
        case .rightBurnerPool:
            return CGRect(x: rightX + 4, y: topBarH + 6, width: max(240, rightWidth - 10), height: bodyH - 12)
        }
    }

    private func cardPosition(for highlight: CGRect, zone: KroutonTutorialTargetZone) -> CGPoint {
        let cardW: CGFloat = 380
        let cardH: CGFloat = 230
        let clampedY = min(max(cardH * 0.5 + 64, highlight.midY), totalSize.height - cardH * 0.5 - 20)
        switch zone {
        case .leftFormatSidebar:
            return CGPoint(x: min(totalSize.width - cardW * 0.5 - 20, highlight.maxX + cardW * 0.5 + 18), y: clampedY)
        case .rightBurnerPool:
            return CGPoint(x: max(cardW * 0.5 + 20, highlight.minX - cardW * 0.5 - 18), y: clampedY)
        case .centerMasteringDeck:
            return CGPoint(x: highlight.midX, y: min(totalSize.height - cardH * 0.5 - 20, highlight.maxY + cardH * 0.5 + 16))
        case .centerWorkspaceBody:
            return CGPoint(x: highlight.midX, y: max(cardH * 0.5 + 62, highlight.minY + 95))
        case .centerCapacityBar:
            return CGPoint(x: highlight.midX, y: max(cardH * 0.5 + 62, highlight.minY - cardH * 0.5 - 16))
        }
    }

    var body: some View {
        if let tut = tutorialController.activeTutorial,
           let step = tutorialController.currentStep {
            let rect = highlightFrame(for: step.zone)
            let stepsCount = tutorialController.activeSteps.count
            let cardPos = cardPosition(for: rect, zone: step.zone)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [store.activeAccent, store.uiSecondaryAccent, store.activeAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3.0, dash: [8, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(store.activeAccent.opacity(0.05))
                    )
                    .shadow(color: store.activeAccent.opacity(0.55), radius: 12)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)

                HStack(spacing: 5) {
                    Image(systemName: tut.sfSymbol)
                        .font(.system(size: 10, weight: .bold))
                    Text("STEP \(step.id + 1) OF \(stepsCount)")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(store.activeAccent)
                .foregroundStyle(store.activeOnAccentText)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.45), radius: 4)
                .position(x: min(totalSize.width - 70, max(70, rect.minX + 64)), y: max(62, rect.minY))
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: tut.sfSymbol)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(store.activeAccent)
                        Text(tut.title.uppercased())
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            withAnimation(kroutonMotion(.easeInOut(duration: 0.18))) {
                                tutorialController.stop()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Close interactive guided tutorial")
                    }

                    Text(step.headline)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(step.body)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Label(step.shortcutHint, systemImage: "command")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())

                        Spacer()

                        if let actionTitle = step.actionButtonTitle {
                            Button {
                                tutorialController.performLiveStepAction(store: store, driveManager: driveManager)
                            } label: {
                                Label(actionTitle, systemImage: "sparkles")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(store.uiSecondaryAccent)
                            .controlSize(.small)
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            ForEach(0..<stepsCount, id: \.self) { idx in
                                Capsule()
                                    .fill(idx == step.id ? store.activeAccent : Color.secondary.opacity(0.30))
                                    .frame(width: idx == step.id ? 18 : 7, height: 6)
                            }
                        }

                        Spacer()

                        if step.id > 0 {
                            Button("Back") {
                                withAnimation(kroutonMotion(.spring(response: 0.28, dampingFraction: 0.80))) {
                                    tutorialController.previousStep(store: store, driveManager: driveManager)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Button(step.id + 1 < stepsCount ? "Next Step" : "Finish Tour") {
                            withAnimation(kroutonMotion(.spring(response: 0.28, dampingFraction: 0.80))) {
                                tutorialController.nextStep(store: store, driveManager: driveManager)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(store.activeAccent)
                        .controlSize(.small)
                    }
                }
                .padding(14)
                .frame(width: 380)
                .background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(store.activeAccent.opacity(0.75), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.42), radius: 16, y: 6)
                .position(cardPos)
            }
            .frame(width: totalSize.width, height: totalSize.height)
        }
    }
}
