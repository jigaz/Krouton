import Foundation

// MARK: - Panorama planet (polar coordinates)

/// How a panorama is wrapped into the disc: each pixel of the disc is traced back to a point of
/// the photo by its angle (across the photo) and its distance from the centre (down the photo).
public struct KroutonPlanetSettings: Codable, Hashable, Sendable {
    public enum Projection: String, Codable, CaseIterable, Identifiable, Sendable {
        /// Distance from the centre is linear in the photo's height (Photoshop's Polar Coordinates).
        case polar = "Polar Coordinates"
        /// Stereographic: the ground curves into a small globe and the sky opens out, as a
        /// little-planet photo from a 360° camera looks.
        case stereographic = "Little Planet"
        public var id: String { rawValue }
    }

    public enum Orientation: String, Codable, CaseIterable, Identifiable, Sendable {
        case planet = "Planet (ground in the middle)"
        case tunnel = "Tunnel (sky in the middle)"
        public var id: String { rawValue }
    }

    public enum Seam: String, Codable, CaseIterable, Identifiable, Sendable {
        /// The photo's ends meet: right for full 360° panoramas.
        case wrap = "Wrap (360° panorama)"
        /// The photo's ends crossfade over `seamBlend` of its width.
        case blend = "Blend the ends"
        /// The photo and its mirror image go round once each, so nothing has to meet.
        case mirror = "Mirror (no seam)"
        public var id: String { rawValue }
    }

    public var projection: Projection = .stereographic
    public var orientation: Orientation = .planet
    public var seam: Seam = .wrap
    /// Fraction of the photo's width crossfaded at the seam (`.blend`).
    public var seamBlend: Double = 0.08
    /// Turns the planet, in degrees.
    public var rotationDegrees: Double = 0
    /// Where the horizon lands: 0 at the hub (or centre), 1 at the rim.
    public var horizonRadius: Double = 0.42
    /// Where the horizon is in the photo: 0 top, 1 bottom (0.5 for a level 360° panorama).
    public var horizonInPhoto: Double = 0.5
    /// Polar only: above 1 squeezes the ground towards the centre, below 1 spreads it out.
    public var groundCurve: Double = 1.0
    /// Fractions of the photo cut from the top (sky) and bottom (ground) before wrapping.
    public var cropTop: Double = 0
    public var cropBottom: Double = 0
    /// Degrees of swirl added between the centre and the rim.
    public var twistDegrees: Double = 0
    /// Starts the photo at the hub's edge so the stretched centre falls in the hole.
    public var startAtHub: Bool = true
    public var flipHorizontal: Bool = false
    /// Fractions of the radius that fade to `fadeColor` at the rim and at the centre.
    public var rimFade: Double = 0
    public var centerFade: Double = 0
    public var fadeColor = KroutonRGBAColor(r: 1, g: 1, b: 1)
    /// Moves the planet's centre, as a fraction of the disc radius.
    public var centerOffsetX: Double = 0
    public var centerOffsetY: Double = 0
    /// Samples per pixel along each axis (1–3); 2 removes the jagged edges at the centre.
    public var antialias: Int = 2

    public init() {}
}

// MARK: - Printing

/// How the label is printed: straight onto a printable disc in an inkjet tray, or onto a sheet.
public struct KroutonLabelPrintSettings: Codable, Hashable, Sendable {
    public enum Target: String, Codable, CaseIterable, Identifiable, Sendable {
        /// A PNG at 1:1 for the printer's own disc software (Epson Print CD, Canon IJ), plus
        /// the PDF tray sheet.
        case discTray = "Printable disc (inkjet tray)"
        /// A PDF on US Letter at 1:1, to cut out or check alignment on plain paper.
        case letterSheet = "US Letter sheet"
        public var id: String { rawValue }
    }

    public var target: Target = .discTray
    public var dotsPerInch: Int = 300
    /// Ink carried past the rim and into the hub, so a slightly off-centre print leaves no white
    /// edge. Printable discs usually take about 1 mm outside and 0.5 mm inside.
    public var bleedOuterMM: Double = 1.0
    public var bleedInnerMM: Double = 0.5
    /// 1 prints the colours as they are; lower lightens every colour towards the white disc,
    /// for glossy surfaces that pool ink.
    public var inkDensity: Double = 1.0
    /// Lifts the darkest tones so large black areas don't flood (0 to 0.3).
    public var blackLift: Double = 0
    /// Draws the rim, hub and crosshair marks on the PDF sheet.
    public var cropMarks: Bool = true

    public init() {}
}
