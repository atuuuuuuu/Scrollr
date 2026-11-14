import AppKit
import SwiftUI

/// Scrollr's identity: a mouse outline holding a pair of opposite arrows, on a coral-to-raspberry tile.
enum Brand {
    static let coral = Color(red: 1.00, green: 0.48, blue: 0.27)      // #FF7A45
    static let raspberry = Color(red: 0.91, green: 0.21, blue: 0.42)  // #E8366B
    static let gradient = LinearGradient(colors: [coral, raspberry], startPoint: .top, endPoint: .bottom)

    /// Template images for the menu bar, drawn from the same glyph as the app icon.
    @MainActor static let menuIcon = template(active: true)
    @MainActor static let menuIconPaused = template(active: false)

    @MainActor private static func template(active: Bool) -> NSImage {
        let renderer = ImageRenderer(content: Glyph(weight: 1.5).frame(width: 18, height: 18).opacity(active ? 1 : 0.45))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}

/// The mouse-and-arrows mark, drawn in unit space so it stays crisp at 16 px and at 1024 px.
struct Glyph: View {
    var weight: CGFloat = 1

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            let line = StrokeStyle(lineWidth: 0.06 * s * weight, lineCap: .round, lineJoin: .round)

            let body = Path(roundedRect: CGRect(origin: p(0.29, 0.12), size: CGSize(width: 0.42 * s, height: 0.76 * s)),
                            cornerRadius: 0.21 * s, style: .continuous)
            ctx.stroke(body, with: .foreground, style: line)

            var arrows = Path()
            // Up arrow on the left, down arrow on the right: "the wheel goes the other way".
            arrows.move(to: p(0.42, 0.66)); arrows.addLine(to: p(0.42, 0.33))
            arrows.move(to: p(0.355, 0.40)); arrows.addLine(to: p(0.42, 0.33)); arrows.addLine(to: p(0.485, 0.40))
            arrows.move(to: p(0.58, 0.34)); arrows.addLine(to: p(0.58, 0.67))
            arrows.move(to: p(0.515, 0.60)); arrows.addLine(to: p(0.58, 0.67)); arrows.addLine(to: p(0.645, 0.60))
            ctx.stroke(arrows, with: .foreground, style: StrokeStyle(lineWidth: 0.05 * s * weight, lineCap: .round, lineJoin: .round))
        }
    }
}

/// The app icon: the glyph on the brand tile, laid out on Apple's 1024 pt icon grid (824 pt tile).
struct AppIconView: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.1855, style: .continuous)
                    .fill(Brand.gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.1855, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                    )
                    .shadow(color: .black.opacity(0.28), radius: s * 0.012, y: s * 0.01)
                Glyph()
                    .foregroundStyle(.white)
                    .frame(width: s * 0.56, height: s * 0.56)
                    .shadow(color: Brand.raspberry.opacity(0.5), radius: s * 0.02, y: s * 0.01)
            }
            .frame(width: s * 0.805, height: s * 0.805)
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// `Scrollr --render-art <dir>` writes the icon set and README art from the views above.
enum ArtRenderer {
    @MainActor static func run(_ dir: String) {
        let out = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let iconset = out.appendingPathComponent("AppIcon.iconset")
        try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for pt in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
                write(AppIconView().frame(width: CGFloat(pt), height: CGFloat(pt)), scale: CGFloat(scale), to: iconset.appendingPathComponent(name))
            }
        }
        write(AppIconView().frame(width: 512, height: 512), scale: 1, to: out.appendingPathComponent("logo.png"))
        write(Banner(width: 1600, height: 560), scale: 1, to: out.appendingPathComponent("banner.png"))
        write(Banner(width: 1280, height: 640), scale: 1, to: out.appendingPathComponent("social-preview.png"))
    }

    @MainActor private static func write(_ view: some View, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            fatalError("could not render \(url.lastPathComponent)")
        }
        try! png.write(to: url)
    }
}

private struct Banner: View {
    let width: CGFloat, height: CGFloat

    var body: some View {
        HStack(spacing: height * 0.08) {
            AppIconView().frame(width: height * 0.62, height: height * 0.62)
            VStack(alignment: .leading, spacing: height * 0.03) {
                Text("Scrollr")
                    .font(.system(size: height * 0.21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.1))
                Text("Reverse your mouse.\nKeep your trackpad.")
                    .font(.system(size: height * 0.075, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.35))
                    .lineSpacing(height * 0.01)
                Text("Free menu bar app for macOS")
                    .font(.system(size: height * 0.045, weight: .semibold, design: .rounded))
                    .foregroundStyle(Brand.raspberry)
                    .padding(.top, height * 0.02)
            }
        }
        .frame(width: width, height: height)
        .background(
            LinearGradient(colors: [Color(red: 1, green: 0.97, blue: 0.95), Color(red: 1, green: 0.92, blue: 0.91)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .environment(\.colorScheme, .light)
    }
}
