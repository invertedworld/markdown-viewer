import AppKit

enum BrowserOpener {
    /// Renders a Markdown file to HTML in the caches directory and opens it in the default browser.
    /// The completion handler runs on the main queue once the browser has accepted the file.
    static func open(markdownFile url: URL, completion: @escaping (Error?) -> Void) throws {
        let markdown = MarkdownRenderer.decode(try Data(contentsOf: url))
        let html = MarkdownRenderer.renderDocument(markdown,
                                                   title: url.lastPathComponent,
                                                   baseURL: url.deletingLastPathComponent())

        let outputDirectory = try FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MarkdownViewer", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        removeStaleFiles(in: outputDirectory)

        // A short hash of the full path keeps same-named files from different folders apart.
        let key = String(url.path.utf8.reduce(UInt32(5381)) { ($0 &* 33) ^ UInt32($1) }, radix: 16)
        let outputURL = outputDirectory
            .appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(key).html")
        try Data(html.utf8).write(to: outputURL, options: .atomic)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let browser = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)
            ?? NSWorkspace.shared.urlForApplication(toOpen: outputURL)
        guard let browser else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "No web browser is installed."])
        }
        NSWorkspace.shared.open([outputURL], withApplicationAt: browser, configuration: configuration) { _, error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    private static func removeStaleFiles(in directory: URL) {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let files = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                  includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
