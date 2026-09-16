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
    @State private var renamingSpace = false
    @State private var confirmDelete = false
    @State private var deletingBoard: (space: UUID, board: TypeBoard)?
    var space: DesignSpace? { store.state.spaces.first { $0.id == spaceID } ?? store.state.spaces.first }
    var board: TypeBoard? { space?.boards.first { $0.id == boardID } ?? space?.boards.first }
    var body: some View {
        HStack(spacing: 0) {
        navigation.frame(width: 232).environment(\.shelfInsideGlass, true).modifier(ShelfSidebarGlass()).padding(12)
        VStack(spacing: 0) {
            if !store.error.isEmpty { Text(store.error).foregroundStyle(.orange).textSelection(.enabled).padding(.horizontal, 20) }
            if let space {
                HStack(spacing: 12) {
                    Text(space.displayName).font(.system(size: 22, weight: .semibold)).lineLimit(1).frame(minHeight: 30).help(space.displayName)
                    Spacer()
                    Button("New typeboard") { boardID = store.addBoard(space: space.id, fonts: library.compared.map { library.chosenFace($0).name }) }
                    Menu {
                        Button("Rename space…") { newName = space.displayName; renamingSpace = true; showNewSpace = true }
                        Button("Import Figma typeboard…") { importFigma() }
                        Button("Export space…") { exportSpace(space) }
                        Button("Import space…") { importSpace() }
                        Divider()
                        Button("Delete space…", role: .destructive) { confirmDelete = true }
                    } label: { Image(systemName: "ellipsis") }.shelfIconMenu().help("Space actions").accessibilityLabel("Space actions")
                }.padding(.horizontal, 18).padding(.vertical, 14).fixedSize(horizontal: false, vertical: true)
                Divider()
                if let board {
                    TypeBoardEditor(library: library, savedBoard: board, onSave: { store.update(space: space.id, board: $0, action: $1) }, onDelete: {
                        store.removeBoard(space: space.id, id: board.id); boardID = store.focusedBoard
                    }).id(board.id)
                } else {
                    VStack(spacing: 14) { Image(systemName: "rectangle.3.group").font(.system(size: 38)); Text("No typeboards").font(.title2); Button("Create typeboard") { boardID = store.addBoard(space: space.id) } }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.3.group").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text("Create a space").font(.title2)
                    Text("A space holds your project's typeboards. Each typeboard can contain several canvases to explore and compare.").foregroundStyle(.secondary)
                    HStack { Button("New space") { showNewSpace = true }; Button("Import space…") { importSpace() } }.disabled(store.readBlocked)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } }
        .onAppear { if let id = store.focusedSpace { spaceID = id }; if let id = store.focusedBoard { boardID = id } }
        .onChange(of: store.focusedSpace) { id in spaceID = id; boardID = store.focusedBoard }
        .onChange(of: store.focusedBoard) { id in spaceID = store.focusedSpace; boardID = id }
        .alert(renamingSpace ? "Rename space" : "New space", isPresented: $showNewSpace) {
            TextField("Project or client name", text: $newName)
            Button(renamingSpace ? "Rename" : "Create") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if renamingSpace, let index = store.state.spaces.firstIndex(where: { $0.id == space?.id }) { store.state.spaces[index].name = name.isEmpty ? "Untitled space" : name; store.save() }
                else { spaceID = store.addSpace(name); boardID = store.addBoard(space: spaceID!, fonts: library.compared.map { library.chosenFace($0).name }) }
                newName = ""; renamingSpace = false
            }
            Button("Cancel", role: .cancel) { newName = ""; renamingSpace = false }
        }
        .alert("Delete this space and its typeboards?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { if let space { store.state.spaces.removeAll { $0.id == space.id }; store.save(); spaceID = nil; boardID = nil } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete “\(deletingBoard?.board.name ?? "typeboard")”?", isPresented: Binding(get: { deletingBoard != nil }, set: { if !$0 { deletingBoard = nil } })) {
            Button("Delete", role: .destructive) { if let target = deletingBoard { store.removeBoard(space: target.space, id: target.board.id); if boardID == target.board.id { boardID = store.focusedBoard } }; deletingBoard = nil }
            Button("Cancel", role: .cancel) { deletingBoard = nil }
        } message: { Text("Its canvases will be removed from this space. You can undo this with ⌘Z.") }
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
                            Label(item.displayName, systemImage: "rectangle.3.group").fontWeight(.medium).frame(maxWidth: .infinity, alignment: .leading).padding(10).background(space?.id == item.id ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                        ForEach(item.boards) { child in
                            StudioBoardRow(name: child.name, selected: board?.id == child.id, onSelect: { spaceID = item.id; boardID = child.id; store.focusedSpace = item.id; store.focusedBoard = child.id; store.save() }, onDelete: { deletingBoard = (item.id, child) })
                        }
                    }
                }
            }
            Menu("Import…") { Button("Space…") { importSpace() }; Button("Figma typeboard JSON…") { importFigma() }; Button("Using a native .fig file…") { figFileHelp() } }.menuStyle(.borderlessButton).fixedSize().padding(.bottom, 12)
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
            store.state.spaces.append(space); store.focusedSpace = space.id; store.focusedBoard = nil; store.save(); spaceID = space.id; boardID = nil
        } catch { store.error = "Space could not be imported: " + error.localizedDescription }
    }
    func importFigma() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        panel.message = "In the FontShelf Figma bridge, export selected frames to FontShelf, then choose that JSON file. Native .fig files are not supported."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 20_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let imported = try FigmaLayoutImporter.board(data: Data(contentsOf: url), fonts: library.allFaces)
            let target = space?.id ?? store.addSpace("Figma imports")
            guard let index = store.state.spaces.firstIndex(where: { $0.id == target }) else { return }
            store.state.spaces[index].boards.append(imported); store.focusedSpace = target; store.focusedBoard = imported.id; store.save(); spaceID = target; boardID = imported.id
        } catch { store.error = "Figma layout could not be imported: " + error.localizedDescription }
    }
    func figFileHelp() {
        let alert = NSAlert(); alert.messageText = "Bring a .fig file into FontShelf"
        alert.informativeText = "Direct .fig decoding is not available yet. Import your .fig file in Figma's file browser, run the FontShelf Layout Importer plugin, select the frames you want and choose Export selected frames. Then import the saved JSON here.\n\nThis keeps supported text and shapes editable; review the bridge's notes for unsupported content."
        alert.addButton(withTitle: "OK"); alert.runModal()
    }
}

struct StudioBoardRow: View {
    let name: String
    let selected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) { HStack { Image(systemName: "rectangle.on.rectangle"); Text(name).lineLimit(2); Spacer(minLength: 0) }.contentShape(Rectangle()) }.buttonStyle(.plain)
            Button(action: onDelete) { Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle()) }.buttonStyle(.borderless).help("Delete " + name).accessibilityLabel("Delete " + name)
        }.font(.caption).padding(.leading, 16).padding(6).foregroundStyle(selected ? ShelfPalette.ink : Color.secondary)
            .background(selected ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 6)).contentShape(Rectangle())
            .contextMenu { Button("Delete typeboard…", role: .destructive, action: onDelete) }
    }
}

extension TypeDirection {
    var isValid: Bool {
        width.isFinite && (canvas == .imported ? (1...10000).contains(width) : (320...1600).contains(width)) && (importedLayout?.isValid ?? (canvas != .imported)) && (textOverrides.map { $0.count <= 5000 && $0.values.allSatisfy { $0.utf8.count <= 200000 } } ?? true) && TypeRole.allCases.allSatisfy { role in
            guard let s = styles[role.rawValue] else { return false }
            return s.size.isFinite && (8...160).contains(s.size) && s.leading.isFinite && (1...2.5).contains(s.leading) && s.tracking.isFinite && (-3...12).contains(s.tracking) && s.axes.values.allSatisfy(\.isFinite) && (s.lineHeight.map { $0.isFinite && (8...400).contains($0) } ?? true) && [s.paragraphSpacing, s.indent].allSatisfy { $0.map { $0.isFinite && (0...200).contains($0) } ?? true } && (s.wordSpacing.map { $0.isFinite && (-3...40).contains($0) } ?? true)
        }
    }
}

struct TypeBoardEditor: View {
    @ObservedObject var library: Library
    @State var board: TypeBoard
    let savedBoard: TypeBoard
    let onSave: (TypeBoard, String) -> Void
    let onDelete: () -> Void
    init(library: Library, savedBoard: TypeBoard, onSave: @escaping (TypeBoard, String) -> Void, onDelete: @escaping () -> Void) {
        self.library = library; self.savedBoard = savedBoard; self.onSave = onSave; self.onDelete = onDelete
        _board = State(initialValue: savedBoard)
    }
    @State private var role = TypeRole.display
    @State private var fontSearch = ""
    @State private var fontCollection = "All fonts"
    @State private var fontCategory = "All categories"
    @State private var showAllCanvases = false
    @State private var selectedTextID: String?
    @State private var compareID: UUID?
    @State private var zoom = 0.0
    @State private var showDelete = false
    @State private var status = ""
    @State private var showFontPicker = false
    @State private var draggedSection: String?
    @State private var selectedSection: String?
    @State private var abID: UUID?
    @State private var inspectorTab = "Typography"
    @FocusState private var fontSearchFocused: Bool
    var directionIndex: Int { board.directions.firstIndex { $0.id == board.selectedDirection } ?? 0 }
    var direction: TypeDirection { board.directions[directionIndex] }
    var importedLayerIndex: Int? { guard direction.canvas == .imported else { return nil }; return direction.importedLayout?.layers.firstIndex { $0.id == selectedSection && $0.style != nil } ?? direction.importedLayout?.layers.firstIndex { $0.style != nil } }
    var selectedText: CanvasElement? { guard let selectedTextID else { return nil }; return CanvasPlan(direction: direction).elements.first { $0.textID == selectedTextID } }
    var style: TypeStyle { if let index = importedLayerIndex, let style = direction.importedLayout?.layers[index].style { return style }; return selectedText?.style ?? direction.style(role) }
    var editingTitle: String { if let index = importedLayerIndex { return direction.importedLayout?.layers[index].name ?? "Text layer" }; return role.rawValue }
    func setStyle(_ style: TypeStyle) {
        if let index = importedLayerIndex { board.directions[directionIndex].importedLayout?.layers[index].style = style }
        else if let selectedTextID, let selectedText {
            var shared = style; shared.text = direction.style(role).text
            board.directions[directionIndex].styles[role.rawValue] = shared
            if style.text != selectedText.style?.text { var overrides = direction.textOverrides ?? [:]; overrides[selectedTextID] = style.text; board.directions[directionIndex].textOverrides = overrides }
        } else { board.directions[directionIndex].styles[role.rawValue] = style }
    }
    var faces: [Face] { StudioFontFilter.faces(library: library, collection: fontCollection, category: fontCategory, search: fontSearch) }
    var missingFonts: [String] { Set(direction.canvas == .imported ? direction.importedLayout?.layers.compactMap { $0.style?.fontName } ?? [] : direction.styles.values.map(\.fontName)).subtracting(Set(library.allFaces.map(\.name))).sorted() }
    func save(_ action: String = "Edit Typeboard") { onSave(board, action) }
    func directionBinding<T>(_ key: WritableKeyPath<TypeDirection, T>) -> Binding<T> { Binding(get: { direction[keyPath: key] }, set: { board.directions[directionIndex][keyPath: key] = $0; save() }) }
    func styleBinding<T>(_ key: WritableKeyPath<TypeStyle, T>) -> Binding<T> { Binding(get: { style[keyPath: key] }, set: { var updated = style; updated[keyPath: key] = $0; setStyle(updated); save(key == \TypeStyle.size ? "Change Size" : key == \TypeStyle.tracking ? "Change Letter Spacing" : key == \TypeStyle.text ? "Change Sample Text" : "Edit Typography") }) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField("Typeboard name", text: Binding(get: { board.name }, set: { board.name = $0; save() })).textFieldStyle(.plain).font(.headline).frame(minWidth: 110)
                Spacer(minLength: 12)
                Menu("Add canvas") {
                    Button("Blank canvas") { let canvas = TypeDirection(name: board.nextCanvasName); board.directions.append(canvas); board.selectedDirection = canvas.id; save("Add Canvas") }
                    Button("Duplicate current canvas") { let copy = direction.copy(name: board.nextCanvasName); board.directions.append(copy); board.selectedDirection = copy.id; save("Duplicate Canvas") }
                }.fixedSize()
                Menu("Export") {
                    Button("Preview PDF…") { exportPDF() }
                    Button("Editable Figma layout…") { exportFigma() }
                }.fixedSize()
                Menu {
                    Button("Save checkpoint") { var values = board.checkpoints ?? []; values.append(DirectionCheckpoint(direction: direction)); board.checkpoints = Array(values.suffix(50)); save(); status = "Checkpoint saved" }
                    Menu("Restore checkpoint as canvas") {
                        ForEach((board.checkpoints ?? []).reversed()) { checkpoint in Button(checkpoint.direction.name + " · " + checkpoint.date.formatted(date: .abbreviated, time: .shortened)) { let copy = checkpoint.direction.copy(name: checkpoint.direction.name + " restored"); board.directions.append(copy); board.selectedDirection = copy.id; save() } }
                    }.disabled((board.checkpoints ?? []).isEmpty)
                    Button("Add shortlist as candidates") { board.candidates = Array(Set(board.candidates + library.compared.map { library.chosenFace($0).name })).sorted(); save() }
                    Divider()
                    Button("Delete canvas", role: .destructive) { let id = direction.id; board.directions.removeAll { $0.id == id }; board.selectedDirection = board.directions.first?.id; compareID = nil; abID = nil; save("Delete Canvas") }.disabled(board.directions.count < 2)
                    Button("Delete typeboard…", role: .destructive) { showDelete = true }
                } label: { Image(systemName: "ellipsis") }.shelfIconMenu().help("Typeboard actions").accessibilityLabel("Typeboard actions")
            }.padding(14).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { ForEach(board.directions) { canvas in
                        Button { board.selectedDirection = canvas.id; save() } label: { Text(board.canvasName(canvas)).lineLimit(1).padding(.horizontal, 12).padding(.vertical, 7).background(canvas.id == direction.id ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7)) }.buttonStyle(.plain).help("Edit " + board.canvasName(canvas))
                    } }
                }
                Toggle("Show all canvases", isOn: $showAllCanvases).toggleStyle(.button).fixedSize().disabled(board.directions.count < 2).onChange(of: showAllCanvases) { enabled in if enabled { compareID = nil; abID = nil } }
            }.frame(height: 36).padding(.horizontal, 14).padding(.bottom, 10)
            HStack {
                ShelfDropdown(title: "Format", selection: directionBinding(\.canvas), options: CanvasKind.allCases.filter { $0 != .imported || direction.importedLayout != nil }.map { ($0.rawValue, $0) }).frame(minWidth: 115, idealWidth: 180, maxWidth: 210)
                if direction.canvas == .imported { Text("\(Int(direction.width)) px").font(.caption).foregroundStyle(.secondary) }
                else { ShelfDropdown(title: "Width", selection: directionBinding(\.width), options: [("Mobile · 390", 390.0), ("Tablet · 768", 768.0), ("Desktop · 1200", 1200.0), ("Canvas · 960", 960.0)], showsTitle: false).frame(width: 132) }
                Spacer()
                Menu {
                    Button("Single canvas") { compareID = nil; abID = nil; showAllCanvases = false }
                    Menu("Quick A/B") {
                        let candidates = board.directions.filter { $0.id != direction.id && $0.canvas == direction.canvas && $0.width == direction.width }
                        if candidates.isEmpty { Text("Duplicate a canvas to start"); Text("Use the same format and width") }
                        ForEach(candidates) { candidate in Button(board.canvasName(candidate)) { abID = candidate.id; compareID = nil; showAllCanvases = false } }
                    }
                    Menu("Side by side") {
                        ForEach(board.directions.filter { $0.id != direction.id }) { candidate in Button(board.canvasName(candidate)) { compareID = candidate.id; abID = nil; showAllCanvases = false } }
                    }.disabled(board.directions.count < 2)
                } label: { Label(abID != nil ? "A/B" : compareID != nil ? "Comparing" : "Compare", systemImage: "rectangle.split.2x1") }.fixedSize()
                if abID != nil { Button { swapAB() } label: { Image(systemName: "arrow.left.arrow.right") }.keyboardShortcut("\\", modifiers: [.command]).help("Swap A/B (⌘\\)").accessibilityLabel("Swap A/B") }
                Menu(zoom == 0 ? "Fit" : "\(Int(zoom * 100))%") { Button("Fit all visible canvases") { zoom = 0 }; ForEach([0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0], id: \.self) { value in Button("\(Int(value * 100))%") { zoom = value } } }.fixedSize().help("Pinch to zoom, or hold ⌘ while scrolling with a mouse. Scroll normally to pan.")
            }.padding(.horizontal, 14).padding(.bottom, 12).fixedSize(horizontal: false, vertical: true)
            Divider()
            HSplitView {
                inspector.frame(minWidth: 240, idealWidth: 310, maxWidth: 500).background(StudioSplitPosition())
                VStack(alignment: .leading, spacing: 0) {
                    if library.loading { ProgressView(library.families.isEmpty ? "Loading font library…" : "Checking watched font folders…").controlSize(.small).padding(10) }
                    else if !missingFonts.isEmpty { Label("Unavailable fonts: " + missingFonts.joined(separator: ", ") + ". Preview uses fallback.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).padding(12) }
                    GeometryReader { geometry in
                    let other = board.directions.first(where: { $0.id == compareID && $0.id != direction.id })
                    let visible = showAllCanvases ? board.directions : [direction] + (other.map { [$0] } ?? [])
                    let scale = zoom == 0 ? min(1, max(0.1, (geometry.size.width - 48 - Double(visible.count - 1) * 24) / visible.reduce(0) { $0 + $1.width })) : zoom
                    ScrollView([.horizontal, .vertical]) {
                        HStack(alignment: .top, spacing: 24) {
                            ForEach(visible) { item in canvas(item, scale: scale) }
                        }.padding(24).frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                    }.background(Color.black.opacity(0.09)).background(CanvasZoomInput { factor in zoom = CanvasZoomInput.clamped((zoom == 0 ? scale : zoom) * factor) })
                    }
                    HStack { Text(!library.studio.error.isEmpty ? "Changes could not be saved" : status.isEmpty ? "Saved" : status).lineLimit(2); Spacer(); if let partner = board.directions.first(where: { $0.id == abID }) { Text("A/B · " + partner.name).lineLimit(1) }; Text("\(Int(direction.width)) px · " + (zoom == 0 ? "Fit" : "\(Int(zoom * 100))%" )).monospacedDigit() }.font(.caption).foregroundStyle(.secondary).padding(10)
                }.frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }.alert("Delete this typeboard?", isPresented: $showDelete) { Button("Delete", role: .destructive, action: onDelete); Button("Cancel", role: .cancel) {} }
        .onChange(of: savedBoard) { value in if value != board { board = value } }
        .onChange(of: role) { _ in library.studio.endUndoCoalescing() }
        .onChange(of: selectedSection) { _ in library.studio.endUndoCoalescing() }
        .onChange(of: selectedTextID) { _ in library.studio.endUndoCoalescing() }
        .onChange(of: direction.id) { _ in selectedSection = nil; selectedTextID = nil; draggedSection = nil; if let other = board.directions.first(where: { $0.id == abID }), other.canvas != direction.canvas || other.width != direction.width { abID = nil } }
        .onChange(of: direction.canvas) { _ in abID = nil; selectedSection = nil; selectedTextID = nil }
        .onChange(of: direction.width) { _ in abID = nil }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FontShelfMenu"))) { event in if event.object as? String == "find" { inspectorTab = "Typography"; DispatchQueue.main.async { showFontPicker = true } } }
    }
    func swapAB() { guard let id = abID, board.directions.contains(where: { $0.id == id && $0.canvas == direction.canvas && $0.width == direction.width }) else { return }; abID = direction.id; board.selectedDirection = id; compareID = nil; save() }
    func moveSection(_ source: String, _ target: String, _ before: Bool) {
        let plan = CanvasPlan(direction: direction)
        if direction.canvas == .imported, var layout = direction.importedLayout, source != target, let index = layout.layers.firstIndex(where: { $0.id == source }) {
            let layer = layout.layers.remove(at: index)
            if let destination = layout.layers.firstIndex(where: { $0.id == target }) { layout.layers.insert(layer, at: destination + (before ? 0 : 1)); board.directions[directionIndex].importedLayout = layout; selectedSection = source; save("Reorder Layers") }; return
        }
        board.directions[directionIndex].reorder(source, target: target, before: before, visible: plan.sections.map(\.id)); selectedSection = source; save("Reorder Sections")
    }
    func moveLayer(_ id: String, _ dx: Double, _ dy: Double) {
        guard let index = direction.importedLayout?.layers.firstIndex(where: { $0.id == id }) else { return }
        board.directions[directionIndex].importedLayout!.layers[index].x = min(100000, max(0, direction.importedLayout!.layers[index].x + dx))
        board.directions[directionIndex].importedLayout!.layers[index].y = min(100000, max(0, direction.importedLayout!.layers[index].y + dy))
        save("Move Layer")
    }
    func canvas(_ direction: TypeDirection, scale: Double) -> some View {
        let zoom = scale
        let plan = CanvasPlan(direction: direction)
        return VStack(alignment: .leading, spacing: 10) {
            Button { board.selectedDirection = direction.id; save() } label: { HStack { Text(board.canvasName(direction)); if direction.id == self.direction.id { Text("Editing").foregroundStyle(Color.accentColor) } else { Text("Click to edit").foregroundStyle(.secondary) } } }.font(.caption).buttonStyle(.plain)
            CanvasPreview(plan: plan, zoom: zoom, directionID: direction.id == self.direction.id ? direction.id : nil, selectedSection: direction.id == self.direction.id ? selectedSection : nil, onSelect: { id in selectedSection = id; selectedTextID = nil }, onMove: moveSection, onTranslate: direction.canvas == .imported ? moveLayer : nil, onTextSelect: { element in selectedSection = element.sectionID; selectedTextID = element.textID; if let item = element.role { role = item }; inspectorTab = "Typography" })
                .frame(width: plan.size.width * zoom, height: plan.size.height * zoom).shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
    var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Canvas name", text: Binding(get: { board.canvasName(direction) }, set: { board.directions[directionIndex].name = $0; save() })).textFieldStyle(.roundedBorder)
                Picker("Inspector", selection: $inspectorTab) { Text("Typography").tag("Typography"); Text("Arrangement").tag("Arrangement") }.pickerStyle(.segmented).labelsHidden()
                if inspectorTab == "Arrangement" { layoutSections }
                else {
                if direction.canvas == .imported {
                    Text("IMPORTED TEXT LAYERS").font(.caption).foregroundStyle(.secondary)
                    ShelfDropdown(title: "Layer", selection: Binding(get: { importedLayerIndex.flatMap { direction.importedLayout?.layers[$0].id } ?? "" }, set: { selectedSection = $0 }), options: (direction.importedLayout?.layers.filter { $0.style != nil } ?? []).map { ($0.name, $0.id) }, showsTitle: false)
                    Text("Edit each text layer independently. Drag layers on the canvas to position them.").font(.caption).foregroundStyle(.secondary)
                } else {
                Text("TYPE ROLES").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                ForEach(TypeRole.allCases) { item in
                    Button { role = item; selectedTextID = nil; selectedSection = nil; fontSearch = "" } label: {
                        HStack { Text(item.rawValue).font(.caption).fontWeight(.medium); Spacer(); Text("\(Int(direction.style(item).size))").font(.caption).monospacedDigit().foregroundStyle(.secondary) }.padding(9).background(role == item ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                }
                }
                Divider()
                Text(editingTitle).font(.headline)
                if selectedTextID != nil && direction.canvas != .imported { Text("Editing the selected text. Font and spacing changes apply to its shared type role.").font(.caption).foregroundStyle(.secondary) }
                Button { showFontPicker = true } label: { HStack { VStack(alignment: .leading, spacing: 4) { Text("Font").font(.caption).foregroundStyle(.secondary); Text(style.fontName).lineLimit(2) }; Spacer(); Image(systemName: "magnifyingglass") }.padding(10).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    .popover(isPresented: $showFontPicker) { fontPicker }
                numeric("Size", value: styleBinding(\.size), range: direction.canvas == .imported ? 1...1000 : 8...160, unit: "px")
                numeric("Line height", value: Binding(get: { style.lineHeight ?? style.size * style.leading }, set: { var s = style; s.lineHeight = $0; setStyle(s); save("Change Line Height") }), range: direction.canvas == .imported ? 1...2000 : 8...400, unit: "px")
                Button("Auto line height") { var s = style; s.lineHeight = nil; setStyle(s); save() }.font(.caption)
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
                            ShelfDropdown(title: tag, selection: Binding(get: { style.features[tag] ?? -1 }, set: { var s = style; if $0 < 0 { s.features.removeValue(forKey: tag) } else { s.features[tag] = $0 }; setStyle(s); save() }), options: [("Default", -1), ("Off", 0), ("On", 1)] + (2...9).map { ("Alternate \($0)", $0) })
                        }
                    }
                }
                Text(selectedTextID == nil ? "Sample text" : "Selected text").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: styleBinding(\.text)).frame(height: 100).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.25)))
                }
                Divider()
                if let warnings = direction.importWarnings, !warnings.isEmpty { DisclosureGroup("Import notes (\(warnings.count))") { Text(warnings.joined(separator: "\n")).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) } }
                colorPicker("Text", key: \.ink); colorPicker("Background", key: \.paper); if direction.canvas != .imported { colorPicker("Accent", key: \.accent) }
                Text("Canvas notes").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: directionBinding(\.notes)).frame(height: 75)
            }.padding(14)
        }
    }
    func optionalStyleBinding<T>(_ key: WritableKeyPath<TypeStyle, T?>, default fallback: T) -> Binding<T> { Binding(get: { style[keyPath: key] ?? fallback }, set: { var s = style; s[keyPath: key] = $0; setStyle(s); save() }) }
    var fontPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Choose font · " + editingTitle).font(.headline); Spacer(); Button("Done") { showFontPicker = false } }
            TextField("Search fonts, styles or #tags", text: $fontSearch).textFieldStyle(.roundedBorder).focused($fontSearchFocused)
            HStack(spacing: 12) {
                ShelfDropdown(title: "Collection", selection: $fontCollection, options: [("All fonts", "All fonts"), ("Favorites", "Favorites")] + library.saved.collections.keys.sorted().map { ($0, "collection:" + $0) })
                ShelfDropdown(title: "Category", selection: $fontCategory, options: ["All categories"] .map { ($0, $0) } + Category.allCases.map { ($0.rawValue, $0.rawValue) })
            }
            HStack { Text("\(faces.count) styles").font(.caption).foregroundStyle(.secondary); Spacer(); if fontCollection != "All fonts" || fontCategory != "All categories" || !fontSearch.isEmpty { Button("Clear filters") { fontCollection = "All fonts"; fontCategory = "All categories"; fontSearch = "" }.font(.caption) } }
            if !board.candidates.isEmpty {
                Menu("Pairing candidates (\(board.candidates.count))") {
                    ForEach(board.candidates, id: \.self) { name in Button(name) { chooseFont(name) } }
                }
            }
            if library.loading && faces.isEmpty { ProgressView("Loading font library…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if faces.isEmpty { Text("No fonts match these filters. Choose another collection or category, or clear the filters.").foregroundStyle(.secondary).padding(20).frame(maxWidth: .infinity) }
                    ForEach(faces) { face in
                        Button { chooseFont(face.name) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(face.originalFamily + " · " + face.style).font(.caption); Spacer(); if style.fontName == face.name { Image(systemName: "checkmark") } }
                                FontPreview(text: style.text.isEmpty ? "Aa Bb Cc 0123456789" : String(style.text.prefix(90)), name: face.name, size: 27, wraps: true).frame(minHeight: 38).allowsHitTesting(false)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(style.fontName == face.name ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(maxHeight: .infinity)
        }.padding(18).frame(width: 580, height: 540).background(Color(nsColor: .windowBackgroundColor)).onAppear { fontSearchFocused = true }.onExitCommand { showFontPicker = false }
    }
    var layoutSections: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("ARRANGEMENT").font(.caption).foregroundStyle(.secondary); Spacer(); Menu { ForEach(TypeRole.allCases) { item in Button(item.rawValue) {
                if direction.canvas == .imported { let layer = ImportedLayer(name: item.rawValue, x: 24, y: 24, width: max(1, direction.width - 48), height: item.size * 2, color: direction.ink, style: direction.style(item)); board.directions[directionIndex].importedLayout?.layers.append(layer); selectedSection = layer.id }
                else { board.directions[directionIndex].addedBlocks = (direction.addedBlocks ?? []) + [LayoutBlock(role: item)] }; save("Add Section")
            } }; if !(direction.hiddenSections ?? []).isEmpty { Button("Restore removed sections") { board.directions[directionIndex].hiddenSections = nil; save() } } } label: { Image(systemName: "plus") }.shelfIconMenu().help("Add section").accessibilityLabel("Add section") }
            let plan = CanvasPlan(direction: direction)
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    CanvasPreview(plan: CanvasPlan(arrangement: plan.sections, width: geometry.size.width), directionID: direction.id, selectedSection: selectedSection, onSelect: { selectedSection = $0 }, onMove: moveSection)
                    VStack(spacing: 0) {
                        ForEach(plan.sections) { section in
                            Button { var hidden = direction.hiddenSections ?? []; hidden.insert(section.id); board.directions[directionIndex].hiddenSections = hidden; save("Remove Section") } label: { Image(systemName: "minus").frame(width: 28, height: 42) }.buttonStyle(.borderless).help("Remove " + section.title).accessibilityLabel("Remove " + section.title)
                        }
                    }
                }
            }.frame(height: Double(plan.sections.count) * 42)
            Text(direction.canvas == .imported ? "Drag here to change layer stacking order; drag on the canvas to move a layer." : "Drag sections here or on the canvas.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    func chooseFont(_ name: String) { var s = style; s.fontName = name; s.axes = library.pro.axes[name] ?? [:]; s.features = library.pro.features[name] ?? [:]; setStyle(s); save("Change Font") }
    func numeric(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { HStack { Text(title); Spacer(); TextField(title, value: Binding(get: { value.wrappedValue }, set: { if $0.isFinite { value.wrappedValue = min(range.upperBound, max(range.lowerBound, $0)) } }), format: .number.precision(.fractionLength(0...2))).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width: 65).onSubmit { NSApp.keyWindow?.makeFirstResponder(nil) }; Text(unit).foregroundStyle(.secondary) }.font(.caption); Slider(value: value, in: range) }
    }
    var axesEditor: some View {
        let axes = CTFontCopyVariationAxes(CTFontCreateWithName(style.fontName as CFString, 24, nil)) as? [[String: Any]] ?? []
        return ForEach(Array(axes.enumerated()), id: \.offset) { _, axis in
            if let id = axis[kCTFontVariationAxisIdentifierKey as String] as? Int, let low = axis[kCTFontVariationAxisMinimumValueKey as String] as? Double, let high = axis[kCTFontVariationAxisMaximumValueKey as String] as? Double, let initial = axis[kCTFontVariationAxisDefaultValueKey as String] as? Double, high > low {
                numeric(axis[kCTFontVariationAxisNameKey as String] as? String ?? "Axis", value: Binding(get: { style.axes[id] ?? initial }, set: { var s = style; s.axes[id] = $0; setStyle(s); save() }), range: low...high, unit: "")
            }
        }
    }
    func colorPicker(_ title: String, key: WritableKeyPath<TypeDirection, String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(nsColor: NSColor(hex: key == \TypeDirection.ink ? importedLayerIndex.flatMap { direction.importedLayout?.layers[$0].color } ?? direction.ink : direction[keyPath: key])) }, set: { if key == \TypeDirection.ink, let index = importedLayerIndex { board.directions[directionIndex].importedLayout?.layers[index].color = NSColor($0).rgbHex } else { board.directions[directionIndex][keyPath: key] = NSColor($0).rgbHex }; save() }), supportsOpacity: false)
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

/// Preserve the designer's inspector width across boards, without replacing native split-view behavior.
struct StudioSplitPosition: NSViewRepresentable {
    final class Anchor: NSView {
        private var observation: NSObjectProtocol?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.observation == nil else { return }
                var ancestor = self.superview
                while let view = ancestor {
                    if let split = view as? NSSplitView {
                        let saved = UserDefaults.standard.double(forKey: "studioInspectorWidth")
                        split.setPosition(min(500, max(240, saved == 0 ? 310 : saved)), ofDividerAt: 0)
                        self.observation = NotificationCenter.default.addObserver(forName: NSSplitView.didResizeSubviewsNotification, object: split, queue: .main) { [weak split] _ in
                            if let width = split?.subviews.first?.frame.width, width >= 240 { UserDefaults.standard.set(min(500, width), forKey: "studioInspectorWidth") }
                        }
                        return
                    }
                    ancestor = view.superview
                }
            }
        }
        deinit { if let observation { NotificationCenter.default.removeObserver(observation) } }
    }
    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ view: Anchor, context: Context) {}
}

struct CanvasElement {
    var rect: CGRect
    var text: NSAttributedString?
    var color: NSColor?
    var radius: Double = 0
    var sectionID = ""
    var style: TypeStyle?
    var role: TypeRole?
    var textID: String?
}
struct CanvasSection: Identifiable { var id: String; var title: String; var rect: CGRect }
struct CanvasPlan {
    var elements: [CanvasElement] = []
    var sections: [CanvasSection] = []
    var size: CGSize = .zero
    var paper: NSColor
    init(arrangement: [CanvasSection], width: Double) {
        paper = .clear; size = CGSize(width: width, height: Double(arrangement.count) * 42)
        for (index, section) in arrangement.enumerated() {
            let y = Double(index) * 42
            sections.append(CanvasSection(id: section.id, title: section.title, rect: CGRect(x: 0, y: y, width: width, height: 42)))
            let text = NSAttributedString(string: "≡   " + section.title, attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor])
            elements.append(CanvasElement(rect: CGRect(x: 10, y: y + 13, width: max(1, width - 42), height: 20), text: text, sectionID: section.id))
        }
    }
    init(direction d: TypeDirection) {
        paper = NSColor(hex: d.paper)
        if d.canvas == .imported {
            size = CGSize(width: d.width, height: d.importedLayout?.height ?? 480)
            for layer in d.importedLayout?.layers ?? [] where !(d.hiddenSections ?? []).contains(layer.id) {
                let color = NSColor(hex: layer.color).withAlphaComponent(layer.opacity)
                var rect = layer.rect
                if let style = layer.style {
                    let text = style.attributed(color: color)
                    rect.size.height = max(rect.height, ceil(text.boundingRect(with: CGSize(width: max(1, rect.width), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height) + 4)
                    elements.append(CanvasElement(rect: rect, text: text, sectionID: layer.id, style: style))
                } else { elements.append(CanvasElement(rect: rect, color: color, radius: layer.radius, sectionID: layer.id)) }
                sections.append(CanvasSection(id: layer.id, title: layer.name, rect: rect))
                size.height = max(size.height, rect.maxY)
            }
            return
        }
        let w = min(1600, max(320, d.width)), margin = w < 500 ? 24.0 : 56.0, usable = w - margin * 2
        let ink = NSColor(hex: d.ink), accent = NSColor(hex: d.accent)
        var y = margin
        var currentID = "", currentTitle = "", sectionStart = margin, elementStart = 0
        var textCounts: [TypeRole: Int] = [:]
        func finishSection() {
            guard !currentID.isEmpty else { return }
            for i in elementStart..<elements.count { elements[i].sectionID = currentID }
            sections.append(CanvasSection(id: currentID, title: currentTitle, rect: CGRect(x: 0, y: sectionStart, width: w, height: max(24, y - sectionStart))))
        }
        func section(_ id: String, _ title: String) {
            finishSection(); currentID = d.canvas.rawValue + ":" + id; currentTitle = title; sectionStart = y; elementStart = elements.count; textCounts = [:]
        }
        func text(_ role: TypeRole, _ override: String? = nil, x: Double? = nil, at: Double? = nil, width: Double? = nil, color: NSColor? = nil) -> Double {
            let occurrence = textCounts[role, default: 0]; textCounts[role] = occurrence + 1
            let textID = currentID + "|" + role.rawValue + "|" + String(occurrence)
            var style = d.style(role); style.text = d.textOverrides?[textID] ?? override ?? style.text
            let value = style.attributed(color: color ?? ink)
            let available = max(1, width ?? usable)
            let height = ceil(value.boundingRect(with: NSSize(width: available, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading]).height) + 4
            elements.append(CanvasElement(rect: CGRect(x: x ?? margin, y: at ?? y, width: available, height: height), text: value, style: style, role: role, textID: textID))
            if at == nil { y += height + 18 }
            return height
        }
        func rule() { elements.append(CanvasElement(rect: CGRect(x: margin, y: y, width: usable, height: 1), color: ink.withAlphaComponent(0.18))); y += 26 }
        func button() { let start = y; let h = text(.label, x: margin + 18, at: start + 13, width: usable - 36); elements.insert(CanvasElement(rect: CGRect(x: margin, y: start, width: usable, height: h + 26), color: accent, radius: 7), at: elements.count - 1); y = start + h + 50 }
        switch d.canvas {
        case .imported: break
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
final class CanvasNativeView: NSView {
    var plan: CanvasPlan
    var zoom = 1.0
    var directionID: UUID?
    var selectedSection: String?
    var onSelect: ((String) -> Void)?
    var onMove: ((String, String, Bool) -> Void)?
    var onTranslate: ((String, Double, Double) -> Void)?
    var onTextSelect: ((CanvasElement) -> Void)?
    private var insertionY: Double?
    private var translation = NSPoint.zero
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(plan: CanvasPlan) { self.plan = plan; super.init(frame: CGRect(origin: .zero, size: plan.size)); registerForDraggedTypes([.string]) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func resetCursorRects() { if directionID != nil { addCursorRect(bounds, cursor: .openHand) } }
    func section(at point: NSPoint) -> CanvasSection? { let local = NSPoint(x: point.x / max(0.01, zoom), y: point.y / max(0.01, zoom)); return plan.sections.last { $0.rect.contains(local) } }
    override func mouseDown(with event: NSEvent) {
        guard directionID != nil, let window else { return }
        window.makeFirstResponder(self)
        let origin = convert(event.locationInWindow, from: nil)
        guard let item = section(at: origin) else { return }
        selectedSection = item.id; needsDisplay = true
        var moved = false
        // Keep selection changes out of SwiftUI until tracking ends: changing the inspector
        // during mouseDown can rebuild the hosted canvas before AppKit delivers the drag.
        defer { insertionY = nil; translation = .zero; needsDisplay = true }
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .keyDown], until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            if next.type == .keyDown { if next.keyCode == 53 { return }; continue }
            let point = convert(next.locationInWindow, from: nil)
            moved = moved || hypot(point.x - origin.x, point.y - origin.y) > 4
            let target = dropTarget(at: point)
            if next.type == .leftMouseUp {
                let local = NSPoint(x: origin.x / zoom, y: origin.y / zoom)
                if !moved, let text = plan.text(at: local), let onTextSelect { onTextSelect(text) }
                else { onSelect?(item.id) }
                if moved, bounds.contains(point) { if let onTranslate { onTranslate(item.id, (point.x - origin.x) / zoom, (point.y - origin.y) / zoom) } else if let target { onMove?(item.id, target.id, point.y / zoom < target.rect.midY) } }
                return
            }
            if moved {
                _ = autoscroll(with: next)
                if onTranslate != nil { translation = NSPoint(x: (point.x - origin.x) / zoom, y: (point.y - origin.y) / zoom) }
                else { insertionY = target.map { point.y / zoom < $0.rect.midY ? $0.rect.minY : $0.rect.maxY } }
                needsDisplay = true; displayIfNeeded()
            }
        }
    }
    private func dropTarget(at point: NSPoint) -> CanvasSection? {
        if let hit = section(at: point) { return hit }
        return point.y / max(0.01, zoom) < (plan.sections.first?.rect.minY ?? 0) ? plan.sections.first : plan.sections.last
    }
    private func source(_ sender: NSDraggingInfo) -> String? {
        guard let directionID, let value = sender.draggingPasteboard.string(forType: .string), value.hasPrefix(directionID.uuidString + "|") else { return nil }
        let id = String(value.dropFirst(37)); return plan.sections.contains { $0.id == id } ? id : nil
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard source(sender) != nil else { return [] }
        let point = convert(sender.draggingLocation, from: nil)
        guard let target = dropTarget(at: point) else { insertionY = nil; needsDisplay = true; return [] }
        insertionY = point.y / zoom < target.rect.midY ? target.rect.minY : target.rect.maxY; needsDisplay = true; return .move
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { insertionY = nil; needsDisplay = true }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { source(sender) != nil }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { insertionY = nil; needsDisplay = true }
        guard let source = source(sender) else { return false }
        let point = convert(sender.draggingLocation, from: nil)
        guard let target = dropTarget(at: point) else { return false }
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
            NSColor.controlAccentColor.withAlphaComponent(0.7).setStroke(); let border = NSBezierPath(rect: selected.rect.offsetBy(dx: translation.x, dy: translation.y).insetBy(dx: 1 / zoom, dy: 0)); border.lineWidth = 1 / zoom; border.stroke()
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
    var onTranslate: ((String, Double, Double) -> Void)?
    var onTextSelect: ((CanvasElement) -> Void)?
    func makeNSView(context: Context) -> CanvasNativeView { CanvasNativeView(plan: plan) }
    func updateNSView(_ view: CanvasNativeView, context: Context) { view.plan = plan; view.zoom = zoom; view.directionID = directionID; view.selectedSection = selectedSection; view.onSelect = onSelect; view.onMove = onMove; view.onTranslate = onTranslate; view.onTextSelect = onTextSelect; view.frame.size = CGSize(width: plan.size.width * zoom, height: plan.size.height * zoom); view.setAccessibilityElement(true); view.setAccessibilityLabel(plan.elements.compactMap { $0.text?.string }.joined(separator: ". ")); view.needsDisplay = true }
}

extension CanvasPlan {
    func text(at point: NSPoint) -> CanvasElement? { elements.last { $0.text != nil && $0.rect.contains(point) } }
}

enum StudioFontFilter {
    static func faces(library: Library, collection: String, category: String, search: String) -> [Face] {
        let query = FontSearchQuery(search)
        return library.families.filter { family in
            (collection == "All fonts" || library.matchesSection(family, collection)) && (category == "All categories" || library.category(family).rawValue == category)
        }.flatMap(\.faces).filter { face in
            (query.text.isEmpty || face.name.localizedCaseInsensitiveContains(query.text) || face.originalFamily.localizedCaseInsensitiveContains(query.text) || face.style.localizedCaseInsensitiveContains(query.text)) && query.matches(face, tags: library.pro.tags[face.name] ?? [])
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// Limit gesture interception to the visible canvas viewport; ordinary scrolling still pans.
struct CanvasZoomInput: NSViewRepresentable {
    var onZoom: (Double) -> Void
    static func clamped(_ value: Double) -> Double { value.isFinite ? min(4, max(0.1, value)) : 1 }
    final class Anchor: NSView {
        var onZoom: ((Double) -> Void)?
        var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.magnify, .scrollWheel]) { [weak self] event in
                guard let self, !self.isHiddenOrHasHiddenAncestor, event.window === self.window, self.bounds.contains(self.convert(event.locationInWindow, from: nil)) else { return event }
                if event.type == .magnify { self.onZoom?(max(0.1, 1 + event.magnification)); return nil }
                if event.modifierFlags.contains(.command) { self.onZoom?(exp(Double(event.scrollingDeltaY) * 0.01)); return nil }
                return event
            }
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
    func makeNSView(context: Context) -> Anchor { let view = Anchor(); view.onZoom = onZoom; return view }
    func updateNSView(_ view: Anchor, context: Context) { view.onZoom = onZoom }
    static func dismantleNSView(_ view: Anchor, coordinator: ()) { if let monitor = view.monitor { NSEvent.removeMonitor(monitor); view.monitor = nil } }
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
