import Foundation
import AppKit
import CoreText

enum StudioChecks {
    static func verify(_ condition: @autoclosure () -> Bool, _ message: String = "Assertion failed", line: Int = #line) throws {
        if !condition() { throw NSError(domain: "FontShelfCheck", code: line, userInfo: [NSLocalizedDescriptionKey: "\(message) (StudioChecks.swift:\(line))"]) }
    }
    static func integration(source: URL) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FontShelf-activation-check-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent(source.lastPathComponent)
        let manager = ActivationManager(journal: root.appendingPathComponent("activation.json"))
        defer { manager.clear(restore: false); CTFontManagerUnregisterFontsForURL(target as CFURL, .process, nil); try? FileManager.default.removeItem(at: root) }
        func check(_ condition: Bool, _ message: String) throws { if !condition { throw NSError(domain: "FontShelfCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) } }
        let watcher = FolderWatcher()
        var changes = 0
        watcher.configure(roots: [root.path]) { _ in changes += 1 }
        func wait(_ predicate: () -> Bool) -> Bool {
            let end = Date().addingTimeInterval(10)
            while !predicate() && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
            return predicate()
        }
        try check(wait { changes > 0 }, "Initial folder scan did not finish")
        let initial = changes
        try FileManager.default.copyItem(at: source, to: target)
        try check(wait { changes > initial }, "Watcher did not detect a new font")
        let count = FontCatalog.registerFolder(root.path)
        try check(count == 1 && CTFontManagerGetScopeForURL(target as CFURL) == .process, "Font did not register for preview")
        _ = try manager.activate(target)
        try check(manager.owns(target) && CTFontManagerGetScopeForURL(target as CFURL) == .session, "Session activation failed")
        let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(target as CFURL) as? [CTFontDescriptor])!.first!
        let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as! String
        let process = Process(); process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]); process.arguments = ["--font-available", name]
        try process.run(); process.waitUntilExit()
        try check(process.terminationStatus == 0, "Session font was not visible to a separate process")
        try manager.deactivate(target)
        try check(!manager.owns(target) && CTFontManagerGetScopeForURL(target as CFURL) == .process, "Deactivation did not restore preview scope")
        let prior = changes
        try FileManager.default.removeItem(at: target)
        try check(wait { changes > prior }, "Watcher did not detect deletion")
        FontCatalog.reconcileFolders([root.path])
        try check(FontCatalog.registeredFiles[target.path] == nil, "Removed font remained registered")
        withExtendedLifetime(watcher) {}
        print("PASS: live recursive watcher, original-file preview, temporary activation visible to a separate process, deactivation and removal reconciliation.")
    }
    static func run(catalog: [Family]) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FontShelf-studio-checks-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StudioStore(url: root.appendingPathComponent("spaces.json"))
        let space = store.addSpace("Client"), boardID = store.addBoard(space: space, fonts: ["Georgia", "Helvetica"])!
        var board = store.state.spaces[0].boards[0]
        try verify(board.id == boardID)
        var duplicate = board.directions[0].copy(name: "Direction B")
        duplicate.styles[TypeRole.body.rawValue]!.fontName = "Courier"
        duplicate.styles[TypeRole.body.rawValue]!.axes = [2003265652: 520]
        duplicate.styles[TypeRole.body.rawValue]!.features = ["liga": 0]
        duplicate.notes = "Saved design decision"
        duplicate.styles[TypeRole.body.rawValue]!.alignment = .right
        duplicate.styles[TypeRole.body.rawValue]!.kerning = false
        duplicate.styles[TypeRole.body.rawValue]!.lineHeight = 32
        duplicate.styles[TypeRole.body.rawValue]!.wordSpacing = 3
        duplicate.styles[TypeRole.body.rawValue]!.paragraphSpacing = 12
        duplicate.styles[TypeRole.body.rawValue]!.indent = 20
        duplicate.styles[TypeRole.body.rawValue]!.casing = .upper
        duplicate.styles[TypeRole.body.rawValue]!.underline = true
        duplicate.canvas = .custom
        duplicate.blocks = [.heading, .body, .caption]
        board.checkpoints = [DirectionCheckpoint(direction: duplicate)]
        board.directions.append(duplicate); board.selectedDirection = duplicate.id
        store.update(space: space, board: board)
        let restored = StudioStore(url: store.url)
        let restoredBoard = restored.state.spaces[0].boards[0]
        let reverseData = try JSONSerialization.data(withJSONObject: FigmaLayoutExporter.payload(board: board))
        let importedBoard = try FigmaLayoutImporter.board(data: reverseData, fonts: catalog.flatMap(\.faces))
        try verify(importedBoard.isValid && importedBoard.directions.count == board.directions.count, "Figma typeboard failed validation")
        let importedFirst = importedBoard.directions[0]
        try verify(importedFirst.canvas == .imported && importedFirst.importedLayout?.layers.filter { $0.style != nil }.count == CanvasPlan(direction: board.directions[0]).elements.filter { $0.text != nil }.count)
        try verify(importedFirst.importedLayout?.layers.first?.style?.fontName == "Helvetica", "Imported font mapping failed")
        let importedEncoded = try JSONEncoder().encode(importedBoard)
        let decodedImported = try JSONDecoder().decode(TypeBoard.self, from: importedEncoded)
        try verify(decodedImported == importedBoard, "Imported geometry/style persistence failed")
        try verify(restoredBoard.directions.count == 2 && restoredBoard.selectedDirection == duplicate.id)
        try verify(restoredBoard.directions[0].style(.body).fontName == "Helvetica")
        try verify(restoredBoard.directions[1] == duplicate, "Direction settings were lost on reload")
        try verify(restored.focusedSpace == space && restored.focusedBoard == boardID, "Selected workspace was lost on reload")
        try verify(restoredBoard.checkpoints?.first?.direction == duplicate, "Checkpoint settings were lost on reload")
        restored.undoManager.groupsByEvent = false
        var edited = restoredBoard
        edited.directions[1].hiddenSections = ["Custom layout:block-0"]
        restored.update(space: space, board: edited, action: "Remove Section")
        try verify(restored.undoManager.canUndo && restored.undoManager.undoActionName == "Remove Section")
        restored.undoManager.undo()
        try verify(restored.state.spaces[0].boards[0] == restoredBoard, "Undo did not restore the board")
        try verify(StudioStore(url: restored.url).state.spaces[0].boards[0] == restoredBoard, "Undo was not persisted")
        restored.undoManager.redo()
        try verify(restored.state.spaces[0].boards[0] == edited, "Redo did not restore the edit")
        restored.undoManager.removeAllActions()
        edited.selectedDirection = edited.directions[0].id
        restored.update(space: space, board: edited)
        try verify(!restored.undoManager.canUndo, "Direction navigation polluted edit history")
        let beforeTyping = edited
        edited.directions[0].styles[TypeRole.display.rawValue]!.size = 8
        restored.update(space: space, board: edited, action: "Change Size")
        edited.directions[0].styles[TypeRole.display.rawValue]!.size = 80
        restored.update(space: space, board: edited, action: "Change Size")
        restored.undoManager.undo()
        try verify(restored.state.spaces[0].boards[0] == beforeTyping, "Numeric typing was not coalesced")
        restored.undoManager.redo()
        try verify(restored.state.spaces[0].boards[0] == edited, "Coalesced redo lost the final value")
        restored.removeBoard(space: space, id: edited.id)
        try verify(restored.state.spaces[0].boards.isEmpty)
        restored.undoManager.undo()
        try verify(restored.state.spaces[0].boards.first == edited && restored.focusedBoard == edited.id, "Deleted typeboard was not recovered")
        restored.undoManager.redo()
        try verify(restored.state.spaces[0].boards.isEmpty, "Redo deletion did not remove the typeboard")
        let corruptURL = root.appendingPathComponent("corrupt.json"), corrupt = Data("broken".utf8)
        try corrupt.write(to: corruptURL)
        let broken = StudioStore(url: corruptURL)
        _ = broken.addSpace("Do not overwrite")
        try verify(broken.readBlocked && !broken.save())
        let unchanged = try Data(contentsOf: corruptURL); try verify(unchanged == corrupt)
        var invalid = duplicate; invalid.width = -1
        try verify(!invalid.isValid)
        var invalidText = duplicate; invalidText.styles[TypeRole.body.rawValue]!.lineHeight = -4
        try verify(!invalidText.isValid)
        let legacyStyle = Data(#"{"fontName":"Helvetica","size":18,"leading":1.35,"tracking":0,"axes":{},"features":{},"text":"Legacy document"}"#.utf8)
        let legacy = try JSONDecoder().decode(TypeStyle.self, from: legacyStyle)
        try verify(legacy.alignment == nil && legacy.lineHeight == nil, "Legacy typography failed to decode")
        let styled = duplicate.style(.body).attributed("One two\nThree", color: .black)
        try verify(styled.string == "ONE TWO\nTHREE")
        let paragraph = styled.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        try verify(paragraph.alignment == .right && paragraph.minimumLineHeight == 32 && paragraph.paragraphSpacing == 12 && paragraph.firstLineHeadIndent == 20)
        try verify(styled.attribute(.kern, at: 3, effectiveRange: nil) as? Double == 3)
        let parsedSearch = FontSearchQuery("Helvetica #\"Client Work/Approved\" #!fontshelf/italic")
        try verify(parsedSearch.text == "Helvetica" && parsedSearch.tokens.count == 2)
        let regular = catalog.flatMap(\.faces).first { $0.name == "Helvetica" }!
        try verify(parsedSearch.matches(regular, tags: ["Client Work/Approved"]))
        try verify(!FontSearchQuery("#!\"Client Work\"").matches(regular, tags: ["Client Work/Approved"]))
        try verify(FontSearchQuery("#fontshelf/regular #typeface/upright").matches(regular, tags: []))
        try verify(!FontSearchQuery("#fontshelf/italic #fontshelf/upright").matches(regular, tags: []))
        try verify(FontSearchQuery.token("Client Work", excluded: true) == "#!\"Client Work\"")
        try verify(FontSearchQuery.removing("#tag", from: "#tag #tagged") == "#tagged", "Removing a token changed a different token")
        if let emoji = catalog.flatMap(\.faces).first(where: { $0.name == "AppleColorEmoji" }) { try verify(emoji.facts.color && FontSearchQuery("#fontshelf/color").matches(emoji, tags: [])) }
        var query = TagQuery(included: ["Client", "Editorial"], excluded: ["Client/Archived"], matchAll: true)
        try verify(query.matches(["Client/Current", "Editorial"]))
        try verify(!query.matches(["Client/Archived", "Editorial"]))
        try verify(!query.matches(["Client/Current"]))
        query.matchAll = false; try verify(query.matches(["Editorial"]))
        try verify(!query.matches(["Clients"]))
        try verify(TagQuery.hierarchy(["Client/Brand/Approved"]) == ["Client", "Client/Brand", "Client/Brand/Approved"])
        let nested = root.appendingPathComponent("watched/nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let a = nested.appendingPathComponent("sample.ttf")
        try Data([1,2,3]).write(to: a)
        let first = FontFolderSnapshot.read([nested.deletingLastPathComponent().path])
        try verify(first.files.count == 1 && first.errors.isEmpty)
        try Data([1,2,3,4]).write(to: a)
        let second = FontFolderSnapshot.read([nested.deletingLastPathComponent().path])
        try verify(second.files != first.files, "Font replacement went undetected")
        try FileManager.default.moveItem(at: a, to: nested.appendingPathComponent("renamed.otf"))
        let renamed = FontFolderSnapshot.read([nested.deletingLastPathComponent().path])
        try verify(renamed.files.keys.first?.hasSuffix("renamed.otf") == true)
        try verify(!FontFolderSnapshot.contains("/fonts-other/a.ttf", root: "/fonts"))
        try verify(!FontFolderSnapshot.read([root.appendingPathComponent("missing").path]).errors.isEmpty)
        let font = CTFontCreateWithName("Helvetica" as CFString, 100, nil)
        let glyphs = GlyphCatalog.entries(font: font)
        let capitalA = glyphs.first { $0.scalar?.value == 65 }!
        try verify(capitalA.matches("U+0041") && capitalA.matches("LATIN CAPITAL LETTER A"))
        try verify(glyphs.count == CTFontGetGlyphCount(font) - 1)
        try verify(GlyphCatalog.svg(font: font, glyph: capitalA.glyph)?.contains("<path") == true)
        var plans = 0
        for kind in CanvasKind.allCases {
            for width in [390.0, 768, 960, 1200] {
                var d = TypeDirection(); d.canvas = kind; d.width = width
                let plan = CanvasPlan(direction: d)
                try verify(plan.size.height.isFinite && plan.size.width == width)
                try verify(plan.elements.allSatisfy { $0.rect.minX >= 0 && $0.rect.maxX <= width + 1 && $0.rect.minY >= 0 && $0.rect.maxY <= plan.size.height }, "Canvas clipped content")
                plans += 1
                if let first = plan.sections.first, let last = plan.sections.last, first.id != last.id {
                    d.reorder(first.id, target: last.id, before: false, visible: plan.sections.map(\.id))
                    let reordered = CanvasPlan(direction: d)
                    try verify(reordered.sections.last?.id == first.id && reordered.elements.count == plan.elements.count)
                    try verify(reordered.elements.allSatisfy { $0.rect.minY >= 0 && $0.rect.maxY <= reordered.size.height }, "Reorder clipped content")
                    d.hiddenSections = [last.id]
                    try verify(!CanvasPlan(direction: d).elements.contains { $0.sectionID == last.id })
                    d.hiddenSections = nil
                    try verify(CanvasPlan(direction: d).elements.count == plan.elements.count)
                }
            }
        }
        let figmaData = try JSONSerialization.data(withJSONObject: FigmaLayoutExporter.payload(board: board))
        let figma = try JSONSerialization.jsonObject(with: figmaData) as! [String: Any]
        try verify(figma["format"] as? String == "fontshelf-figma" && (figma["frames"] as? [[String: Any]])?.count == 2)
        let frames = figma["frames"] as! [[String: Any]]
        let bodyLayer = (frames[1]["elements"] as! [[String: Any]]).first { $0["role"] as? String == TypeRole.body.rawValue }!
        try verify(bodyLayer["alignment"] as? String == "RIGHT" && bodyLayer["lineHeight"] as? Double == 32)
        let library = Library(storageURL: root.appendingPathComponent("library-state/library.json")); library.acceptCatalog(catalog)
        let sample = catalog.flatMap(\.faces).first { $0.name == "Helvetica" }!
        let pdf = SpecimenExporter.data(faces: [sample], library: library, sample: "Hamburgefontsiv 0123456789")
        try verify(CGDataProvider(data: pdf as CFData).flatMap { CGPDFDocument($0) }?.numberOfPages == 1)
        let longPDF = SpecimenExporter.data(faces: [sample], library: library, sample: String(repeating: "Long preview text with complete words. ", count: 100))
        try verify((CGDataProvider(data: longPDF as CFData).flatMap { CGPDFDocument($0) }?.numberOfPages ?? 0) > 1, "Long specimens must paginate")
        library.saved.collections["Keep"] = [catalog[0].name]
        let backup = LibraryBackup(library: library.saved, pro: library.pro, spaces: store.state)
        try LibraryBackupTools.merge(backup, into: library)
        try verify(library.saved.collections["Keep"] == [catalog[0].name])
        try verify(library.studio.state.spaces[0].id != store.state.spaces[0].id)
        try verify(FileManager.default.fileExists(atPath: root.appendingPathComponent("Backups").path))
        print("PASS: typography and legacy decoding, section reorder/removal, Figma layout payload, search tokens, independent directions and relaunch persistence, corrupt workspace preservation, nested AND/OR/NOT tags, recursive folder changes, Unicode lookup/SVG, \(plans) responsive canvases, specimen PDF and backup merge.")
    }
}
