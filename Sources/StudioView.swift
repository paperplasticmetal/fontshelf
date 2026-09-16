import SwiftUI
import AppKit
import CoreText
import UniformTypeIdentifiers

struct StudioView: View {
    @ObservedObject var library: Library
    @ObservedObject var store: StudioStore
    @State private var spaceID: UUID?
    @State private var boardID: UUID?
    @State private var newName = ""
    @State private var showNewSpace = false
    @State private var confirmDelete = false
    var space: DesignSpace? { store.state.spaces.first { $0.id == spaceID } ?? store.state.spaces.first }
    var board: TypeBoard? { space?.boards.first { $0.id == boardID } ?? space?.boards.first }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Spaces").font(.system(size: 25, weight: .semibold))
                Spacer()
                if !store.state.spaces.isEmpty {
                    ShelfDropdown(title: "Space", selection: Binding(get: { space?.id ?? UUID() }, set: { spaceID = $0; boardID = nil }), options: store.state.spaces.map { ($0.name, $0.id) }).frame(width: 210)
                }
                Button { showNewSpace = true } label: { Label("New space", systemImage: "plus") }.disabled(store.readBlocked)
            }.padding(20)
            if !store.error.isEmpty { Text(store.error).foregroundStyle(.orange).textSelection(.enabled).padding(.horizontal, 20) }
            if let space {
                HStack {
                    TextField("Space name", text: Binding(get: { self.space?.name ?? "" }, set: { value in if let i = store.state.spaces.firstIndex(where: { $0.id == space.id }) { store.state.spaces[i].name = value; store.save() } })).textFieldStyle(.plain).frame(width: 170)
                    if !space.boards.isEmpty {
                        ShelfDropdown(title: "Typeboard", selection: Binding(get: { board?.id ?? UUID() }, set: { boardID = $0 }), options: space.boards.map { ($0.name, $0.id) }).frame(width: 240)
                    }
                    Spacer()
                    Button("New typeboard") { boardID = store.addBoard(space: space.id, fonts: library.compared.map { library.chosenFace($0).name }) }
                    Menu {
                        Button("Export space…") { exportSpace(space) }
                        Button("Import space…") { importSpace() }
                        Divider()
                        Button("Delete space…", role: .destructive) { confirmDelete = true }
                    } label: { Image(systemName: "ellipsis") }.frame(width: 30)
                }.padding(.horizontal, 20).padding(.bottom, 14)
                Divider()
                if let board {
                    TypeBoardEditor(library: library, board: board, onSave: { store.update(space: space.id, board: $0) }, onDelete: {
                        if let i = store.state.spaces.firstIndex(where: { $0.id == space.id }) { store.state.spaces[i].boards.removeAll { $0.id == board.id }; store.save(); boardID = nil }
                    }).id(board.id)
                } else {
                    VStack(spacing: 14) { Image(systemName: "rectangle.3.group").font(.system(size: 38)); Text("No typeboards").font(.title2); Button("Create typeboard") { boardID = store.addBoard(space: space.id) } }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.3.group").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text("Create a space").font(.title2)
                    Text("Keep typeboards and design directions together for a project.").foregroundStyle(.secondary)
                    HStack { Button("New space") { showNewSpace = true }; Button("Import space…") { importSpace() } }.disabled(store.readBlocked)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if let id = store.focusedSpace { spaceID = id }; if let id = store.focusedBoard { boardID = id } }
        .onChange(of: store.focusedBoard) { id in spaceID = store.focusedSpace; boardID = id }
        .alert("New space", isPresented: $showNewSpace) {
            TextField("Project or client name", text: $newName)
            Button("Create") { spaceID = store.addSpace(newName.trimmingCharacters(in: .whitespacesAndNewlines)); boardID = store.addBoard(space: spaceID!, fonts: library.compared.map { library.chosenFace($0).name }); newName = "" }
            Button("Cancel", role: .cancel) { newName = "" }
        }
        .alert("Delete this space and its typeboards?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { if let space { store.state.spaces.removeAll { $0.id == space.id }; store.save(); spaceID = nil; boardID = nil } }
            Button("Cancel", role: .cancel) {}
        }
    }
    func exportSpace(_ space: DesignSpace) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "\(space.name).fontshelf.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try JSONEncoder().encode(space).write(to: url, options: .atomic) } catch { store.error = error.localizedDescription }
    }
    func importSpace() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var space = try JSONDecoder().decode(DesignSpace.self, from: Data(contentsOf: url))
            guard space.boards.allSatisfy(\.isValid) else { throw CocoaError(.fileReadCorruptFile) }
            space.id = UUID()
            for i in space.boards.indices { space.boards[i].id = UUID(); space.boards[i].directions = space.boards[i].directions.map { $0.copy(name: $0.name) }; space.boards[i].selectedDirection = nil }
            store.state.spaces.append(space); store.save(); spaceID = space.id; boardID = nil
        } catch { store.error = "Space could not be imported: " + error.localizedDescription }
    }
}

extension TypeDirection {
    var isValid: Bool {
        width.isFinite && (320...1600).contains(width) && TypeRole.allCases.allSatisfy { role in
            guard let s = styles[role.rawValue] else { return false }
            return s.size.isFinite && (8...160).contains(s.size) && s.leading.isFinite && (1...2.5).contains(s.leading) && s.tracking.isFinite && (-3...12).contains(s.tracking) && s.axes.values.allSatisfy(\.isFinite)
        }
    }
}

struct TypeBoardEditor: View {
    @ObservedObject var library: Library
    @State var board: TypeBoard
    let onSave: (TypeBoard) -> Void
    let onDelete: () -> Void
    @State private var role = TypeRole.display
    @State private var fontSearch = ""
    @State private var compareID: UUID?
    @State private var zoom = 0.65
    @State private var showDelete = false
    @State private var status = ""
    var directionIndex: Int { board.directions.firstIndex { $0.id == board.selectedDirection } ?? 0 }
    var direction: TypeDirection { board.directions[directionIndex] }
    var style: TypeStyle { direction.style(role) }
    var faces: [Face] { library.allFaces.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    var missingFonts: [String] { Set(direction.styles.values.map(\.fontName)).subtracting(Set(library.allFaces.map(\.name))).sorted() }
    func save() { onSave(board) }
    func directionBinding<T>(_ key: WritableKeyPath<TypeDirection, T>) -> Binding<T> { Binding(get: { direction[keyPath: key] }, set: { board.directions[directionIndex][keyPath: key] = $0; save() }) }
    func styleBinding<T>(_ key: WritableKeyPath<TypeStyle, T>) -> Binding<T> { Binding(get: { style[keyPath: key] }, set: { var updated = style; updated[keyPath: key] = $0; board.directions[directionIndex].styles[role.rawValue] = updated; save() }) }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Typeboard name", text: Binding(get: { board.name }, set: { board.name = $0; save() })).textFieldStyle(.plain).font(.headline).frame(minWidth: 110)
                ShelfDropdown(title: "Direction", selection: Binding(get: { direction.id }, set: { board.selectedDirection = $0; save() }), options: board.directions.map { ($0.name, $0.id) }).frame(width: 230)
                Button { let copy = direction.copy(); board.directions.append(copy); board.selectedDirection = copy.id; save() } label: { Image(systemName: "plus.square.on.square") }.help("Duplicate direction")
                Menu {
                    Button("Export preview PDF…") { exportPDF() }
                    Button("Save checkpoint") { var values = board.checkpoints ?? []; values.append(DirectionCheckpoint(direction: direction)); board.checkpoints = Array(values.suffix(50)); save(); status = "Checkpoint saved" }
                    Menu("Restore checkpoint as direction") {
                        ForEach((board.checkpoints ?? []).reversed()) { checkpoint in Button(checkpoint.direction.name + " · " + checkpoint.date.formatted(date: .abbreviated, time: .shortened)) { let copy = checkpoint.direction.copy(name: checkpoint.direction.name + " restored"); board.directions.append(copy); board.selectedDirection = copy.id; save() } }
                    }.disabled((board.checkpoints ?? []).isEmpty)
                    Button("Add shortlist as candidates") { board.candidates = Array(Set(board.candidates + library.compared.map { library.chosenFace($0).name })).sorted(); save() }
                    Divider()
                    Button("Delete direction", role: .destructive) { let id = direction.id; board.directions.removeAll { $0.id == id }; board.selectedDirection = board.directions.first?.id; compareID = nil; save() }.disabled(board.directions.count < 2)
                    Button("Delete typeboard…", role: .destructive) { showDelete = true }
                } label: { Image(systemName: "ellipsis") }.frame(width: 28)
            }.padding(14)
            HStack {
                ShelfDropdown(title: "Canvas", selection: directionBinding(\.canvas), options: CanvasKind.allCases.map { ($0.rawValue, $0) }).frame(width: 210)
                ShelfDropdown(title: "Width", selection: directionBinding(\.width), options: [("Mobile · 390", 390.0), ("Tablet · 768", 768.0), ("Desktop · 1200", 1200.0), ("Canvas · 960", 960.0)]).frame(width: 190)
                Spacer()
                Menu("Compare") {
                    Button("Single direction") { compareID = nil }
                    ForEach(board.directions.filter { $0.id != direction.id }) { candidate in Button(candidate.name) { compareID = candidate.id } }
                }.frame(width: 90)
                ShelfDropdown(title: "Zoom", selection: $zoom, options: [("40%", 0.4), ("65%", 0.65), ("100%", 1.0)], showsTitle: false).frame(width: 80)
            }.padding(.horizontal, 14).padding(.bottom, 12)
            Divider()
            HStack(spacing: 0) {
                inspector.frame(width: 252)
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    if !missingFonts.isEmpty { Label("Unavailable fonts: " + missingFonts.joined(separator: ", ") + ". Preview uses fallback.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).padding(12) }
                    ScrollView([.horizontal, .vertical]) {
                        HStack(alignment: .top, spacing: 24) {
                            canvas(direction)
                            if let other = board.directions.first(where: { $0.id == compareID && $0.id != direction.id }) { canvas(other) }
                        }.padding(24)
                    }.background(Color.black.opacity(0.09))
                    HStack { Text(status.isEmpty ? "Changes saved to this space" : status); Spacer(); Text("\(Int(direction.width)) px · \(Int(zoom * 100))%").monospacedDigit() }.font(.caption).foregroundStyle(.secondary).padding(10)
                }
            }
        }.alert("Delete this typeboard?", isPresented: $showDelete) { Button("Delete", role: .destructive, action: onDelete); Button("Cancel", role: .cancel) {} }
    }
    func canvas(_ direction: TypeDirection) -> some View {
        let plan = CanvasPlan(direction: direction)
        return VStack(alignment: .leading, spacing: 10) {
            Text(direction.name).font(.caption).foregroundStyle(.secondary)
            CanvasPreview(plan: plan, zoom: zoom).frame(width: plan.size.width * zoom, height: plan.size.height * zoom).shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
    var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Direction name", text: directionBinding(\.name)).textFieldStyle(.roundedBorder)
                if direction.canvas == .custom { customBlocks }
                Text("TYPE ROLES").font(.caption).foregroundStyle(.secondary)
                ForEach(TypeRole.allCases) { item in
                    Button { role = item; fontSearch = "" } label: {
                        HStack { VStack(alignment: .leading, spacing: 3) { Text(item.rawValue).fontWeight(.medium); Text(direction.style(item).fontName).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Text("\(Int(direction.style(item).size))").monospacedDigit().foregroundStyle(.secondary) }.padding(9).background(role == item ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Divider()
                Text(role.rawValue).font(.headline)
                TextField("Find font", text: $fontSearch).textFieldStyle(.roundedBorder)
                fontChooser
                numeric("Size", value: styleBinding(\.size), range: 8...160, unit: "px")
                numeric("Leading", value: styleBinding(\.leading), range: 1...2.5, unit: "×")
                numeric("Tracking", value: styleBinding(\.tracking), range: -3...12, unit: "px")
                axesEditor
                if let face = library.allFaces.first(where: { $0.name == style.fontName }), !face.facts.features.isEmpty {
                    DisclosureGroup("OpenType features") {
                        ForEach(face.facts.features, id: \.self) { tag in
                            ShelfDropdown(title: tag, selection: Binding(get: { style.features[tag] ?? -1 }, set: { var s = style; if $0 < 0 { s.features.removeValue(forKey: tag) } else { s.features[tag] = $0 }; board.directions[directionIndex].styles[role.rawValue] = s; save() }), options: [("Default", -1), ("Off", 0), ("On", 1)] + (2...9).map { ("Alternate \($0)", $0) })
                        }
                    }
                }
                Text("Sample text").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: styleBinding(\.text)).frame(height: 100).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.25)))
                Divider()
                colorPicker("Text", key: \.ink); colorPicker("Background", key: \.paper); colorPicker("Accent", key: \.accent)
                Text("Direction notes").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: directionBinding(\.notes)).frame(height: 75)
            }.padding(14)
        }
    }
    var fontChooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(style.fontName).font(.caption).textSelection(.enabled)
            if !board.candidates.isEmpty {
                Menu("Pairing candidates (\(board.candidates.count))") {
                    ForEach(board.candidates, id: \.self) { name in Button(name) { chooseFont(name) } }
                }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(faces.filter { fontSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(fontSearch) || $0.originalFamily.localizedCaseInsensitiveContains(fontSearch) }) { face in
                        Button { chooseFont(face.name) } label: { Text(face.originalFamily + " · " + face.style).font(.system(size: 12)).lineLimit(1).padding(6).frame(maxWidth: .infinity, alignment: .leading).background(style.fontName == face.name ? Color.accentColor.opacity(0.15) : .clear) }.buttonStyle(.plain)
                    }
                }
            }.frame(height: 135).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
        }
    }
    var customBlocks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAYOUT BLOCKS").font(.caption).foregroundStyle(.secondary)
            let blocks = direction.blocks ?? TypeRole.allCases
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, role in
                HStack { Text(role.rawValue).font(.caption); Spacer(); Button { var values = blocks; values.swapAt(index, index - 1); board.directions[directionIndex].blocks = values; save() } label: { Image(systemName: "arrow.up") }.disabled(index == 0); Button { var values = blocks; values.remove(at: index); board.directions[directionIndex].blocks = values; save() } label: { Image(systemName: "minus") } }.buttonStyle(.borderless)
            }
            Menu("Add block") { ForEach(TypeRole.allCases) { role in Button(role.rawValue) { board.directions[directionIndex].blocks = blocks + [role]; save() } } }
        }
    }
    func chooseFont(_ name: String) { var s = style; s.fontName = name; s.axes = library.pro.axes[name] ?? [:]; s.features = library.pro.features[name] ?? [:]; board.directions[directionIndex].styles[role.rawValue] = s; save() }
    func numeric(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { HStack { Text(title); Spacer(); Text(String(format: title == "Size" ? "%.0f %@" : "%.2f %@", value.wrappedValue, unit)).monospacedDigit() }.font(.caption); Slider(value: value, in: range) }
    }
    var axesEditor: some View {
        let axes = CTFontCopyVariationAxes(CTFontCreateWithName(style.fontName as CFString, 24, nil)) as? [[String: Any]] ?? []
        return ForEach(Array(axes.enumerated()), id: \.offset) { _, axis in
            if let id = axis[kCTFontVariationAxisIdentifierKey as String] as? Int, let low = axis[kCTFontVariationAxisMinimumValueKey as String] as? Double, let high = axis[kCTFontVariationAxisMaximumValueKey as String] as? Double, let initial = axis[kCTFontVariationAxisDefaultValueKey as String] as? Double, high > low {
                numeric(axis[kCTFontVariationAxisNameKey as String] as? String ?? "Axis", value: Binding(get: { style.axes[id] ?? initial }, set: { var s = style; s.axes[id] = $0; board.directions[directionIndex].styles[role.rawValue] = s; save() }), range: low...high, unit: "")
            }
        }
    }
    func colorPicker(_ title: String, key: WritableKeyPath<TypeDirection, String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(nsColor: NSColor(hex: direction[keyPath: key])) }, set: { board.directions[directionIndex][keyPath: key] = NSColor($0).rgbHex; save() }), supportsOpacity: false)
    }
    func exportPDF() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = board.name + " — " + direction.name + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let plan = CanvasPlan(direction: direction); let view = CanvasNativeView(plan: plan); try view.dataWithPDF(inside: view.bounds).write(to: url, options: .atomic); status = "PDF exported" } catch { status = "Export failed: " + error.localizedDescription }
    }
}

struct CanvasElement {
    var rect: CGRect
    var text: NSAttributedString?
    var color: NSColor?
    var radius: Double = 0
}
struct CanvasPlan {
    var elements: [CanvasElement] = []
    var size: CGSize = .zero
    var paper: NSColor
    init(direction d: TypeDirection) {
        paper = NSColor(hex: d.paper)
        let w = min(1600, max(320, d.width)), margin = w < 500 ? 24.0 : 56.0, usable = w - margin * 2
        let ink = NSColor(hex: d.ink), accent = NSColor(hex: d.accent)
        var y = margin
        func text(_ role: TypeRole, _ override: String? = nil, x: Double? = nil, at: Double? = nil, width: Double? = nil, color: NSColor? = nil) -> Double {
            let style = d.style(role), paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = style.leading; paragraph.lineBreakMode = .byWordWrapping
            let value = NSAttributedString(string: override ?? style.text, attributes: [.font: style.font as NSFont, .foregroundColor: color ?? ink, .kern: style.tracking, .paragraphStyle: paragraph])
            let available = max(1, width ?? usable)
            let height = ceil(value.boundingRect(with: NSSize(width: available, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height) + 4
            elements.append(CanvasElement(rect: CGRect(x: x ?? margin, y: at ?? y, width: available, height: height), text: value))
            if at == nil { y += height + 18 }
            return height
        }
        func rule() { elements.append(CanvasElement(rect: CGRect(x: margin, y: y, width: usable, height: 1), color: ink.withAlphaComponent(0.18))); y += 26 }
        func button() { let start = y; let h = text(.label, x: margin + 18, at: start + 13, width: usable - 36); elements.insert(CanvasElement(rect: CGRect(x: margin, y: start, width: usable, height: h + 26), color: accent, radius: 7), at: elements.count - 1); y = start + h + 50 }
        switch d.canvas {
        case .custom:
            for role in d.blocks ?? TypeRole.allCases { _ = text(role) }
        case .website:
            _ = text(.caption); rule(); y += 30
            _ = text(.display); _ = text(.body); button(); rule()
            let cards = w >= 768 ? 3 : 1, gap = 24.0, cw = (usable - Double(cards - 1) * gap) / Double(cards)
            let top = y
            var bottom = y
            for i in 0..<cards {
                let x = margin + Double(i) * (cw + gap)
                elements.append(CanvasElement(rect: CGRect(x: x, y: top, width: cw, height: cw * 0.52), color: accent.withAlphaComponent(0.16), radius: 4))
                let h = text(.subheading, x: x, at: top + cw * 0.52 + 16, width: cw)
                let b = text(.body, x: x, at: top + cw * 0.52 + h + 28, width: cw)
                bottom = max(bottom, top + cw * 0.52 + h + b + 44)
            }
            y = bottom; rule(); _ = text(.caption, "ABOUT     JOURNAL     CONTACT")
        case .product:
            _ = text(.caption, "WORKSPACE / OVERVIEW"); rule(); _ = text(.heading); _ = text(.body)
            let columns = w >= 768 ? 3 : 1, gap = 16.0, cw = (usable - Double(columns - 1) * gap) / Double(columns)
            for start in stride(from: 0, to: 3, by: columns) {
                let rowY = y
                var bottom = y
                for i in start..<min(start + columns, 3) {
                    let x = margin + Double(i - start) * (cw + gap), insertion = elements.count
                    let captionHeight = text(.caption, ["PROJECTS", "IN REVIEW", "COMPLETED"][i], x: x + 16, at: rowY + 14, width: cw - 32)
                    let numberHeight = text(.subheading, ["24", "08", "16"][i], x: x + 16, at: rowY + captionHeight + 26, width: cw - 32)
                    let height = captionHeight + numberHeight + 42
                    elements.insert(CanvasElement(rect: CGRect(x: x, y: rowY, width: cw, height: height), color: accent.withAlphaComponent(0.12), radius: 8), at: insertion)
                    bottom = max(bottom, rowY + height)
                }
                y = bottom + 24
            }
            _ = text(.subheading, "Recent activity"); rule()
            for item in ["Website exploration", "Mobile interface", "Brand guidelines"] { _ = text(.label, item); _ = text(.caption, "Updated today · In progress"); rule() }
            _ = text(.mono); button()
        case .editorial:
            _ = text(.caption); y += 24; _ = text(.display); _ = text(.subheading); rule()
            let columns = w >= 768 ? 2 : 1, cw = (usable - Double(columns - 1) * 32) / Double(columns), top = y
            var bottom = y
            for i in 0..<columns { let h = text(.body, Array(repeating: d.style(.body).text, count: 5).joined(separator: "\n\n"), x: margin + Double(i) * (cw + 32), at: top, width: cw); bottom = max(bottom, top + h) }
            y = bottom + 32; rule(); _ = text(.caption, "01 / JOURNAL")
        case .poster:
            _ = text(.caption); y += 60; _ = text(.display); y += 30
            elements.append(CanvasElement(rect: CGRect(x: margin, y: y, width: usable, height: 12), color: accent)); y += 60
            _ = text(.heading); _ = text(.subheading); _ = text(.body); y += 50; rule(); _ = text(.label); _ = text(.mono)
        case .specimen:
            for role in TypeRole.allCases { _ = text(.caption, role.rawValue.uppercased() + " · " + d.style(role).fontName + " · \(Int(d.style(role).size)) PX"); _ = text(role); rule() }
        }
        size = CGSize(width: w, height: max(480, y + margin))
    }
}
final class CanvasNativeView: NSView {
    var plan: CanvasPlan
    var zoom = 1.0
    override var isFlipped: Bool { true }
    init(plan: CanvasPlan) { self.plan = plan; super.init(frame: CGRect(origin: .zero, size: plan.size)) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        plan.paper.setFill(); bounds.fill()
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.cgContext.scaleBy(x: zoom, y: zoom)
        for element in plan.elements {
            if let color = element.color { color.setFill(); NSBezierPath(roundedRect: element.rect, xRadius: element.radius, yRadius: element.radius).fill() }
            element.text?.draw(with: element.rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }
    }
}
struct CanvasPreview: NSViewRepresentable {
    let plan: CanvasPlan
    var zoom = 1.0
    func makeNSView(context: Context) -> CanvasNativeView { CanvasNativeView(plan: plan) }
    func updateNSView(_ view: CanvasNativeView, context: Context) { view.plan = plan; view.zoom = zoom; view.frame.size = CGSize(width: plan.size.width * zoom, height: plan.size.height * zoom); view.setAccessibilityElement(true); view.setAccessibilityLabel(plan.elements.compactMap { $0.text?.string }.joined(separator: ". ")); view.needsDisplay = true }
}
