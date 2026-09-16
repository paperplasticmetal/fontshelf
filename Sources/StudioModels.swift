import SwiftUI
import AppKit
import CoreText

enum CanvasKind: String, Codable, CaseIterable { case website = "Website", product = "Product UI", editorial = "Editorial", poster = "Poster", specimen = "Type system", custom = "Custom layout" }
enum TypeRole: String, Codable, CaseIterable, Identifiable {
    case display = "Display", heading = "Heading", subheading = "Subheading", body = "Body", label = "UI label", caption = "Caption", mono = "Monospace"
    var id: String { rawValue }
    var size: Double { switch self { case .display: return 64; case .heading: return 36; case .subheading: return 24; case .body: return 18; case .label: return 14; case .caption: return 12; case .mono: return 14 } }
    var sample: String { switch self { case .display: return "A new perspective."; case .heading: return "Designed for everyday life"; case .subheading: return "Details make the difference"; case .body: return "Good design begins with a clear idea. Explore a collection of considered objects, useful tools, and stories about the way we live."; case .label: return "Explore collection"; case .caption: return "STUDIO JOURNAL · SEPTEMBER 2026"; case .mono: return "0123456789  /  Aa Bb Cc  /  { type: true }" } }
}
struct TypeStyle: Codable, Equatable {
    var fontName: String
    var size: Double
    var leading: Double = 1.35
    var tracking: Double = 0
    var axes: [Int: Double] = [:]
    var features: [String: Int] = [:]
    var text: String
    var alignment: TextAlignmentOption?
    var kerning: Bool?
    var lineHeight: Double?
    var paragraphSpacing: Double?
    var wordSpacing: Double?
    var indent: Double?
    var casing: TextCaseOption?
    var underline: Bool?
    var strikethrough: Bool?
    var font: CTFont { var values = features; if let kerning { values["kern"] = kerning ? 1 : 0 }; return OpenType.font(name: fontName, size: size, axes: axes, features: values) }
    func attributed(_ source: String? = nil, color: NSColor) -> NSAttributedString {
        let raw = source ?? text
        let value = casing == .upper ? raw.uppercased() : casing == .lower ? raw.lowercased() : raw
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = (alignment ?? .left).native
        paragraph.minimumLineHeight = lineHeight ?? size * leading
        paragraph.maximumLineHeight = paragraph.minimumLineHeight
        paragraph.paragraphSpacing = paragraphSpacing ?? 0
        paragraph.firstLineHeadIndent = indent ?? 0
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [.font: font as NSFont, .foregroundColor: color, .paragraphStyle: paragraph]
        if tracking != 0 || kerning == false { attributes[.kern] = tracking }
        if underline == true { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if strikethrough == true { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        let result = NSMutableAttributedString(string: value, attributes: attributes)
        if let spacing = wordSpacing, spacing != 0 {
            let string = value as NSString
            for i in 0..<string.length where string.character(at: i) == 32 { result.addAttribute(.kern, value: tracking + spacing, range: NSRange(location: i, length: 1)) }
        }
        return result
    }
}
enum TextAlignmentOption: String, Codable, CaseIterable { case left = "Left", center = "Center", right = "Right", justified = "Justified"
    var native: NSTextAlignment { switch self { case .left: return .left; case .center: return .center; case .right: return .right; case .justified: return .justified } }
}
enum TextCaseOption: String, Codable, CaseIterable { case original = "Original", upper = "UPPERCASE", lower = "lowercase" }
struct LayoutBlock: Codable, Identifiable, Equatable { var id = UUID().uuidString; var role: TypeRole }
struct TypeDirection: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Direction A"
    var canvas: CanvasKind = .website
    var width: Double = 960
    var ink = "222222"
    var paper = "F5F2EA"
    var accent = "C59937"
    var styles: [String: TypeStyle] = [:]
    var notes = ""
    var blocks: [TypeRole]?
    var addedBlocks: [LayoutBlock]?
    var sectionOrder: [String]?
    var hiddenSections: Set<String>?
    init(name: String = "Direction A", fonts: [String] = []) {
        self.name = name
        for role in TypeRole.allCases {
            let fallback = role == .mono ? "Menlo-Regular" : role == .display || role == .heading ? "Georgia" : "Helvetica"
            let index = role == .display || role == .heading ? 0 : 1
            styles[role.rawValue] = TypeStyle(fontName: fonts.isEmpty ? fallback : fonts[min(index, fonts.count - 1)], size: role.size, text: role.sample)
        }
    }
    func style(_ role: TypeRole) -> TypeStyle { styles[role.rawValue] ?? TypeStyle(fontName: "Helvetica", size: role.size, text: role.sample) }
    func copy(name: String? = nil) -> TypeDirection { var value = self; value.id = UUID(); value.name = name ?? self.name + " copy"; return value }
    mutating func reorder(_ source: String, target: String, before: Bool, visible: [String]) {
        guard source != target, visible.contains(source), visible.contains(target) else { return }
        var order = visible.filter { $0 != source }
        guard let index = order.firstIndex(of: target) else { return }
        order.insert(source, at: index + (before ? 0 : 1)); sectionOrder = order
    }
}
struct TypeBoard: Codable, Identifiable {
    var id = UUID()
    var name = "Untitled typeboard"
    var directions = [TypeDirection()]
    var selectedDirection: UUID?
    var candidates: [String] = []
    var checkpoints: [DirectionCheckpoint]?
    var isValid: Bool { !directions.isEmpty && directions.allSatisfy(\.isValid) && (checkpoints ?? []).allSatisfy { $0.direction.isValid } }
}
struct DirectionCheckpoint: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var direction: TypeDirection
}
struct DesignSpace: Codable, Identifiable {
    var id = UUID()
    var name = "Untitled space"
    var boards: [TypeBoard] = []
}
struct StudioState: Codable {
    var version = 1
    var spaces: [DesignSpace] = []
    var selectedSpace: UUID?
    var selectedBoard: UUID?
}
final class StudioStore: ObservableObject {
    @Published var focusedSpace: UUID?
    @Published var focusedBoard: UUID?
    @Published var state = StudioState()
    @Published var error = ""
    @Published var savedAt: Date?
    let url: URL
    private(set) var readBlocked = false
    init(url: URL) {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let loaded = try JSONDecoder().decode(StudioState.self, from: Data(contentsOf: url))
            guard loaded.version == 1, loaded.spaces.allSatisfy({ $0.boards.allSatisfy(\.isValid) }) else { throw NSError(domain: "FontShelf", code: 1, userInfo: [NSLocalizedDescriptionKey: "The workspace has invalid data or requires a newer FontShelf version."]) }
            state = loaded
            focusedSpace = loaded.selectedSpace; focusedBoard = loaded.selectedBoard
        } catch { readBlocked = true; self.error = "Spaces could not be opened. The saved file has been preserved. " + error.localizedDescription }
    }
    @discardableResult func save() -> Bool {
        guard !readBlocked else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            state.selectedSpace = focusedSpace; state.selectedBoard = focusedBoard
            let data = try JSONEncoder().encode(state)
            try LibraryBackupTools.preserve(url)
            if FileManager.default.fileExists(atPath: url.path) {
                try Data(contentsOf: url).write(to: url.appendingPathExtension("backup"), options: .atomic)
            }
            try data.write(to: url, options: .atomic); savedAt = Date(); error = ""; return true
        } catch { self.error = "Spaces could not be saved: " + error.localizedDescription; return false }
    }
    func addSpace(_ name: String) -> UUID {
        let space = DesignSpace(name: name.isEmpty ? "Untitled space" : name)
        state.spaces.append(space); focusedSpace = space.id; focusedBoard = nil; save(); return space.id
    }
    func addBoard(space: UUID, fonts: [String] = []) -> UUID? {
        guard let i = state.spaces.firstIndex(where: { $0.id == space }) else { return nil }
        let board = TypeBoard(name: "Typeboard \(state.spaces[i].boards.count + 1)", directions: [TypeDirection(fonts: fonts)], candidates: fonts)
        state.spaces[i].boards.append(board); focusedSpace = space; focusedBoard = board.id; save(); return board.id
    }
    func update(space: UUID, board: TypeBoard) {
        guard let i = state.spaces.firstIndex(where: { $0.id == space }), let j = state.spaces[i].boards.firstIndex(where: { $0.id == board.id }) else { return }
        state.spaces[i].boards[j] = board; save()
    }
}

struct TagQuery: Equatable {
    var included: Set<String> = []
    var excluded: Set<String> = []
    var matchAll = true
    var active: Bool { !included.isEmpty || !excluded.isEmpty }
    static func contains(_ parent: String, in tags: Set<String>) -> Bool { tags.contains { $0 == parent || $0.hasPrefix(parent + "/") } }
    func matches(_ tags: Set<String>) -> Bool {
        let include = included.isEmpty || (matchAll ? included.allSatisfy { Self.contains($0, in: tags) } : included.contains { Self.contains($0, in: tags) })
        return include && !excluded.contains { Self.contains($0, in: tags) }
    }
    static func hierarchy(_ tags: Set<String>) -> [String] {
        var result = tags
        for tag in tags { let parts = tag.split(separator: "/"); for count in 1..<max(1, parts.count) { result.insert(parts.prefix(count).joined(separator: "/")) } }
        return result.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
