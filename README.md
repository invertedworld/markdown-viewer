# Markdown Viewer

Thank you for installing Markdown Viewer.

Markdown Viewer is a macOS application that provides two facilities for Markdown documents
(`.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`):

1. **Quick Look preview.** A Quick Look extension renders a Markdown document as formatted text
   when the document is selected in Finder and the Space bar is pressed.
2. **Opening in Preview.** When a Markdown document is double-clicked, it is converted to a
   paginated A4 PDF and opened in Preview.

Both facilities support GitHub-flavoured Markdown: tables, task lists, strikethrough, autolinks,
footnotes and fenced code blocks. Raw HTML in a document is passed through unchanged. The Quick Look
preview follows the system light or dark appearance; the PDF is always rendered on a white page.

## Activation

Markdown Viewer should be launched once from the Applications folder. The window that appears
contains a button, **Set as Default for Markdown Files**, which makes Markdown Viewer the
application that opens Markdown documents on a double-click. macOS may ask for this change to be
confirmed.

The Quick Look extension is registered automatically when the application is first launched. It
may be enabled or disabled in **System Settings > General > Login Items & Extensions > Quick Look**.

> **Note:** If another Quick Look extension for Markdown is installed, macOS uses only one of them.
> The other extension should be disabled in System Settings.

## Opening in Preview

When a Markdown document is opened, Markdown Viewer renders it with WebKit, prints it to a PDF on
A4 paper with margins of 15 mm, passes the PDF to Preview, and then quits. The PDF is written to
`~/Library/Caches/com.invertedworld.MarkdownViewer/`, in a folder specific to the original
document, and carries the original document's name. Relative links and images are resolved against
the folder that contains the original document, so local images are included. Rendered files older
than seven days are removed automatically.

The PDF is a snapshot of the document at the time it was opened. To see later changes, the document
is opened again; Preview then reloads the updated PDF.

## Quick Look preview

The Quick Look extension runs in the macOS sandbox and may read only the document being previewed.
Images stored beside the document are therefore not shown in the preview; images referenced by an
`https://` address are shown.

## Building from source

The project is described in `project.yml` and generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
Markdown is parsed with [swift-cmark](https://github.com/swiftlang/swift-cmark) (cmark-gfm), which
Xcode fetches through Swift Package Manager.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project MarkdownViewer.xcodeproj -scheme MarkdownViewer \
  -configuration Release -derivedDataPath build build
ditto "build/Build/Products/Release/Markdown Viewer.app" "/Applications/Markdown Viewer.app"
```

Signing uses the Developer ID Application certificate for team `U7KDB84YPD`. The default handler
may also be set from the command line:

```sh
open -a "Markdown Viewer" --args --set-default
```

`Samples/sample.md` contains examples of each supported feature.

## Principle of operation

Both components share `Shared/MarkdownRenderer.swift`, which parses the document with cmark-gfm,
enables the GitHub extensions, and wraps the resulting HTML in a page with an embedded stylesheet.
The Quick Look extension (`QuickLook/PreviewProvider.swift`) is a data-based preview provider that
returns this HTML to Quick Look. The application (`App/`) declares itself a viewer for the
`net.daringfireball.markdown` type. On receiving an open request it renders the document, inserts a
`<base>` element pointing at the document's folder, loads the page into an off-screen WebKit view,
and prints that view to a PDF file, which is then opened in Preview. The application waits until
Preview has accepted the file before quitting, because quitting earlier can cancel the transfer of
the file.
