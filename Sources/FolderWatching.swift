import Foundation
import SwiftUI
import CoreText

struct FontFileStamp: Equatable {
    let size: Int
    let modified: Date
    let identity: String
    static func read(_ url: URL) -> FontFileStamp? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .fileResourceIdentifierKey, .isRegularFileKey]), values.isRegularFile == true else { return nil }
        return FontFileStamp(size: values.fileSize ?? 0, modified: values.contentModificationDate ?? .distantPast, identity: String(describing: values.fileResourceIdentifier))
    }
}
enum FontFolderSnapshot {
    static func read(_ roots: [String]) -> (files: [String: FontFileStamp], errors: [String]) {
        var files: [String: FontFileStamp] = [:], errors: [String] = []
        for root in roots {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory), isDirectory.boolValue else { errors.append(root + ": Folder unavailable"); continue }
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .fileResourceIdentifierKey, .isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { url, error in errors.append(url.path + ": " + error.localizedDescription); return true }) else { errors.append(root + ": Cannot read folder"); continue }
            for case let url as URL in enumerator where DuplicateFinder.extensions.contains(url.pathExtension.lowercased()) {
                if let stamp = FontFileStamp.read(url) { files[url.standardizedFileURL.path] = stamp }
                else { errors.append(url.path + ": Cannot read font") }
            }
        }
        return (files, errors)
    }
    static func contains(_ path: String, root: String) -> Bool { path.hasPrefix(URL(fileURLWithPath: root).standardizedFileURL.path + "/") }
}
/// Poll recursively on a private queue. This also handles removable and cloud-backed folders.
final class FolderWatcher {
    private let queue = DispatchQueue(label: "FontShelf.folder-watch", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var roots: [String] = []
    private var last: [String: FontFileStamp]?
    private var errors: [String] = []
    func configure(roots: [String], changed: @escaping ([String]) -> Void) {
        queue.async { [weak self] in
            guard let self, self.roots != roots || self.timer == nil else { return }
            self.timer?.cancel(); self.timer = nil; self.roots = roots; self.last = nil
            guard !roots.isEmpty else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 3, leeway: .milliseconds(500))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                let current = FontFolderSnapshot.read(roots)
                let differs = self.last != current.files || self.errors != current.errors
                self.last = current.files; self.errors = current.errors
                if differs { DispatchQueue.main.async { changed(current.errors) } }
            }
            self.timer = timer; timer.resume()
        }
    }
    deinit { timer?.cancel() }
}

extension Library {
    func configureWatcher() {
        folderWatcher.configure(roots: resolvedFolders) { [weak self] errors in
            guard let self else { return }
            self.folderStatus = errors.isEmpty ? "Changes detected; refreshing…" : errors.joined(separator: "\n")
            self.reload(register: true)
        }
    }
    func applyFolderActivation() {
        let roots = (saved.autoActivateFolders ?? []).compactMap { try? folderAccess.restore($0) }
        let urls = Set(allFaces.compactMap(\.url).filter { url in roots.contains { FontFolderSnapshot.contains(url.path, root: $0) } })
        var errors: [String] = []
        for path in autoActivatedPaths where !urls.contains(URL(fileURLWithPath: path)) {
            do { try ActivationManager.shared.deactivate(URL(fileURLWithPath: path), restore: FileManager.default.fileExists(atPath: path)); autoActivatedPaths.remove(path); autoActivatedStamps.removeValue(forKey: path) }
            catch { errors.append(error.localizedDescription) }
        }
        for url in urls where !ActivationManager.shared.owns(url) {
            do { _ = try ActivationManager.shared.activate(url); if ActivationManager.shared.owns(url) { autoActivatedPaths.insert(url.path); autoActivatedStamps[url.path] = FontFileStamp.read(url) } }
            catch { errors.append(url.lastPathComponent + ": " + error.localizedDescription) }
        }
        if !errors.isEmpty { folderStatus = errors.joined(separator: "\n") }
    }
}
struct WatchedFoldersView: View {
    @ObservedObject var library: Library
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Watched folders").font(.headline); Spacer(); Button("Add folder…") { library.addFolder() }; Button("Refresh now") { library.reload(register: true) }.disabled(library.loading) }
            Text("Folders and subfolders are checked every three seconds while FontShelf is open.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(library.saved.folders, id: \.self) { path in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "folder").font(.headline); Spacer(); Button("Stop watching") { library.saved.folders.removeAll { $0 == path }; library.saved.autoActivateFolders?.remove(path); library.save(); library.reload(register: true) } }
                            Text(path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            Toggle("Activate fonts for other apps", isOn: Binding(get: { library.saved.autoActivateFolders?.contains(path) == true }, set: { enabled in var paths = library.saved.autoActivateFolders ?? []; if enabled { paths.insert(path) } else { paths.remove(path) }; library.saved.autoActivateFolders = paths; library.save(); library.applyFolderActivation() })).toggleStyle(.checkbox).disabled(library.loading)
                        }.padding(14).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                    }
                    if library.saved.folders.isEmpty { Text("No watched folders").foregroundStyle(.secondary).padding(25) }
                }
            }
            Text("Activation uses the original files. Activated fonts are cleared when FontShelf quits normally or you log out. Stopping a watch keeps your font files.").font(.caption).foregroundStyle(.secondary)
            Text(library.folderStatus).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }.padding(12)
    }
}

struct TagFilterView: View {
    @ObservedObject var library: Library
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Tag filters").font(.headline); Spacer(); Button("Clear") { library.tagQuery = TagQuery() } }
            Picker("Combine included tags", selection: $library.tagQuery.matchAll) { Text("All included (AND)").tag(true); Text("Any included (OR)").tag(false) }.pickerStyle(.segmented)
            Text("Excluded tags always take precedence. Parent tags include descendants.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                ForEach(TagQuery.hierarchy(Set(library.pro.tags.values.flatMap { $0 })), id: \.self) { tag in
                    HStack {
                        Text(tag).lineLimit(1); Spacer()
                        ShelfDropdown(title: tag, selection: Binding(get: { library.tagQuery.excluded.contains(tag) ? -1 : library.tagQuery.included.contains(tag) ? 1 : 0 }, set: { value in library.tagQuery.included.remove(tag); library.tagQuery.excluded.remove(tag); if value == 1 { library.tagQuery.included.insert(tag) }; if value == -1 { library.tagQuery.excluded.insert(tag) } }), options: [("Any", 0), ("Include", 1), ("Exclude", -1)], showsTitle: false).frame(width: 110)
                    }.padding(.vertical, 4)
                }
            }
        }.padding(20).frame(width: 420, height: 400)
    }
}
