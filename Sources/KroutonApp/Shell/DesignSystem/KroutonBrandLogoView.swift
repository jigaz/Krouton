import SwiftUI

struct KroutonBrandLogoView: View {
    var size: CGFloat = 26
    var tintColor: Color? = nil

    init(size: CGFloat = 26, tintColor: Color? = nil) {
        self.size = size
        self.tintColor = tintColor
    }

    var body: some View {
        ZStack {
            // Squircle Base
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(tintColor != nil ? Color.clear : Color(white: 0.89))

            // Optical Disc Ring
            Circle()
                .stroke(tintColor ?? Color(red: 0.93, green: 0.47, blue: 0.24), lineWidth: size * 0.05)
                .frame(width: size * 0.75, height: size * 0.75)

            // Isometric Golden Crouton Cube (Top, Left, Right faces)
            if tintColor == nil {
                Path { p in
                    p.move(to: CGPoint(x: size * 0.50, y: size * 0.27))
                    p.addLine(to: CGPoint(x: size * 0.70, y: size * 0.39))
                    p.addLine(to: CGPoint(x: size * 0.50, y: size * 0.51))
                    p.addLine(to: CGPoint(x: size * 0.30, y: size * 0.39))
                    p.closeSubpath()
                }.fill(Color(red: 0.99, green: 0.92, blue: 0.84))

                Path { p in
                    p.move(to: CGPoint(x: size * 0.30, y: size * 0.39))
                    p.addLine(to: CGPoint(x: size * 0.50, y: size * 0.51))
                    p.addLine(to: CGPoint(x: size * 0.50, y: size * 0.74))
                    p.addLine(to: CGPoint(x: size * 0.30, y: size * 0.63))
                    p.closeSubpath()
                }.fill(Color(red: 0.69, green: 0.44, blue: 0.30))

                Path { p in
                    p.move(to: CGPoint(x: size * 0.50, y: size * 0.51))
                    p.addLine(to: CGPoint(x: size * 0.70, y: size * 0.39))
                    p.addLine(to: CGPoint(x: size * 0.70, y: size * 0.63))
                    p.addLine(to: CGPoint(x: size * 0.50, y: size * 0.74))
                    p.closeSubpath()
                }.fill(Color(red: 0.84, green: 0.61, blue: 0.35))
            }

            // Hexagon Outline
            Path { p in
                p.move(to: CGPoint(x: size * 0.50, y: size * 0.27))
                p.addLine(to: CGPoint(x: size * 0.70, y: size * 0.39))
                p.addLine(to: CGPoint(x: size * 0.70, y: size * 0.63))
                p.addLine(to: CGPoint(x: size * 0.50, y: size * 0.74))
                p.addLine(to: CGPoint(x: size * 0.30, y: size * 0.63))
                p.addLine(to: CGPoint(x: size * 0.30, y: size * 0.39))
                p.closeSubpath()
            }.stroke(tintColor ?? Color(red: 0.84, green: 0.61, blue: 0.35), lineWidth: size * 0.025)
        }
        .frame(width: size, height: size)
    }
}
