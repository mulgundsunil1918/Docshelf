import UIKit

// MARK: - Data model
//
// MUST match receive_sharing_intent v1.8.1's SharedMediaFile exactly.
// Critical differences from a naive implementation:
//   • type is a String enum ("image","video","file","url","text") — NOT Int
//   • mimeType and message fields must be present (optional but in the struct)
// The plugin force-unwraps its JSON decode, so any mismatch = crash (SIGILL).

struct SharedMediaFile: Codable {
    var path: String
    var mimeType: String?
    var thumbnail: String?
    var duration: Double?
    var message: String?
    var type: SharedMediaType

    // Raw values must match plugin's enum case names exactly (String rawValue)
    enum SharedMediaType: String, Codable {
        case image
        case video
        case file
        case url
        case text
    }
}

// MARK: - ShareViewController
//
// Processes shared files silently (no compose UI), saves them to the App
// Group container, then opens the main app so the Save-Document sheet
// can appear.  The main app reads the files via receive_sharing_intent.

@objc(ShareViewController)
class ShareViewController: UIViewController {

    static let appGroupId  = "group.com.docshelf.myapp"
    static let urlScheme   = "ShareMedia-com.docshelf.myapp"
    static let shareKey    = "ShareKey"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await handleShare() }
    }

    private func handleShare() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish(); return
        }

        let providers = items.compactMap { $0.attachments }.flatMap { $0 }
        guard !providers.isEmpty else { finish(); return }

        guard let groupUrl = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)?
                .appendingPathComponent("ShareExtension", isDirectory: true) else {
            finish(); return
        }
        try? FileManager.default.createDirectory(
            at: groupUrl, withIntermediateDirectories: true)

        var results: [SharedMediaFile] = []
        for provider in providers {
            if let file = await copyFile(from: provider, into: groupUrl) {
                results.append(file)
            }
        }

        if let data = try? JSONEncoder().encode(results) {
            let defaults = UserDefaults(suiteName: Self.appGroupId)
            defaults?.set(data, forKey: Self.shareKey)
            defaults?.synchronize()
        }

        if let url = URL(string: "\(Self.urlScheme)://dataUrl=\(Self.shareKey)") {
            openURL(url)
        }
        finish()
    }

    private func copyFile(from provider: NSItemProvider,
                          into destDir: URL) async -> SharedMediaFile? {
        // Use stable UTI strings — UTType struct requires iOS 14+
        let candidates: [(String, SharedMediaFile.SharedMediaType)] = [
            ("com.adobe.pdf",      .file),
            ("public.image",       .image),
            ("public.movie",       .video),
            ("public.audio",       .file),
            ("public.zip-archive", .file),
            ("public.plain-text",  .file),
            ("public.file-url",    .file),
            ("public.data",        .file),
        ]

        for (typeId, mediaType) in candidates {
            guard provider.hasItemConformingToTypeIdentifier(typeId) else { continue }
            if let file = await loadItem(provider: provider,
                                         typeId: typeId,
                                         mediaType: mediaType,
                                         destDir: destDir) {
                return file
            }
        }
        return nil
    }

    private func loadItem(provider: NSItemProvider,
                          typeId: String,
                          mediaType: SharedMediaFile.SharedMediaType,
                          destDir: URL) async -> SharedMediaFile? {
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
                guard error == nil else { continuation.resume(returning: nil); return }

                var srcURL: URL?

                if let url = item as? URL {
                    srcURL = url
                } else if let data = item as? Data {
                    let ext  = self.fileExtension(for: typeId)
                    let name = "shared_\(UUID().uuidString).\(ext)"
                    let tmp  = destDir.appendingPathComponent(name)
                    try? data.write(to: tmp)
                    continuation.resume(returning: SharedMediaFile(
                        path: tmp.path, type: mediaType))
                    return
                }

                guard let src = srcURL else {
                    continuation.resume(returning: nil); return
                }

                let dest = self.uniqueDestination(
                    destDir.appendingPathComponent(src.lastPathComponent))

                let needsScope = src.startAccessingSecurityScopedResource()
                defer { if needsScope { src.stopAccessingSecurityScopedResource() } }

                do {
                    try FileManager.default.copyItem(at: src, to: dest)
                    continuation.resume(returning: SharedMediaFile(
                        path: dest.path, type: mediaType))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func uniqueDestination(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let stem = url.deletingPathExtension().lastPathComponent
        let ext  = url.pathExtension
        let dir  = url.deletingLastPathComponent()
        var i = 2
        while true {
            let candidate = dir.appendingPathComponent(
                ext.isEmpty ? "\(stem)_\(i)" : "\(stem)_\(i).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            i += 1
        }
    }

    private func fileExtension(for typeId: String) -> String {
        switch typeId {
        case "com.adobe.pdf":    return "pdf"
        case "public.image":     return "jpg"
        case "public.movie":     return "mp4"
        case "public.audio":     return "m4a"
        case "public.plain-text": return "txt"
        default:                  return "dat"
        }
    }

    @discardableResult
    private func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url)
                return true
            }
            responder = r.next
        }
        return false
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
