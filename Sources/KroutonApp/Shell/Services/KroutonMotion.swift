import SwiftUI

// MARK: - Reduce Motion

/// Every animation in Krouton goes through `kroutonMotion`, so Reduce Motion (System Settings ›
/// Accessibility › Display) turns them all off: the change still happens, just without
/// movement. The setting is read from SwiftUI's environment by `KroutonReduceMotionReader`,
/// which every window carries.
@MainActor
enum KroutonMotionPreference {
    static var reduceMotion = false
}

@MainActor
func kroutonMotion(_ animation: Animation) -> Animation? {
    KroutonMotionPreference.reduceMotion ? nil : animation
}

struct KroutonReduceMotionReader: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onAppear { KroutonMotionPreference.reduceMotion = reduceMotion }
            .onChange(of: reduceMotion) { _, value in KroutonMotionPreference.reduceMotion = value }
    }
}
