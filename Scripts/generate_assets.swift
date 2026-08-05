#!/usr/bin/env swift
// Renders the DeepWeather app icon (1024px) and launch logo (256px, transparent)
// using an SF Symbol composited over a sky gradient. Run: swift Scripts/generate_assets.swift
import AppKit
import Foundation

let topColor = NSColor(calibratedRed: 0.35, green: 0.62, blue: 0.95, alpha: 1.0)   // #59A0F2
let bottomColor = NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.83, alpha: 1.0) // #2E6BD4

func makeImage(size: CGFloat, background: Bool, symbolScale: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    if background {
        let colors = [topColor.cgColor, bottomColor.cgColor] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.maxY),
                end: CGPoint(x: rect.midX, y: rect.minY),
                options: []
            )
        }
    }

    let config = NSImage.SymbolConfiguration(pointSize: size * symbolScale, weight: .medium)
        .applying(.init(paletteColors: [NSColor.white]))
    if let symbol = NSImage(systemSymbolName: "cloud.sun.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let s = size * symbolScale
        let origin = CGPoint(x: (size - s) / 2, y: (size - s) / 2)
        symbol.draw(in: NSRect(x: origin.x, y: origin.y, width: s, height: s))
    }
    return image
}

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG for \(path)")
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let icon = makeImage(size: 1024, background: true, symbolScale: 0.5)
writePNG(icon, to: outputDir + "/AppIcon.png")
let logo = makeImage(size: 256, background: false, symbolScale: 0.9)
writePNG(logo, to: outputDir + "/LaunchLogo.png")
print("Generated AppIcon.png and LaunchLogo.png in \(outputDir)")
