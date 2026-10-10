import AppKit
import UniformTypeIdentifiers

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var openedFiles = false
    private var pendingOpens = 0

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openedFiles = true
        for url in urls {
            pendingOpens += 1
            do {
                try PreviewOpener.open(markdownFile: url) { [weak self] error in
                    if let error { self?.report(error, for: url) }
                    self?.finishOpen()
                }
            } catch {
                report(error, for: url)
                finishOpen()
            }
        }
    }

    private func report(_ error: Error, for url: URL) {
        let alert = NSAlert(error: error)
        alert.messageText = "Could not open \(url.lastPathComponent)"
        alert.runModal()
    }

    /// When launched only to open documents, quit once Preview has received all of them.
    /// Quitting earlier can cancel the hand-over of the file to Preview.
    private func finishOpen() {
        pendingOpens -= 1
        if pendingOpens == 0 && window == nil {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--set-default") {
            setAsDefault { NSApp.terminate(nil) }
            return
        }
        // Give pending open-document events a moment to arrive before showing the window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, !self.openedFiles else { return }
            self.showWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func showWindow() {
        NSApp.setActivationPolicy(.regular)

        let text = NSTextField(wrappingLabelWithString: """
        Markdown Viewer opens Markdown files in Preview, as formatted PDF documents, when they are double-clicked, \
        and provides a Quick Look preview (press Space on a Markdown file in Finder).

        To make double-clicking open Markdown files here, set Markdown Viewer as the default application below.
        """)
        text.preferredMaxLayoutWidth = 420

        let button = NSButton(title: "Set as Default for Markdown Files", target: self, action: #selector(setDefaultClicked))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"

        let stack = NSStackView(views: [text, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 180),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Markdown Viewer"
        window.contentView = stack
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func setDefaultClicked() {
        setAsDefault {}
    }

    private func setAsDefault(completion: @escaping () -> Void) {
        guard let type = UTType("net.daringfireball.markdown") else { return completion() }
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type) { error in
            DispatchQueue.main.async {
                if let error {
                    NSAlert(error: error).runModal()
                }
                completion()
            }
        }
    }
}
