import RescueKit
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import OpticalCore

// MARK: - 1:1 Millimeter-Calibrated Vector PDF Print Sheet & 300-DPI PNG Encoder

extension KroutonKrustiniModule {
    /// Exact PostScript/PDF points per physical millimeter (72 points/inch / 25.4 mm/inch)
    public static let pointsPerMillimeter: CGFloat = 72.0 / 25.4

    /// Encodes a CGImage into 300-DPI PNG data with embedded DPI metadata.
    public static func encodeCGImageToPNGData(_ cgImage: CGImage, dpi: Double = 300.0) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let dest = CGImageDestinationCreateWithData(
                  mutableData,
                  UTType.png.identifier as CFString,
                  1,
                  nil
              ) else {
            return nil
        }
        let props: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi
        ]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }

    /// Renders a 1:1 millimeter-calibrated US Letter (215.9 x 279.4 mm) PDF print sheet
    /// with outer rim clipping, inner hub hole punch-out, X/Y tray offsets, and crop crosshairs.
    public static func renderCalibratedPrintSheetPDFData(
        discCGImage: CGImage,
        presetName: String,
        outerDiameterMM: Double,
        innerDiameterMM: Double,
        offsetXMM: Double,
        offsetYMM: Double,
        discTitle: String,
        includeCalibrationMarks: Bool = true
    ) -> Data? {
        guard let pdfData = CFDataCreateMutable(nil, 0),
              let consumer = CGDataConsumer(data: pdfData) else { return nil }

        // US Letter in PostScript points (8.5" x 11" = 612 x 792 pt)
        var mediaBox = CGRect(x: 0.0, y: 0.0, width: 612.0, height: 792.0)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        ctx.beginPDFPage(nil)

        let ptPerMM = pointsPerMillimeter
        let outerDiamPt = CGFloat(max(70.0, min(120.0, outerDiameterMM))) * ptPerMM
        let innerDiamPt = CGFloat(max(15.0, min(54.0, innerDiameterMM))) * ptPerMM
        let offsetXPt = CGFloat(offsetXMM) * ptPerMM
        let offsetYPt = CGFloat(offsetYMM) * ptPerMM

        let outerRadiusPt = outerDiamPt * 0.5
        let innerRadiusPt = innerDiamPt * 0.5
        let centerX: CGFloat = (mediaBox.width * 0.5) + offsetXPt
        let centerY: CGFloat = (mediaBox.height * 0.54) - offsetYPt

        let discRect = CGRect(
            x: centerX - outerRadiusPt,
            y: centerY - outerRadiusPt,
            width: outerRadiusPt * 2.0,
            height: outerRadiusPt * 2.0
        )
        let hubRect = CGRect(
            x: centerX - innerRadiusPt,
            y: centerY - innerRadiusPt,
            width: innerRadiusPt * 2.0,
            height: innerRadiusPt * 2.0
        )

        // 1. Clip to annular disc ring (outer circle minus inner spindle hub hole using even-odd rule)
        ctx.saveGState()
        ctx.beginPath()
        ctx.addEllipse(in: discRect)
        ctx.addEllipse(in: hubRect)
        ctx.clip(using: .evenOdd)
        ctx.draw(discCGImage, in: discRect)
        ctx.restoreGState()

        // 2. Hairline perimeter, hub boundary & registration crosshairs for tray calibration
        if includeCalibrationMarks {
            ctx.saveGState()
            ctx.setStrokeColor(CGColor(gray: 0.25, alpha: 0.65))
            ctx.setLineWidth(0.5)
            ctx.strokeEllipse(in: discRect)
            ctx.strokeEllipse(in: hubRect)

            let markGap: CGFloat = 6.0
            let markLen: CGFloat = 14.0
            ctx.move(to: CGPoint(x: centerX - outerRadiusPt - markGap - markLen, y: centerY))
            ctx.addLine(to: CGPoint(x: centerX - outerRadiusPt - markGap, y: centerY))
            ctx.move(to: CGPoint(x: centerX + outerRadiusPt + markGap, y: centerY))
            ctx.addLine(to: CGPoint(x: centerX + outerRadiusPt + markGap + markLen, y: centerY))
            ctx.move(to: CGPoint(x: centerX, y: centerY - outerRadiusPt - markGap - markLen))
            ctx.addLine(to: CGPoint(x: centerX, y: centerY - outerRadiusPt - markGap))
            ctx.move(to: CGPoint(x: centerX, y: centerY + outerRadiusPt + markGap))
            ctx.addLine(to: CGPoint(x: centerX, y: centerY + outerRadiusPt + markGap + markLen))
            ctx.strokePath()

            let specLine = String(
                format: "KROUTON 1:1 CALIBRATED PRINT SHEET  •  %@  •  Outer %.0fmm / Hub %.0fmm  •  Offset X:%+.1fmm Y:%+.1fmm  •  %@",
                discTitle.isEmpty ? "UNTITLED_DISC" : discTitle,
                outerDiameterMM,
                innerDiameterMM,
                offsetXMM,
                offsetYMM,
                presetName
            )
            let attr: [NSAttributedString.Key: Any] = [
                .font: CTFontCreateWithName("Menlo-Regular" as CFString, 8.0, nil),
                .foregroundColor: CGColor(gray: 0.22, alpha: 0.90)
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: specLine, attributes: attr))
            ctx.textPosition = CGPoint(x: 42.0, y: 36.0)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        ctx.endPDFPage()
        ctx.closePDF()
        return pdfData as Data
    }

    /// Writes exported PNG and/or 1:1 PDF label files to ~/Downloads (or temporaryDirectory fallback).
    public static func writeDiscLabelExportFiles(
        discCGImage: CGImage,
        presetName: String,
        outerDiameterMM: Double,
        innerDiameterMM: Double,
        offsetXMM: Double,
        offsetYMM: Double,
        discTitle: String,
        exportPNG: Bool,
        exportPDF: Bool
    ) -> (pngURL: URL?, pdfURL: URL?) {
        let safeStem = discTitle
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let baseName = safeStem.isEmpty ? "Krouton_Disc_Label" : safeStem
        let outDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        var writtenPNG: URL? = nil
        var writtenPDF: URL? = nil

        if exportPNG, let pngData = encodeCGImageToPNGData(discCGImage, dpi: 300.0) {
            let url = outDir.appendingPathComponent("\(baseName)_300DPI_Label.png")
            if (try? pngData.write(to: url, options: Data.WritingOptions.atomic)) != nil {
                writtenPNG = url
            }
        }
        if exportPDF, let pdfData = renderCalibratedPrintSheetPDFData(
            discCGImage: discCGImage,
            presetName: presetName,
            outerDiameterMM: outerDiameterMM,
            innerDiameterMM: innerDiameterMM,
            offsetXMM: offsetXMM,
            offsetYMM: offsetYMM,
            discTitle: baseName,
            includeCalibrationMarks: true
        ) {
            let url = outDir.appendingPathComponent("\(baseName)_1to1_PrintSheet.pdf")
            if (try? pdfData.write(to: url, options: Data.WritingOptions.atomic)) != nil {
                writtenPDF = url
            }
        }
        return (writtenPNG, writtenPDF)
    }
}
