import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Converts Markdown (GitHub-flavoured) into a complete, styled HTML document.
enum MarkdownRenderer {
    private static let extensionNames = ["table", "strikethrough", "autolink", "tasklist", "tagfilter"]

    static func renderBody(_ markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()
        let options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES | CMARK_OPT_GITHUB_PRE_LANG | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        let bytes = Array(markdown.utf8)
        bytes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress?.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                cmark_parser_feed(parser, $0, buffer.count)
            }
        }
        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }

        guard let html = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else { return "" }
        defer { free(html) }
        return String(cString: html)
    }

    /// - Parameters:
    ///   - baseURL: directory used to resolve relative links and images.
    static func renderDocument(_ markdown: String, title: String, baseURL: URL? = nil) -> String {
        let base = baseURL.map { "<base href=\"\(escape($0.absoluteString))\">\n" } ?? ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        \(base)<title>\(escape(title))</title>
        <style>\(stylesheet)</style>
        </head>
        <body>
        <article class="markdown-body">
        \(renderBody(markdown))
        </article>
        </body>
        </html>
        """
    }

    static func decode(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        return String(decoding: data, as: UTF8.self)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static let stylesheet = """
    :root {
      --fg: #1f2328; --muted: #59636e; --bg: #ffffff; --border: #d1d9e0;
      --code-bg: #f6f8fa; --link: #0969da; --quote: #59636e; --row-alt: #f6f8fa;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --fg: #e6edf3; --muted: #9198a1; --bg: #0d1117; --border: #3d444d;
        --code-bg: #151b23; --link: #4493f8; --quote: #9198a1; --row-alt: #151b23;
      }
    }
    html { background: var(--bg); }
    body {
      margin: 0; padding: 32px 16px; color: var(--fg); background: var(--bg);
      font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
      -webkit-text-size-adjust: 100%;
    }
    .markdown-body { max-width: 860px; margin: 0 auto; word-wrap: break-word; }
    .markdown-body > :first-child { margin-top: 0; }
    h1, h2, h3, h4, h5, h6 { margin: 1.5em 0 0.6em; font-weight: 600; line-height: 1.25; }
    h1 { font-size: 2em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    h2 { font-size: 1.5em; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    h3 { font-size: 1.25em; } h4 { font-size: 1em; } h5 { font-size: .875em; }
    h6 { font-size: .85em; color: var(--muted); }
    p, ul, ol, blockquote, pre, table, dl { margin: 0 0 1em; }
    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }
    ul, ol { padding-left: 2em; }
    li + li { margin-top: .25em; }
    li > p { margin: .5em 0; }
    li.task-list-item, ul:has(> li > input[type=checkbox]) { list-style: none; }
    ul:has(> li > input[type=checkbox]) { padding-left: 1.2em; }
    input[type=checkbox] { margin: 0 .4em 0 -1.2em; vertical-align: middle; }
    blockquote { padding: 0 1em; color: var(--quote); border-left: .25em solid var(--border); }
    code, pre, kbd { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 85%; }
    code { padding: .2em .4em; background: var(--code-bg); border-radius: 6px; }
    pre { padding: 16px; overflow: auto; line-height: 1.45; background: var(--code-bg); border-radius: 6px; }
    pre code { padding: 0; background: transparent; font-size: 100%; }
    kbd { padding: .1em .4em; border: 1px solid var(--border); border-bottom-width: 2px; border-radius: 6px; }
    table { border-collapse: collapse; display: block; width: max-content; max-width: 100%; overflow: auto; }
    th, td { padding: 6px 13px; border: 1px solid var(--border); }
    th { font-weight: 600; }
    tr:nth-child(2n) { background: var(--row-alt); }
    img { max-width: 100%; }
    hr { height: 2px; margin: 1.5em 0; background: var(--border); border: 0; }
    del { color: var(--muted); }
    .footnotes { font-size: .875em; color: var(--muted); border-top: 1px solid var(--border); margin-top: 2em; padding-top: 1em; }
    @media print { body { padding: 0; } pre, table { break-inside: avoid; } }
    """
}
