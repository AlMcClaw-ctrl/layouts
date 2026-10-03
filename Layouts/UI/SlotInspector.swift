import SwiftUI

/// Details eines Fensterplatzes: App, Position, welches Fenster, wie neu öffnen.
struct SlotInspector: View {
    @Binding var slot: Slot
    /// Die übrigen Plätze im Preset (zum Angleichen).
    let others: [Slot]
    let onDelete: () -> Void

    private static let positions: [(String, String, UnitRect)] = [
        ("Linke Hälfte", "rectangle.lefthalf.filled", .leftHalf),
        ("Rechte Hälfte", "rectangle.righthalf.filled", .rightHalf),
        ("Linkes Drittel", "rectangle.split.3x1", UnitRect(x: 0, y: 0, w: 1.0 / 3, h: 1)),
        ("Mittleres Drittel", "rectangle.split.3x1", UnitRect(x: 1.0 / 3, y: 0, w: 1.0 / 3, h: 1)),
        ("Rechtes Drittel", "rectangle.split.3x1", UnitRect(x: 2.0 / 3, y: 0, w: 1.0 / 3, h: 1)),
        ("Linke zwei Drittel", "rectangle.leadinghalf.inset.filled", UnitRect(x: 0, y: 0, w: 2.0 / 3, h: 1)),
        ("Rechte zwei Drittel", "rectangle.trailinghalf.inset.filled", UnitRect(x: 1.0 / 3, y: 0, w: 2.0 / 3, h: 1)),
        ("Obere Hälfte", "rectangle.tophalf.filled", UnitRect(x: 0, y: 0, w: 1, h: 0.5)),
        ("Untere Hälfte", "rectangle.bottomhalf.filled", UnitRect(x: 0, y: 0.5, w: 1, h: 0.5)),
        ("Vollbild", "rectangle.fill", .full),
    ]

    var body: some View {
        Form {
            Section {
                Picker("App", selection: bundleID) {
                    ForEach(appChoices) { app in
                        Label {
                            Text(app.name)
                        } icon: {
                            if let icon = AppCatalog.icon(app.bundleID) { Image(nsImage: icon) }
                        }
                        .tag(app.bundleID)
                    }
                }
                Picker("Bildschirm", selection: $slot.screen) {
                    ForEach(screenChoices, id: \.ref) { Text($0.name).tag($0.ref) }
                }
                LabeledContent("Position") {
                    HStack(spacing: 4) {
                        ForEach(Self.positions, id: \.0) { title, symbol, rect in
                            Button { slot.frame = rect } label: { Image(systemName: symbol) }
                                .help(title)
                                .buttonStyle(.bordered)
                                .tint(slot.frame == rect ? .accentColor : nil)
                        }
                    }
                }
                if !others.isEmpty {
                    LabeledContent("An Fenster angleichen") {
                        HStack {
                            if others.count == 1, let ref = others.first {
                                Button("Restfläche neben \(name(ref)) füllen") { align { $0.fillingBeside(ref.frame) } }
                                    .buttonStyle(.borderedProminent)
                            }
                            Menu(others.count == 1 ? "Mehr" : "Angleichen an …") {
                                ForEach(others) { ref in
                                    Section(name(ref)) {
                                        Button("Restfläche daneben füllen") { align { $0.fillingBeside(ref.frame) } }
                                        Button("Gleiche Größe, daneben") { align { $0.sameSizeBeside(ref.frame) } }
                                        Button("Gleiche Höhe und Oberkante") { align { $0.sameRow(ref.frame) } }
                                    }
                                }
                            }
                            .fixedSize()
                        }
                    }
                }
            }

            Section("Welches Fenster") {
                Stepper(value: index, in: 0...9) {
                    LabeledContent("Fenster Nr.", value: slot.match.index.map { "\($0 + 1)" } ?? "beliebig")
                }
                TextField("Titel enthält (optional)", text: text(\.match.title))
            }

            Section("Wenn das Fenster fehlt") {
                Picker("Öffnen per", selection: launchKind) {
                    Text("Neues Fenster (Menü / ⌘N)").tag(LaunchSpec.Kind.newWindow)
                    Text("URL").tag(LaunchSpec.Kind.url)
                    Text("Terminal mit Befehl").tag(LaunchSpec.Kind.terminal)
                }
                switch slot.launch?.kind ?? .newWindow {
                case .newWindow:
                    EmptyView()
                case .url:
                    TextField("https://…", text: launchText(\.url))
                case .terminal:
                    TextField("Ordner, z. B. ~/Projects/foo", text: launchText(\.cwd))
                    TextField("Befehl, z. B. claude", text: launchText(\.command))
                }
            }

            Section {
                Button("Platz entfernen", role: .destructive, action: onDelete)
            }
        }
        .formStyle(.grouped)
    }

    private func align(_ transform: (UnitRect) -> UnitRect) {
        withAnimation(.spring(duration: 0.25)) { slot.frame = transform(slot.frame) }
    }

    private func name(_ s: Slot) -> String {
        let base = s.appName ?? AppCatalog.name(s.bundleID)
        let same = others.filter { $0.bundleID == s.bundleID }
        guard same.count > 1, let i = same.firstIndex(where: { $0.id == s.id }) else { return base }
        return "\(base) \(i + 1)"
    }

    // MARK: Bindings

    private var bundleID: Binding<String> {
        Binding(get: { slot.bundleID }, set: {
            slot.bundleID = $0
            slot.appName = AppCatalog.name($0)
        })
    }

    private var appChoices: [AppCatalog.Entry] {
        var apps = AppCatalog.runningApps()
        if !apps.contains(where: { $0.bundleID == slot.bundleID }) {
            apps.insert(.init(bundleID: slot.bundleID, name: slot.appName ?? AppCatalog.name(slot.bundleID)), at: 0)
        }
        return apps
    }

    private var screenChoices: [(ref: String, name: String)] {
        var list = NSScreen.screens.map { s in
            (ref: Screens.ref(for: s), name: s == Screens.primary ? "Hauptbildschirm (\(s.localizedName))" : s.localizedName)
        }
        if !list.contains(where: { $0.ref == slot.screen }) { list.append((ref: slot.screen, name: "\(slot.screen) (nicht verbunden)")) }
        return list
    }

    private var index: Binding<Int> {
        Binding(get: { slot.match.index ?? -1 }, set: { slot.match.index = $0 < 0 ? nil : $0 })
    }

    private func text(_ path: WritableKeyPath<Slot, String?>) -> Binding<String> {
        Binding(get: { slot[keyPath: path] ?? "" }, set: { slot[keyPath: path] = $0.isEmpty ? nil : $0 })
    }

    private var launchKind: Binding<LaunchSpec.Kind> {
        Binding(get: { slot.launch?.kind ?? .newWindow }, set: { kind in
            if kind == .newWindow {
                slot.launch = nil
            } else {
                var spec = slot.launch ?? LaunchSpec(kind: kind)
                spec.kind = kind
                slot.launch = spec
            }
        })
    }

    private func launchText(_ path: WritableKeyPath<LaunchSpec, String?>) -> Binding<String> {
        Binding(get: { slot.launch?[keyPath: path] ?? "" }, set: { slot.launch?[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
}
