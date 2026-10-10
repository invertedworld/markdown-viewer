import AppKit
import WebKit

/// Renders a Markdown file to a paginated A4 PDF in the caches directory and opens it in Preview.
final class PreviewOpener: NSObject, WKNavigationDelegate {
    private static var active: [PreviewOpener] = []

    private let sourceURL: URL
    private let htmlURL: URL
    private let pdfURL: URL
    private let completion: (Error?) -> Void
    private var webView: WKWebView?

    /// The completion handler runs on the main queue once Preview has accepted the PDF.
    static func open(markdownFile url: URL, completion: @escaping (Error?) -> Void) throws {
        let opener = try PreviewOpener(sourceURL: url, completion: completion)
        active.append(opener)
        opener.start()
    }

    private init(sourceURL: URL, completion: @escaping (Error?) -> Void) throws {
        self.sourceURL = sourceURL
        self.completion = completion

        let cache = try FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MarkdownViewer", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        Self.removeStaleItems(in: cache)

        // One folder per source path keeps same-named files apart while the PDF keeps the
        // document's own name, which Preview shows as the window title.
        let key = String(sourceURL.path.utf8.reduce(UInt32(5381)) { ($0 &* 33) ^ UInt32($1) }, radix: 16)
        let folder = cache.appendingPathComponent(key, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let name = sourceURL.deletingPathExtension().lastPathComponent
        htmlURL = folder.appendingPathComponent("\(name).html")
        pdfURL = folder.appendingPathComponent("\(name).pdf")

        let markdown = MarkdownRenderer.decode(try Data(contentsOf: sourceURL))
        let html = MarkdownRenderer.renderDocument(markdown,
                                                   title: sourceURL.lastPathComponent,
                                                   baseURL: sourceURL.deletingLastPathComponent())
        try Data(html.utf8).write(to: htmlURL, options: .atomic)
        super.init()
    }

    private func start() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "shouldPrintBackgrounds")
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1100), configuration: configuration)
        // The PDF is always light, whatever the system appearance.
        webView.appearance = NSAppearance(named: .aqua)
        webView.navigationDelegate = self
        self.webView = webView
        // Read access to the whole disk lets relative image paths in the document resolve.
        webView.loadFileURL(htmlURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let printInfo = NSPrintInfo(dictionary: [
            .jobDisposition: NSPrintInfo.JobDisposition.save,
            .jobSavingURL: pdfURL,
        ])
        printInfo.paperSize = NSSize(width: 595.28, height: 841.89) // A4 in points
        printInfo.topMargin = 42
        printInfo.bottomMargin = 42
        printInfo.leftMargin = 42
        printInfo.rightMargin = 42
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.view?.frame = webView.bounds
        operation.jobTitle = sourceURL.deletingPathExtension().lastPathComponent
        operation.runModal(for: hostWindow(for: webView), delegate: self,
                           didRun: #selector(printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }

    @objc private func printOperationDidRun(_ operation: NSPrintOperation, success: Bool,
                                            contextInfo: UnsafeMutableRawPointer?) {
        guard success else {
            return finish(CocoaError(.fileWriteUnknown,
                                     userInfo: [NSLocalizedDescriptionKey: "The PDF could not be created."]))
        }
        try? FileManager.default.removeItem(at: htmlURL)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview")
            ?? URL(fileURLWithPath: "/System/Applications/Preview.app")
        NSWorkspace.shared.open([pdfURL], withApplicationAt: preview, configuration: configuration) { [self] _, error in
            DispatchQueue.main.async { self.finish(error) }
        }
    }

    /// WebKit printing needs the view to be in a window; an off-screen one is used.
    private func hostWindow(for webView: WKWebView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: webView.frame.width, height: webView.frame.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        return window
    }

    private func finish(_ error: Error?) {
        webView?.window?.close()
        webView = nil
        completion(error)
        Self.active.removeAll { $0 === self }
    }

    private static func removeStaleItems(in directory: URL) {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let items = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                  includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for item in items {
            let modified = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }
}
