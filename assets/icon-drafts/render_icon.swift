#!/usr/bin/env swift
import AppKit
import Foundation

// Ein-Zweck-Skript: rendert ein SVG in alle macOS-AppIcon-Größen
// und schreibt sie in AppIcon.appiconset mit passendem Contents.json.

guard CommandLine.arguments.count == 3 else {
    print("Usage: render_icon.swift <svg-path> <appiconset-path>")
    exit(1)
}

let svgURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconSet = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOf: svgURL) else {
    print("Konnte SVG nicht laden: \(svgURL.path)")
    exit(2)
}

// macOS AppIcon: scale-Pairs (displaySize, scale) → pixelSize = displaySize*scale.
// Wir brauchen zusätzlich die Dateien-PixelSizes.
struct IconSpec {
    let pixelSize: Int
    let displaySize: String  // z.B. "16x16"
    let scale: String        // "1x" oder "2x"
}

let specs: [IconSpec] = [
    IconSpec(pixelSize: 16,   displaySize: "16x16",    scale: "1x"),
    IconSpec(pixelSize: 32,   displaySize: "16x16",    scale: "2x"),
    IconSpec(pixelSize: 32,   displaySize: "32x32",    scale: "1x"),
    IconSpec(pixelSize: 64,   displaySize: "32x32",    scale: "2x"),
    IconSpec(pixelSize: 128,  displaySize: "128x128",  scale: "1x"),
    IconSpec(pixelSize: 256,  displaySize: "128x128",  scale: "2x"),
    IconSpec(pixelSize: 256,  displaySize: "256x256",  scale: "1x"),
    IconSpec(pixelSize: 512,  displaySize: "256x256",  scale: "2x"),
    IconSpec(pixelSize: 512,  displaySize: "512x512",  scale: "1x"),
    IconSpec(pixelSize: 1024, displaySize: "512x512",  scale: "2x"),
]

// Eindeutige Pixel-Größen (Dateien), einmalig rendern + wiederverwenden.
let uniquePixelSizes = Set(specs.map { $0.pixelSize })

func renderPNG(from image: NSImage, pixelSize: Int) -> Data? {
    let size = CGSize(width: pixelSize, height: pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else { return nil }
    rep.size = size

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    image.draw(
        in: NSRect(origin: .zero, size: size),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1.0
    )
    return rep.representation(using: .png, properties: [:])
}

try? FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)

var written: [Int: String] = [:]  // pixelSize → filename
for pixelSize in uniquePixelSizes.sorted() {
    let filename = "icon_\(pixelSize).png"
    let outURL = iconSet.appendingPathComponent(filename)
    guard let data = renderPNG(from: sourceImage, pixelSize: pixelSize) else {
        print("Render-Fehler bei \(pixelSize)px")
        exit(3)
    }
    try data.write(to: outURL)
    written[pixelSize] = filename
    print("✓ \(filename) (\(data.count) bytes)")
}

// Contents.json erzeugen
struct Entry: Encodable {
    let size: String
    let idiom: String
    let filename: String
    let scale: String
}
struct Info: Encodable {
    let version: Int
    let author: String
}
struct Manifest: Encodable {
    let images: [Entry]
    let info: Info
}

let images = specs.map { spec in
    Entry(
        size: spec.displaySize,
        idiom: "mac",
        filename: written[spec.pixelSize]!,
        scale: spec.scale
    )
}

let manifest = Manifest(
    images: images,
    info: Info(version: 1, author: "xcode")
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let jsonData = try encoder.encode(manifest)
let contentsURL = iconSet.appendingPathComponent("Contents.json")
try jsonData.write(to: contentsURL)
print("✓ Contents.json geschrieben")
print("Fertig. \(images.count) Einträge, \(written.count) PNG-Dateien.")
