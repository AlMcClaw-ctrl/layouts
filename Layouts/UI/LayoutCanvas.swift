import SwiftUI

/// To-scale preview of a display; window tiles can be dragged and resized.
struct LayoutCanvas: View {
    /// Fixed reference space for all drag gestures – not the tile itself, which moves.
    static let space = "layoutCanvas"

    @Binding var slots: [Slot]
    @Binding var selection: Slot.ID?
    let screen: NSScreen
    var useGrid = false

    var body: some View {
        let visible = Screens.visibleAX(screen)
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(GridLines(columns: 4, rows: 2))
                    .onTapGesture { selection = nil }

                ForEach($slots) { $slot in
                    if Screens.resolve(slot.screen) == screen {
                        SlotTile(slot: $slot, canvas: geo.size, isSelected: selection == slot.id,
                                 neighbours: slots.filter { $0.id != slot.id && $0.screen == slot.screen }.map(\.frame),
                                 useGrid: useGrid) {
                            selection = slot.id
                        }
                        .zIndex(selection == slot.id ? 1 : 0)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: LayoutCanvas.space)
        }
        .aspectRatio(visible.width / visible.height, contentMode: .fit)
    }
}

private struct GridLines: View {
    let columns: Int, rows: Int

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            for c in 1..<columns {
                let x = size.width * Double(c) / Double(columns)
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for r in 1..<rows {
                let y = size.height * Double(r) / Double(rows)
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.secondary.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .allowsHitTesting(false)
    }
}

private struct SlotTile: View {
    @Binding var slot: Slot
    let canvas: CGSize
    let isSelected: Bool
    /// Frames of the other tiles – their edges are magnetic.
    let neighbours: [UnitRect]
    /// 1/24 grid instead of free dragging.
    let useGrid: Bool
    let select: () -> Void

    private enum Drag { case move, resize }

    /// 1/24 grid – so ½, ⅓, ¼, ⅙ … land exactly.
    private static let grid = 24.0
    /// Snap distance in points on the preview.
    private static let magnet = 6.0
    /// Raw frame while dragging.
    @State private var live: UnitRect?
    @State private var drag = Drag.move

    var body: some View {
        let f = live ?? slot.frame
        let color = AppCatalog.color(slot.bundleID)

        ZStack(alignment: .topLeading) {
            // Target position after release
            if let live {
                let target = snapped(live)
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.08)))
                    .frame(width: target.w * canvas.width, height: target.h * canvas.height)
                    .offset(x: target.x * canvas.width, y: target.y * canvas.height)
                    .allowsHitTesting(false)
            }

            tile(f, color: color)
                .frame(width: max(f.w * canvas.width, 1), height: max(f.h * canvas.height, 1))
                .offset(x: f.x * canvas.width, y: f.y * canvas.height)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
    }

    private func tile(_ f: UnitRect, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(isSelected ? 0.55 : 0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : color, lineWidth: isSelected ? 3 : 1.5)
            )
            .overlay {
                VStack(spacing: 4) {
                    if let icon = AppCatalog.icon(slot.bundleID) {
                        Image(nsImage: icon).resizable().frame(width: 36, height: 36)
                    }
                    Text(slot.appName ?? AppCatalog.name(slot.bundleID)).font(.headline)
                    Text(caption(snapped(f))).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                .padding(6)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.bold())
                    .padding(6)
                    .background(.thinMaterial, in: Circle())
                    .padding(4)
                    .contentShape(Rectangle())
                    .highPriorityGesture(resize)
                    .help("Resize")
            }
            .contentShape(Rectangle())
            .gesture(move)
            .onTapGesture(perform: select)
            .shadow(color: .black.opacity(live == nil ? 0 : 0.25), radius: 8, y: 3)
    }

    private var move: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(LayoutCanvas.space))
            .onChanged { g in
                if live == nil { select() }
                drag = .move
                var u = slot.frame
                u.x = clamp(u.x + g.translation.width / canvas.width, 0, 1 - u.w)
                u.y = clamp(u.y + g.translation.height / canvas.height, 0, 1 - u.h)
                live = u
            }
            .onEnded { _ in commit() }
    }

    private var resize: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(LayoutCanvas.space))
            .onChanged { g in
                if live == nil { select() }
                drag = .resize
                var u = slot.frame
                let minSize = 1 / Self.grid
                u.w = clamp(u.w + g.translation.width / canvas.width, minSize, 1 - u.x)
                u.h = clamp(u.h + g.translation.height / canvas.height, minSize, 1 - u.y)
                live = u
            }
            .onEnded { _ in commit() }
    }

    private func commit() {
        guard let live else { return }
        withAnimation(.spring(duration: 0.2)) {
            slot.frame = snapped(live)
            self.live = nil
        }
    }

    private func snapped(_ u: UnitRect) -> UnitRect {
        useGrid ? gridSnapped(u) : magnetSnapped(u)
    }

    private func gridSnapped(_ u: UnitRect) -> UnitRect {
        func s(_ v: Double) -> Double { (v * Self.grid).rounded() / Self.grid }
        let w = max(s(u.w), 1 / Self.grid), h = max(s(u.h), 1 / Self.grid)
        return UnitRect(x: clamp(s(u.x), 0, 1 - w), y: clamp(s(u.y), 0, 1 - h), w: w, h: h)
    }

    /// Free, but edges stick to the screen border and neighbouring edges. Hold ⌥ for no snapping.
    private func magnetSnapped(_ u: UnitRect) -> UnitRect {
        guard !NSEvent.modifierFlags.contains(.option) else { return u }
        let xs: [Double] = [0, 1] + neighbours.flatMap { [$0.x, $0.maxX] }
        let ys: [Double] = [0, 1] + neighbours.flatMap { [$0.y, $0.y + $0.h] }
        let tx = Self.magnet / max(canvas.width, 1), ty = Self.magnet / max(canvas.height, 1)

        /// Smallest shift that puts one of the edges onto a target.
        func pull(_ edges: [Double], _ targets: [Double], _ t: Double) -> Double {
            var best: Double?
            for e in edges {
                for target in targets where abs(target - e) <= t && abs(target - e) < abs(best ?? .infinity) {
                    best = target - e
                }
            }
            return best ?? 0
        }

        var r = u
        switch drag {
        case .move:
            r.x += pull([u.x, u.maxX], xs, tx)
            r.y += pull([u.y, u.y + u.h], ys, ty)
        case .resize:
            r.w += pull([u.maxX], xs, tx)
            r.h += pull([u.y + u.h], ys, ty)
        }
        return r
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }

    private func caption(_ f: UnitRect) -> String {
        func pct(_ v: Double) -> String { "\(Int((v * 100).rounded())) %" }
        return "\(pct(f.w)) × \(pct(f.h))"
    }
}
