import SwiftUI
import OpticalDough

// MARK: - Phase 4: Reusable Mastering Hardware Deck Card & Drop-Zone Primitives

public struct KroutonMasteringDeckCard<Content: View>: View {
    @ObservedObject var store: KroutonStateStore
    let cornerRadius: CGFloat
    let content: Content

    public init(
        store: KroutonStateStore,
        cornerRadius: CGFloat = 9,
        @ViewBuilder content: () -> Content
    ) {
        self.store = store
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(store.activeAccent.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(store.activeAccent.opacity(0.30), lineWidth: 1)
                    )
            )
    }
}

public struct KroutonEmptyDropZoneView: View {
    @ObservedObject var store: KroutonStateStore
    let isDropTargeted: Bool
    let sfSymbol: String
    let headline: String
    let subtitle: String

    public init(
        store: KroutonStateStore,
        isDropTargeted: Bool,
        sfSymbol: String,
        headline: String,
        subtitle: String
    ) {
        self.store = store
        self.isDropTargeted = isDropTargeted
        self.sfSymbol = sfSymbol
        self.headline = headline
        self.subtitle = subtitle
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(isDropTargeted ? 0.34 : 0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isDropTargeted ? store.activeAccent : Color.primary.opacity(0.14),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: isDropTargeted ? [6, 4] : [])
                        )
                )

            VStack(spacing: 12) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 36))
                    .foregroundStyle(store.activeAccent)
                Text(KroutonL10n.tr(headline))
                    .font(.system(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(KroutonL10n.tr(subtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
