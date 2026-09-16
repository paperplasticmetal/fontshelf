import SwiftUI
import AppKit
import CoreText
import UniformTypeIdentifiers

struct LibraryBackup: Codable {
    var version = 1
    var library: SavedLibrary
    var pro: ProState
    var spaces: StudioState
}
enum LibraryBackupTools {
    static func preserve(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let directory = url.deletingLastPathComponent().appendingPathComponent("Backups")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let day = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let target = directory.appendingPathComponent(String(day) + "-" + url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: url, to: target) }
    }
    static func export(_ library: Library) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "FontShelf-library.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let backup = LibraryBackup(library: library.saved, pro: library.pro, spaces: library.studio.state)
            try JSONEncoder().encode(backup).write(to: url, options: .atomic)
            library.message = "Library backup exported. Font files are not included."
        } catch { library.message = error.localizedDescription }
    }
    static func merge(_ backup: LibraryBackup, into library: Library) throws {
        guard backup.version == 1, backup.spaces.version == 1, !library.librarySaveBlocked, !library.proSaveBlocked, !library.studio.readBlocked, backup.spaces.spaces.allSatisfy({ $0.boards.allSatisfy(\.isValid) }) else { throw CocoaError(.fileReadCorruptFile) }
        library.saved.favorites.formUnion(backup.library.favorites)
        for (key, values) in backup.library.collections { library.saved.collections[key, default: []].formUnion(values) }
        library.saved.overrides.merge(backup.library.overrides) { existing, _ in existing }
        library.pro.familyOverrides.merge(backup.pro.familyOverrides) { existing, _ in existing }
        library.pro.mainPreviews.merge(backup.pro.mainPreviews) { existing, _ in existing }
        library.pro.notes.merge(backup.pro.notes) { existing, _ in existing }
        library.pro.axes.merge(backup.pro.axes) { existing, _ in existing }
        library.pro.features.merge(backup.pro.features) { existing, _ in existing }
        for (key, tags) in backup.pro.tags { library.pro.tags[key, default: []].formUnion(tags) }
        for var space in backup.spaces.spaces {
            space.id = UUID(); space.name += " (imported)"
            library.studio.state.spaces.append(space)
        }
        guard library.save(), library.savePro() else { throw NSError(domain: "FontShelf", code: 1, userInfo: [NSLocalizedDescriptionKey: "Import may be partially saved. " + library.message]) }
        guard library.studio.save() else { throw NSError(domain: "FontShelf", code: 1, userInfo: [NSLocalizedDescriptionKey: "Import may be partially saved. " + library.studio.error]) }
        library.regroup()
    }
    static func restore(_ library: Library) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.message = "Merge a FontShelf backup. Existing settings are kept; spaces are imported as copies."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try merge(JSONDecoder().decode(LibraryBackup.self, from: Data(contentsOf: url)), into: library)
            library.message = "Backup merged. Add font folders separately to grant access on this Mac."
        } catch { library.message = "Backup could not be imported: " + error.localizedDescription }
    }
}
struct MetadataTable: View {
    @ObservedObject var library: Library
    var body: some View {
        Table(library.filtered.flatMap(\.faces)) {
            TableColumn("Family") { Text($0.originalFamily) }
            TableColumn("Style") { Text($0.style) }
            TableColumn("Foundry") { Text($0.facts.foundry) }
            TableColumn("Weight") { Text(String($0.facts.weight)) }
            TableColumn("Glyphs") { Text(String($0.facts.glyphCount)) }
            TableColumn("Format") { Text($0.url?.pathExtension.uppercased() ?? "—") }
            TableColumn("File") { face in
                Button(face.url?.lastPathComponent ?? "Unavailable") { if let family = library.families.first(where: { $0.faces.contains { $0.name == face.name } }) { library.detail = family } }.buttonStyle(.plain).help(face.url?.path ?? "")
            }
        }
    }
}
enum SpecimenExporter {
    static func data(faces: [Face], library: Library, sample: String) -> Data {
        let result = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: result as CFMutableData), let context = CGContext(consumer: consumer, mediaBox: &page, nil) else { return Data() }
        for face in faces {
            var cursor = 690.0
            func beginPage() {
                context.beginPDFPage(nil); context.setFillColor(NSColor.white.cgColor); context.fill(page)
                let title = NSAttributedString(string: face.originalFamily + " · " + face.style, attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: NSColor.black])
                context.textPosition = CGPoint(x: 44, y: 746); CTLineDraw(CTLineCreateWithAttributedString(title), context)
                let footer = NSAttributedString(string: "FontShelf · " + face.name, attributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.darkGray])
                context.textPosition = CGPoint(x: 44, y: 26); CTLineDraw(CTLineCreateWithAttributedString(footer), context)
                cursor = 708
            }
            beginPage()
            for size in [48.0, 36, 24, 18, 12] {
                if cursor < size * 1.5 + 60 { context.endPDFPage(); beginPage() }
                let text = sample.isEmpty ? face.originalFamily : sample
                let name = face.name, axes = library.pro.axes[name] ?? [:], features = library.pro.features[name] ?? [:]
                let font = OpenType.font(name: name, size: size, axes: axes, features: features)
                let value = NSAttributedString(string: text, attributes: [.font: font as NSFont, .foregroundColor: NSColor.black])
                let framesetter = CTFramesetterCreateWithAttributedString(value)
                var offset = 0
                while offset < value.length {
                    let available = cursor - 48
                    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), CGPath(rect: CGRect(x: 44, y: 48, width: 524, height: available), transform: nil), nil)
                    let range = CTFrameGetVisibleStringRange(frame)
                    if range.length == 0 { context.endPDFPage(); beginPage(); continue }
                    CTFrameDraw(frame, context)
                    offset += range.length
                    if offset < value.length { context.endPDFPage(); beginPage() }
                    else {
                        let measured = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, range, nil, CGSize(width: 524, height: CGFloat.greatestFiniteMagnitude), nil)
                        cursor -= ceil(measured.height) + 24
                    }
                }
            }
            context.endPDFPage()
        }
        context.closePDF(); return result as Data
    }
    static func export(faces: [Face], library: Library, sample: String) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = "FontShelf specimens.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data(faces: faces, library: library, sample: sample).write(to: url, options: .atomic); library.message = "Specimen PDF exported." } catch { library.message = error.localizedDescription }
    }
}

struct WaterfallView: View {
    let face: Face
    let text: String
    let axes: [Int: Double]
    let features: [String: Int]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach([10.0, 12, 14, 18, 24, 36, 48, 72, 96], id: \.self) { size in
                    VStack(alignment: .leading, spacing: 7) { Text("\(Int(size)) pt").font(.caption).foregroundStyle(.secondary); FontPreview(text: text, name: face.name, size: size, wraps: true, variations: axes, features: features) }
                    Divider()
                }
            }.padding(20)
        }
    }
}
