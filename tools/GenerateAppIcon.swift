#!/usr/bin/env swift

// Renders Bronzla's app icon at 1024pt in light, dark and tinted variants.
//
// Kept as source rather than committed binaries so the mark can be adjusted without a design
// tool, and so anyone can see exactly what the icon is made of.
//
// Usage: swift Tools/GenerateAppIcon.swift Bronzla/Resources/Assets.xcassets/AppIcon.appiconset

import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024

enum Variant: String, CaseIterable {
    case light = "AppIcon-light"
    case dark = "AppIcon-dark"
    case tinted = "AppIcon-tinted"
}

/// Warm dusk gradient. Sunset rather than midday: the app is about respecting the sun, and a
/// blazing yellow disc would promise the opposite of what it does.
func backgroundColours(for variant: Variant) -> [CGColor] {
    switch variant {
    case .light:
        [
            CGColor(red: 0.99, green: 0.71, blue: 0.33, alpha: 1),
            CGColor(red: 0.95, green: 0.44, blue: 0.29, alpha: 1),
            CGColor(red: 0.78, green: 0.26, blue: 0.38, alpha: 1),
        ]
    case .dark:
        [
            CGColor(red: 0.35, green: 0.16, blue: 0.20, alpha: 1),
            CGColor(red: 0.22, green: 0.10, blue: 0.16, alpha: 1),
            CGColor(red: 0.11, green: 0.06, blue: 0.11, alpha: 1),
        ]
    case .tinted:
        // The system applies its own tint, so this variant supplies luminance only.
        [
            CGColor(gray: 0.10, alpha: 1),
            CGColor(gray: 0.10, alpha: 1),
        ]
    }
}

func markColour(for variant: Variant) -> CGColor {
    switch variant {
    case .light: CGColor(red: 1, green: 0.98, blue: 0.94, alpha: 1)
    case .dark: CGColor(red: 1, green: 0.85, blue: 0.62, alpha: 1)
    case .tinted: CGColor(gray: 1, alpha: 1)
    }
}

func render(_ variant: Variant) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let colours = backgroundColours(for: variant)
    let locations: [CGFloat] = colours.count == 3 ? [0, 0.55, 1] : [0, 1]

    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colours as CFArray,
        locations: locations
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }

    let mark = markColour(for: variant)

    // The sun: a disc sitting above a horizon, cropped by it rather than floating free. The
    // crop is what makes it read as a setting sun instead of a generic circle.
    let horizonY = size * 0.38
    let sunRadius = size * 0.21
    let sunCentre = CGPoint(x: size / 2, y: horizonY + sunRadius * 0.62)

    context.saveGState()
    context.clip(to: CGRect(x: 0, y: horizonY, width: size, height: size - horizonY))
    context.setFillColor(mark)
    context.fillEllipse(in: CGRect(
        x: sunCentre.x - sunRadius,
        y: sunCentre.y - sunRadius,
        width: sunRadius * 2,
        height: sunRadius * 2
    ))
    context.restoreGState()

    // Three horizon lines of decreasing width, suggesting light on water without drawing water.
    let lineHeight = size * 0.028
    let widths: [CGFloat] = [0.52, 0.34, 0.19]
    let gaps: [CGFloat] = [0, 0.075, 0.145]
    let alphas: [CGFloat] = [1.0, 0.72, 0.44]

    for (index, width) in widths.enumerated() {
        context.setFillColor(mark.copy(alpha: alphas[index]) ?? mark)
        let barWidth = size * width
        let rect = CGRect(
            x: (size - barWidth) / 2,
            y: horizonY - lineHeight / 2 - size * gaps[index],
            width: barWidth,
            height: lineHeight
        )
        context.addPath(CGPath(roundedRect: rect, cornerWidth: lineHeight / 2, cornerHeight: lineHeight / 2, transform: nil))
        context.fillPath()
    }

    return context.makeImage()
}

// MARK: - Write

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("error: output directory required")
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1])
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for variant in Variant.allCases {
    guard let image = render(variant) else {
        print("error: could not render \(variant.rawValue)")
        exit(1)
    }

    let url = outputDirectory.appending(path: "\(variant.rawValue).png")
    let bitmap = NSBitmapImageRep(cgImage: image)
    bitmap.size = NSSize(width: size, height: size)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        print("error: could not encode \(variant.rawValue)")
        exit(1)
    }

    try data.write(to: url)
    print("wrote \(url.lastPathComponent)")
}
