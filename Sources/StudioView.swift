import SwiftUI
import AppKit
import CoreText
import UniformTypeIdentifiers

struct WorkspaceSwitcher: View {
    @ObservedObject var library: Library
    var body: some View {
        Picker("Workspace", selection: $library.workspace) { Text("Library").tag(false); Text("Spaces").tag(true) }.pickerStyle(.segmented).labelsHidden()
    }
}
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
        HStack(spacing: 0) {
        navigation.frame(width: 232).environment(\.shelfInsideGlass, true).modifier(ShelfSidebarGlass()).padding(12)
        VStack(spacing: 0) {
            if !store.error.isEmpty { Text(store.error).foregroundStyle(.orange).textSelection(.enabled).padding(.horizontal, 20) }
            if let space {
                HStack {
                    TextField("Space name", text: Binding(get: { self.space?.name ?? "" }, set: { value in if let i = store.state.spaces.firstIndex(where: { $0.id == space.id }) { store.state.spaces[i].name = value; store.save() } })).textFieldStyle(.plain).font(.system(size: 22, weight: .semibold))
                    Spacer()
                    Button("New pairing") { boardID = store.addBoard(space: space.id, fonts: library.compared.map { library.chosenFace($0).name }) }
                    Menu {
                        Button("Export space…") { exportSpace(space) }
                        Button("Import space…") { importSpace() }
                        Divider()
                        Button("Delete space…", role: .destructive) { confirmDelete = true }
                    } label: { Image(systemName: "ellipsis") }.frame(width: 30)
                }.padding(18)
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
        } }
        .onAppear { if let id = store.focusedSpace { spaceID = id }; if let id = store.focusedBoard { boardID = id } }
        .onChange(of: store.focusedSpace) { id in spaceID = id; boardID = store.focusedBoard }
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
    var navigation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FontShelf").font(.headline).padding(.top, 22)
            WorkspaceSwitcher(library: library)
            HStack { Text("SPACES").font(.caption).foregroundStyle(.secondary); Spacer(); Button { showNewSpace = true } label: { Image(systemName: "plus") }.help("New space").disabled(store.readBlocked) }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.state.spaces) { item in
                        Button { spaceID = item.id; boardID = nil; store.focusedSpace = item.id; store.focusedBoard = nil; store.save() } label: {
                            Label(item.name, systemImage: "rectangle.3.group").fontWeight(.medium).frame(maxWidth: .infinity, alignment: .leading).padding(10).background(space?.id == item.id ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                        ForEach(item.boards) { child in
                            Button { spaceID = item.id; boardID = child.id; store.focusedSpace = item.id; store.focusedBoard = child.id; store.save() } label: {
                                HStack { Image(systemName: "rectangle.on.rectangle"); Text(child.name).lineLimit(2); Spacer() }.font(.caption).padding(.leading, 16).padding(8).foregroundStyle(board?.id == child.id ? Color.accentColor : Color.secondary).background(board?.id == child.id ? Color.primary.opacity(0.04) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Button("Import space…") { importSpace() }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.bottom, 12)
        }.padding(.horizontal, 12)
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
            return s.size.isFinite && (8...160).contains(s.size) && s.leading.isFinite && (1...2.5).contains(s.leading) && s.tracking.isFinite && (-3...12).contains(s.tracking) && s.axes.values.allSatisfy(\.isFinite) && (s.lineHeight.map { $0.isFinite && (8...400).contains($0) } ?? true) && [s.paragraphSpacing, s.indent].allSatisfy { $0.map { $0.isFinite && (0...200).contains($0) } ?? true } && (s.wordSpacing.map { $0.isFinite && (-3...40).contains($0) } ?? true)
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
    @State private var zoom = 0.0
    @State private var showDelete = false
    @State private var status = ""
    @State private var showFontPicker = false
    @State private var draggedSection: String?
    @State private var selectedSection: String?
    @State private var abID: UUID?
    @State private var inspectorTab = "Typography"
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
                    Button("Export editable Figma layout…") { exportFigma() }
                    Button("Save checkpoint") { var values = board.checkpoints ?? []; values.append(DirectionCheckpoint(direction: direction)); board.checkpoints = Array(values.suffix(50)); save(); status = "Checkpoint saved" }
                    Menu("Restore checkpoint as direction") {
                        ForEach((board.checkpoints ?? []).reversed()) { checkpoint in Button(checkpoint.direction.name + " · " + checkpoint.date.formatted(date: .abbreviated, time: .shortened)) { let copy = checkpoint.direction.copy(name: checkpoint.direction.name + " restored"); board.directions.append(copy); board.selectedDirection = copy.id; save() } }
                    }.disabled((board.checkpoints ?? []).isEmpty)
                    Button("Add shortlist as candidates") { board.candidates = Array(Set(board.candidates + library.compared.map { library.chosenFace($0).name })).sorted(); save() }
                    Divider()
                    Button("Delete direction", role: .destructive) { let id = direction.id; board.directions.removeAll { $0.id == id }; board.selectedDirection = board.directions.first?.id; compareID = nil; abID = nil; save() }.disabled(board.directions.count < 2)
                    Button("Delete typeboard…", role: .destructive) { showDelete = true }
                } label: { Image(systemName: "ellipsis") }.frame(width: 28)
            }.padding(14)
            HStack {
                ShelfDropdown(title: "Canvas", selection: directionBinding(\.canvas), options: CanvasKind.allCases.map { ($0.rawValue, $0) }).frame(width: 210)
                ShelfDropdown(title: "Width", selection: directionBinding(\.width), options: [("Mobile · 390", 390.0), ("Tablet · 768", 768.0), ("Desktop · 1200", 1200.0), ("Canvas · 960", 960.0)]).frame(width: 190)
                Spacer()
                Menu {
                    ForEach(board.directions.filter { $0.id != direction.id && $0.canvas == direction.canvas && $0.width == direction.width }) { candidate in Button(candidate.name) { abID = candidate.id; compareID = nil } }
                    if abID != nil { Button("End A/B test") { abID = nil } }
                } label: { Text(abID == nil ? "A/B test" : "A/B: " + (board.directions.first { $0.id == abID }?.name ?? "")) }.fixedSize().help("Choose a direction with the same canvas and width")
                Button("Swap A/B") { swapAB() }.keyboardShortcut("\\", modifiers: [.command]).disabled(abID == nil).help("Swap directions (⌘\\)")
                Menu("Compare") {
                    Button("Single direction") { compareID = nil }
                    ForEach(board.directions.filter { $0.id != direction.id }) { candidate in Button(candidate.name) { compareID = candidate.id } }
                }.frame(width: 90)
                ShelfDropdown(title: "Zoom", selection: $zoom, options: [("Fit", 0.0), ("40%", 0.4), ("65%", 0.65), ("100%", 1.0)], showsTitle: false).frame(width: 80)
            }.padding(.horizontal, 14).padding(.bottom, 12)
            Divider()
            HSplitView {
                inspector.frame(minWidth: 240, idealWidth: 310, maxWidth: 500)
                VStack(alignment: .leading, spacing: 0) {
                    if library.loading { ProgressView(library.families.isEmpty ? "Loading font library…" : "Checking watched font folders…").controlSize(.small).padding(10) }
                    else if !missingFonts.isEmpty { Label("Unavailable fonts: " + missingFonts.joined(separator: ", ") + ". Preview uses fallback.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).padding(12) }
                    GeometryReader { geometry in
                    let other = board.directions.first(where: { $0.id == compareID && $0.id != direction.id })
                    let scale = zoom == 0 ? min(1, max(0.15, (geometry.size.width - 48 - (other == nil ? 0 : 24)) / (direction.width + (other?.width ?? 0)))) : zoom
                    ScrollView([.horizontal, .vertical]) {
                        HStack(alignment: .top, spacing: 24) {
                            canvas(direction, scale: scale)
                            if let other { canvas(other, scale: scale) }
                        }.padding(24)
                    }.background(Color.black.opacity(0.09))
                    }
                    HStack { Text(status.isEmpty ? "Changes saved to this space" : status); Spacer(); Text("\(Int(direction.width)) px · " + (zoom == 0 ? "Fit" : "\(Int(zoom * 100))%" )).monospacedDigit() }.font(.caption).foregroundStyle(.secondary).padding(10)
                }.frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }.alert("Delete this typeboard?", isPresented: $showDelete) { Button("Delete", role: .destructive, action: onDelete); Button("Cancel", role: .cancel) {} }
        .onChange(of: direction.id) { _ in selectedSection = nil; draggedSection = nil; if let other = board.directions.first(where: { $0.id == abID }), other.canvas != direction.canvas || other.width != direction.width { abID = nil } }
        .onChange(of: direction.canvas) { _ in abID = nil; selectedSection = nil }
        .onChange(of: direction.width) { _ in abID = nil }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FontShelfMenu"))) { event in if event.object as? String == "find" { showFontPicker = true } }
    }
    func swapAB() { guard let id = abID, board.directions.contains(where: { $0.id == id && $0.canvas == direction.canvas && $0.width == direction.width }) else { return }; abID = direction.id; board.selectedDirection = id; compareID = nil; save() }
    func moveSection(_ source: String, _ target: String, _ before: Bool) {
        let plan = CanvasPlan(direction: direction)
        board.directions[directionIndex].reorder(source, target: target, before: before, visible: plan.sections.map(\.id)); selectedSection = source; save()
    }
    func canvas(_ direction: TypeDirection, scale: Double) -> some View {
        let zoom = scale
        let plan = CanvasPlan(direction: direction)
        return VStack(alignment: .leading, spacing: 10) {
            Text(direction.name).font(.caption).foregroundStyle(.secondary)
            CanvasPreview(plan: plan, zoom: zoom, directionID: direction.id == self.direction.id ? direction.id : nil, selectedSection: selectedSection, onSelect: { id in selectedSection = id; if let item = plan.elements.first(where: { $0.sectionID == id && $0.role != nil })?.role { role = item } }, onMove: moveSection)
                .frame(width: plan.size.width * zoom, height: plan.size.height * zoom).shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
    var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Direction name", text: directionBinding(\.name)).textFieldStyle(.roundedBorder)
                Picker("Inspector", selection: $inspectorTab) { Text("Typography").tag("Typography"); Text("Arrangement").tag("Arrangement") }.pickerStyle(.segmented).labelsHidden()
                if inspectorTab == "Arrangement" { layoutSections }
                else {
                Text("TYPE ROLES").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                ForEach(TypeRole.allCases) { item in
                    Button { role = item; fontSearch = "" } label: {
                        HStack { Text(item.rawValue).font(.caption).fontWeight(.medium); Spacer(); Text("\(Int(direction.style(item).size))").font(.caption).monospacedDigit().foregroundStyle(.secondary) }.padding(9).background(role == item ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                }
                Divider()
                Text(role.rawValue).font(.headline)
                Button { showFontPicker = true } label: { HStack { VStack(alignment: .leading, spacing: 4) { Text("Font").font(.caption).foregroundStyle(.secondary); Text(style.fontName).lineLimit(2) }; Spacer(); Image(systemName: "magnifyingglass") }.padding(10).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .popover(isPresented: $showFontPicker) { fontPicker }
                numeric("Size", value: styleBinding(\.size), range: 8...160, unit: "px")
                numeric("Line height", value: Binding(get: { style.lineHeight ?? style.size * style.leading }, set: { var s = style; s.lineHeight = $0; board.directions[directionIndex].styles[role.rawValue] = s; save() }), range: 8...400, unit: "px")
                Button("Auto line height") { var s = style; s.lineHeight = nil; board.directions[directionIndex].styles[role.rawValue] = s; save() }.font(.caption)
                numeric("Letter spacing", value: styleBinding(\.tracking), range: -3...12, unit: "px")
                ShelfDropdown(title: "Alignment", selection: optionalStyleBinding(\.alignment, default: .left), options: TextAlignmentOption.allCases.map { ($0.rawValue, $0) })
                Toggle("Font kerning", isOn: optionalStyleBinding(\.kerning, default: true)).toggleStyle(.checkbox)
                DisclosureGroup("More text settings") {
                    VStack(spacing: 12) {
                        numeric("Word spacing", value: optionalStyleBinding(\.wordSpacing, default: 0), range: -3...40, unit: "px")
                        numeric("Paragraph spacing", value: optionalStyleBinding(\.paragraphSpacing, default: 0), range: 0...200, unit: "px")
                        numeric("First-line indent", value: optionalStyleBinding(\.indent, default: 0), range: 0...200, unit: "px")
                        ShelfDropdown(title: "Case", selection: optionalStyleBinding(\.casing, default: .original), options: TextCaseOption.allCases.map { ($0.rawValue, $0) })
                        HStack { Toggle("Underline", isOn: optionalStyleBinding(\.underline, default: false)); Toggle("Strike", isOn: optionalStyleBinding(\.strikethrough, default: false)) }.toggleStyle(.checkbox)
                    }.padding(.top, 10)
                }
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
                }
                Divider()
                colorPicker("Text", key: \.ink); colorPicker("Background", key: \.paper); colorPicker("Accent", key: \.accent)
                Text("Direction notes").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: directionBinding(\.notes)).frame(height: 75)
            }.padding(14)
        }
    }
    func optionalStyleBinding<T>(_ key: WritableKeyPath<TypeStyle, T?>, default fallback: T) -> Binding<T> { Binding(get: { style[keyPath: key] ?? fallback }, set: { var s = style; s[keyPath: key] = $0; board.directions[directionIndex].styles[role.rawValue] = s; save() }) }
    var fontPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Choose font · " + role.rawValue).font(.headline); Spacer(); Button("Done") { showFontPicker = false } }
            TextField("Search fonts and styles", text: $fontSearch).textFieldStyle(.roundedBorder)
            if !board.candidates.isEmpty {
                Menu("Pairing candidates (\(board.candidates.count))") {
                    ForEach(board.candidates, id: \.self) { name in Button(name) { chooseFont(name) } }
                }
            }
            if library.loading && faces.isEmpty { ProgressView("Loading font library…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(faces.filter { fontSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(fontSearch) || $0.originalFamily.localizedCaseInsensitiveContains(fontSearch) }) { face in
                        Button { chooseFont(face.name) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(face.originalFamily + " · " + face.style).font(.caption); Spacer(); if style.fontName == face.name { Image(systemName: "checkmark") } }
                                FontPreview(text: style.text.isEmpty ? "Aa Bb Cc 0123456789" : String(style.text.prefix(90)), name: face.name, size: 27, wraps: true).frame(minHeight: 38).allowsHitTesting(false)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(style.fontName == face.name ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(maxHeight: .infinity)
        }.padding(18).frame(width: 580, height: 540)
    }
    var layoutSections: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("ARRANGEMENT").font(.caption).foregroundStyle(.secondary); Spacer(); Menu { ForEach(TypeRole.allCases) { item in Button(item.rawValue) { board.directions[directionIndex].addedBlocks = (direction.addedBlocks ?? []) + [LayoutBlock(role: item)]; save() } }; if !(direction.hiddenSections ?? []).isEmpty { Button("Restore removed sections") { board.directions[directionIndex].hiddenSections = nil; save() } } } label: { Image(systemName: "plus") }.frame(width: 28) }
            let plan = CanvasPlan(direction: direction)
            ForEach(plan.sections) { section in
                HStack {
                    SectionDragTarget(id: section.id, title: section.title, directionID: direction.id, height: 34, selected: selectedSection == section.id, dragging: $draggedSection, onSelect: { selectedSection = section.id }, onMove: moveSection, showsLabel: true).frame(height: 34)
                    Button { var hidden = direction.hiddenSections ?? []; hidden.insert(section.id); board.directions[directionIndex].hiddenSections = hidden; save() } label: { Image(systemName: "minus") }.buttonStyle(.borderless).help("Remove section")
                }
            }
            Text("Drag sections here or on the canvas.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    func chooseFont(_ name: String) { var s = style; s.fontName = name; s.axes = library.pro.axes[name] ?? [:]; s.features = library.pro.features[name] ?? [:]; board.directions[directionIndex].styles[role.rawValue] = s; save() }
    func numeric(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { HStack { Text(title); Spacer(); TextField(title, value: Binding(get: { value.wrappedValue }, set: { if $0.isFinite { value.wrappedValue = min(range.upperBound, max(range.lowerBound, $0)) } }), format: .number.precision(.fractionLength(0...2))).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width: 65); Text(unit).foregroundStyle(.secondary) }.font(.caption); Slider(value: value, in: range) }
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
    func exportFigma() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.message = "Choose where to save the editable Figma layout and local importer. No fonts are bundled."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let folder = try FigmaLayoutExporter.write(board: board, parent: url); status = "Figma package exported. See README in the package for import steps."; NSWorkspace.shared.activateFileViewerSelecting([folder]) } catch { status = "Figma export failed: " + error.localizedDescription }
    }
}

struct CanvasElement {
    var rect: CGRect
    var text: NSAttributedString?
    var color: NSColor?
    var radius: Double = 0
    var sectionID = ""
    var style: TypeStyle?
    var role: TypeRole?
}
struct CanvasSection: Identifiable { var id: String; var title: String; var rect: CGRect }
struct CanvasPlan {
    var elements: [CanvasElement] = []
    var sections: [CanvasSection] = []
    var size: CGSize = .zero
    var paper: NSColor
    init(direction d: TypeDirection) {
        paper = NSColor(hex: d.paper)
        let w = min(1600, max(320, d.width)), margin = w < 500 ? 24.0 : 56.0, usable = w - margin * 2
        let ink = NSColor(hex: d.ink), accent = NSColor(hex: d.accent)
        var y = margin
        var currentID = "", currentTitle = "", sectionStart = margin, elementStart = 0
        func finishSection() {
            guard !currentID.isEmpty else { return }
            for i in elementStart..<elements.count { elements[i].sectionID = currentID }
            sections.append(CanvasSection(id: currentID, title: currentTitle, rect: CGRect(x: 0, y: sectionStart, width: w, height: max(24, y - sectionStart))))
        }
        func section(_ id: String, _ title: String) {
            finishSection(); currentID = d.canvas.rawValue + ":" + id; currentTitle = title; sectionStart = y; elementStart = elements.count
        }
        func text(_ role: TypeRole, _ override: String? = nil, x: Double? = nil, at: Double? = nil, width: Double? = nil, color: NSColor? = nil) -> Double {
            let style = d.style(role)
            let value = style.attributed(override, color: color ?? ink)
            let available = max(1, width ?? usable)
            let height = ceil(value.boundingRect(with: NSSize(width: available, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height) + 4
            elements.append(CanvasElement(rect: CGRect(x: x ?? margin, y: at ?? y, width: available, height: height), text: value, style: style, role: role))
            if at == nil { y += height + 18 }
            return height
        }
        func rule() { elements.append(CanvasElement(rect: CGRect(x: margin, y: y, width: usable, height: 1), color: ink.withAlphaComponent(0.18))); y += 26 }
        func button() { let start = y; let h = text(.label, x: margin + 18, at: start + 13, width: usable - 36); elements.insert(CanvasElement(rect: CGRect(x: margin, y: start, width: usable, height: h + 26), color: accent, radius: 7), at: elements.count - 1); y = start + h + 50 }
        switch d.canvas {
        case .custom:
            for (index, role) in (d.blocks ?? TypeRole.allCases).enumerated() { section("block-\(index)", role.rawValue); _ = text(role) }
        case .website:
            section("masthead", "Masthead")
            _ = text(.caption); rule(); y += 30
            section("hero", "Hero")
            _ = text(.display); _ = text(.body); button(); rule()
            section("cards", "Content cards")
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
            y = bottom; rule(); section("footer", "Footer"); _ = text(.caption, "ABOUT     JOURNAL     CONTACT")
        case .product:
            section("navigation", "Navigation"); _ = text(.caption, "WORKSPACE / OVERVIEW"); rule(); section("intro", "Introduction"); _ = text(.heading); _ = text(.body)
            section("stats", "Statistics")
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
            section("activity-heading", "Activity heading"); _ = text(.subheading, "Recent activity"); rule()
            for (i, item) in ["Website exploration", "Mobile interface", "Brand guidelines"].enumerated() { section("activity-\(i)", item); _ = text(.label, item); _ = text(.caption, "Updated today · In progress"); rule() }
            section("action", "Action"); _ = text(.mono); button()
        case .editorial:
            section("masthead", "Masthead"); _ = text(.caption); y += 24; section("headline", "Headline"); _ = text(.display); _ = text(.subheading); rule()
            section("article", "Article columns")
            let columns = w >= 768 ? 2 : 1, cw = (usable - Double(columns - 1) * 32) / Double(columns), top = y
            var bottom = y
            for i in 0..<columns { let h = text(.body, Array(repeating: d.style(.body).text, count: 5).joined(separator: "\n\n"), x: margin + Double(i) * (cw + 32), at: top, width: cw); bottom = max(bottom, top + h) }
            y = bottom + 32; rule(); section("footer", "Folio"); _ = text(.caption, "01 / JOURNAL")
        case .poster:
            section("eyebrow", "Eyebrow"); _ = text(.caption); y += 60; section("display", "Display"); _ = text(.display); y += 30
            elements.append(CanvasElement(rect: CGRect(x: margin, y: y, width: usable, height: 12), color: accent)); y += 60
            section("details", "Details"); _ = text(.heading); _ = text(.subheading); _ = text(.body); y += 50; rule(); section("footer", "Footer"); _ = text(.label); _ = text(.mono)
        case .specimen:
            for role in TypeRole.allCases { section(role.rawValue, role.rawValue); _ = text(.caption, role.rawValue.uppercased() + " · " + d.style(role).fontName + " · \(Int(d.style(role).size)) PX"); _ = text(role); rule() }
        }
        for block in d.addedBlocks ?? [] { section(block.id, block.role.rawValue); _ = text(block.role) }
        finishSection()
        let original = elements, sourceSections = sections
        let available = sourceSections.map(\.id).filter { !(d.hiddenSections ?? []).contains($0) }
        var ordered: [String] = []
        for id in (d.sectionOrder ?? []) + available where available.contains(id) && !ordered.contains(id) { ordered.append(id) }
        elements = []; sections = []; y = margin
        for id in ordered {
            guard var part = sourceSections.first(where: { $0.id == id }) else { continue }
            let offset = y - part.rect.minY
            for var element in original where element.sectionID == id { element.rect.origin.y += offset; elements.append(element) }
            part.rect.origin.y = y; sections.append(part); y += part.rect.height
        }
        size = CGSize(width: w, height: max(480, y + margin))
    }
}
final class CanvasNativeView: NSView, NSDraggingSource {
    var plan: CanvasPlan
    var zoom = 1.0
    var directionID: UUID?
    var selectedSection: String?
    var onSelect: ((String) -> Void)?
    var onMove: ((String, String, Bool) -> Void)?
    private var dragSection: CanvasSection?
    private var insertionY: Double?
    override var isFlipped: Bool { true }
    init(plan: CanvasPlan) { self.plan = plan; super.init(frame: CGRect(origin: .zero, size: plan.size)); registerForDraggedTypes([.string]) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func resetCursorRects() { if directionID != nil { addCursorRect(bounds, cursor: .openHand) } }
    func section(at point: NSPoint) -> CanvasSection? { let y = point.y / max(0.01, zoom); return plan.sections.first { y >= $0.rect.minY && y < $0.rect.maxY } }
    override func mouseDown(with event: NSEvent) {
        guard directionID != nil else { return }
        dragSection = section(at: convert(event.locationInWindow, from: nil))
        if let item = dragSection { selectedSection = item.id; onSelect?(item.id); needsDisplay = true }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let id = directionID, let item = dragSection else { return }
        dragSection = nil
        let token = id.uuidString + "|" + item.id
        let draggingItem = NSDraggingItem(pasteboardWriter: token as NSString)
        let image = NSImage(size: NSSize(width: 180, height: 32))
        image.lockFocus(); NSColor.controlBackgroundColor.setFill(); NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 180, height: 32), xRadius: 6, yRadius: 6).fill(); (item.title as NSString).draw(at: NSPoint(x: 10, y: 8), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]); image.unlockFocus()
        let point = convert(event.locationInWindow, from: nil)
        draggingItem.setDraggingFrame(NSRect(x: point.x, y: point.y, width: 180, height: 32), contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .move }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
    private func source(_ sender: NSDraggingInfo) -> String? {
        guard let directionID, let value = sender.draggingPasteboard.string(forType: .string), value.hasPrefix(directionID.uuidString + "|") else { return nil }
        let id = String(value.dropFirst(37)); return plan.sections.contains { $0.id == id } ? id : nil
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard source(sender) != nil else { return [] }
        let point = convert(sender.draggingLocation, from: nil)
        guard let target = section(at: point) else { insertionY = nil; needsDisplay = true; return [] }
        insertionY = point.y / zoom < target.rect.midY ? target.rect.minY : target.rect.maxY; needsDisplay = true; return .move
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { insertionY = nil; needsDisplay = true }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { insertionY = nil; needsDisplay = true }
        guard let source = source(sender) else { return false }
        let point = convert(sender.draggingLocation, from: nil)
        guard let target = section(at: point) else { return false }
        onMove?(source, target.id, point.y / zoom < target.rect.midY); return true
    }
    override func draw(_ dirtyRect: NSRect) {
        plan.paper.setFill(); bounds.fill()
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.cgContext.scaleBy(x: zoom, y: zoom)
        for element in plan.elements {
            if let color = element.color { color.setFill(); NSBezierPath(roundedRect: element.rect, xRadius: element.radius, yRadius: element.radius).fill() }
            element.text?.draw(with: element.rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        }
        if directionID != nil, let selected = plan.sections.first(where: { $0.id == selectedSection }) {
            NSColor.controlAccentColor.withAlphaComponent(0.7).setStroke(); let border = NSBezierPath(rect: selected.rect.insetBy(dx: 1 / zoom, dy: 0)); border.lineWidth = 1 / zoom; border.stroke()
        }
        if let insertionY { NSColor.controlAccentColor.setFill(); NSRect(x: 0, y: insertionY, width: plan.size.width, height: 3 / zoom).fill() }
    }
}
struct CanvasPreview: NSViewRepresentable {
    let plan: CanvasPlan
    var zoom = 1.0
    var directionID: UUID?
    var selectedSection: String?
    var onSelect: ((String) -> Void)?
    var onMove: ((String, String, Bool) -> Void)?
    func makeNSView(context: Context) -> CanvasNativeView { CanvasNativeView(plan: plan) }
    func updateNSView(_ view: CanvasNativeView, context: Context) { view.plan = plan; view.zoom = zoom; view.directionID = directionID; view.selectedSection = selectedSection; view.onSelect = onSelect; view.onMove = onMove; view.frame.size = CGSize(width: plan.size.width * zoom, height: plan.size.height * zoom); view.setAccessibilityElement(true); view.setAccessibilityLabel(plan.elements.compactMap { $0.text?.string }.joined(separator: ". ")); view.needsDisplay = true }
}

struct SectionDragTarget: View {
    let id: String
    let title: String
    let directionID: UUID
    let height: Double
    let selected: Bool
    @Binding var dragging: String?
    let onSelect: () -> Void
    let onMove: (String, String, Bool) -> Void
    var showsLabel = false
    @State private var insertion: Bool?
    @State private var hovered = false
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(selected ? Color.accentColor.opacity(0.055) : .clear)
            if showsLabel { HStack { Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary); Text(title).font(.caption); Spacer() }.padding(.horizontal, 8) }
            if hovered && !showsLabel { Text(title).font(.caption2).padding(5).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4)).padding(4).frame(maxHeight: .infinity, alignment: .top) }
        }
        .contentShape(Rectangle())
        .overlay(Rectangle().stroke(selected || hovered ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1))
        .overlay(alignment: insertion == false ? .bottom : .top) { if insertion != nil { Rectangle().fill(Color.accentColor).frame(height: 3) } }
        .onHover { hovered = $0 }
        .onTapGesture(perform: onSelect)
        .onDrag { let token = directionID.uuidString + "|" + id; dragging = token; return NSItemProvider(object: token as NSString) }
        .onDrop(of: [UTType.plainText], delegate: SectionDropDelegate(target: id, directionID: directionID, height: height, dragging: $dragging, insertion: $insertion, onMove: onMove))
        .accessibilityLabel("Reorder " + title).help("Drag above or below another section")
    }
}
struct SectionDropDelegate: DropDelegate {
    let target: String
    let directionID: UUID
    let height: Double
    @Binding var dragging: String?
    @Binding var insertion: Bool?
    let onMove: (String, String, Bool) -> Void
    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [UTType.plainText]) }
    func dropUpdated(info: DropInfo) -> DropProposal? { insertion = info.location.y < height / 2; return DropProposal(operation: .move) }
    func dropExited(info: DropInfo) { insertion = nil }
    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else { return false }
        let before = info.location.y < height / 2
        insertion = nil; dragging = nil
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let value = object as? String, value.hasPrefix(directionID.uuidString + "|") else { return }
            DispatchQueue.main.async { onMove(String(value.dropFirst(37)), target, before) }
        }
        return true
    }
}
