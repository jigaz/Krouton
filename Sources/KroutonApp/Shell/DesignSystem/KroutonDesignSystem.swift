import Foundation
import OpticalCore
import SwiftUI

enum KroutonDesign {
    enum Radius {
        static let pill: CGFloat = 999
        static let badge: CGFloat = 6
        static let card: CGFloat = 10
        static let hero: CGFloat = 14
        static let panel: CGFloat = 12
    }

    enum Typography {
        static let microMono = Font.system(size: 9, weight: .bold, design: .monospaced)
        static let badgeMono = Font.system(size: 9.5, weight: .semibold, design: .monospaced)
        static let telemetryMono = Font.system(size: 10.5, weight: .bold, design: .monospaced)
        static let sectionHeader = Font.system(size: 9.5, weight: .bold, design: .rounded)
        static let cardTitle = Font.system(size: 12.5, weight: .bold)
    }
}

// MARK: - Window Layout

extension EnvironmentValues {
    /// The main window's column sizes, set once by `KroutonMainWorkspaceView` from the column
    /// widths. A view reads it instead of taking a narrow flag through its initializer.
    @Entry var kroutonLayout: KroutonWindowLayout = .regular
}
