import OpticalCore
import SwiftUI

// MARK: - Phase 4: Reusable Mastering Hardware Deck Card & Drop-Zone Primitives

struct KroutonMasteringDeckCard<Content: View>: View {
    var store: KroutonStateStore
    let paddingAmount: CGFloat
    let cornerRadius: CGFloat
    let content: Content

    init(
        store: KroutonStateStore,
        paddingAmount: CGFloat = 10,
        cornerRadius: CGFloat = 9,
        @ViewBuilder content: () -> Content
    ) {
        self.store = store
        self.paddingAmount = paddingAmount
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(paddingAmount)
            .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(store.activeAccent.opacity(0.30), lineWidth: 1)
            )
    }
}

struct KroutonEmptyDropZoneView: View {
    var store: KroutonStateStore
    let isDropTargeted: Bool
    let sfSymbol: String
    let symbolSize: CGFloat
    let headline: String
    let subtitle: String
    let actionTitle: String?
    let actionSymbol: String
    let onAction: (() -> Void)?

    init(
        store: KroutonStateStore,
        isDropTargeted: Bool = false,
        sfSymbol: String,
        symbolSize: CGFloat = 36,
        headline: String,
        subtitle: String,
        actionTitle: String? = nil,
        actionSymbol: String = "folder.badge.plus",
        onAction: (() -> Void)? = nil
    ) {
        self.store = store
        self.isDropTargeted = isDropTargeted
        self.sfSymbol = sfSymbol
        self.symbolSize = symbolSize
        self.headline = headline
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.actionSymbol = actionSymbol
        self.onAction = onAction
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: sfSymbol)
                .font(.system(size: symbolSize))
                .foregroundStyle(store.uiSecondaryAccent.opacity(0.85))
            Text(KroutonL10n.tr(headline))
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text(KroutonL10n.tr(subtitle))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 6) {
                        Image(systemName: actionSymbol)
                        Text(KroutonL10n.tr(actionTitle))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(store.activeAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
