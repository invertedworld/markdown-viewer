import Foundation
import Quartz
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let data = try Data(contentsOf: request.fileURL)
        let markdown = MarkdownRenderer.decode(data)
        let title = request.fileURL.lastPathComponent
        let html = MarkdownRenderer.renderDocument(markdown, title: title)

        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1000)) { reply in
            reply.stringEncoding = .utf8
            reply.title = title
            return Data(html.utf8)
        }
    }
}
