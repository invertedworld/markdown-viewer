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

## Requirements

- macOS 13 or later.
- Xcode 15 or later, with its command-line tools.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), which may be installed with `brew install xcodegen`.

## Setup

The application is built from source. The repository is cloned and the installation script is run:

```sh
git clone https://github.com/invertedworld/markdown-viewer.git
cd markdown-viewer
scripts/install.sh
```

The script generates the Xcode project, builds the application, copies it to `/Applications`,
registers the Quick Look extension and makes Markdown Viewer the default application for Markdown
documents. macOS may ask for the change of default application to be confirmed.

By default the application is signed ad hoc, which is sufficient for use on the Mac on which it was
built. To sign it with an Apple Development certificate instead, the team identifier is supplied:

```sh
TEAM=ABCDE12345 scripts/install.sh
```

The team identifier is shown in Xcode under **Settings > Accounts**, or in the Apple Developer
account under **Membership details**.

After installation, the following should be confirmed:

1. **Quick Look.** A Markdown document is selected in Finder and the Space bar is pressed. The
   document is shown formatted. If it is shown as plain text, the extension is enabled in
   **System Settings > General > Login Items & Extensions > Quick Look**, and Finder is relaunched
   by holding Option, Control-clicking the Finder icon in the Dock and choosing **Relaunch**.
2. **Opening in Preview.** A Markdown document is double-clicked. It opens in Preview as a PDF. If it
   opens in another application, the document is selected in Finder, **File > Get Info** is chosen,
   **Markdown Viewer** is selected under **Open with**, and **Change All…** is clicked.
   Alternatively, Markdown Viewer is launched from the Applications folder and
   **Set as Default for Markdown Files** is clicked.

> **Note:** If another Quick Look extension for Markdown is installed, macOS uses only one of them.
> The other extension should be disabled in System Settings.

### Removal

Markdown Viewer is removed by moving `/Applications/Markdown Viewer.app` to the Bin. Its cached
files may be removed with `rm -rf ~/Library/Caches/com.invertedworld.MarkdownViewer`. Another
application should then be chosen for Markdown documents with **Get Info > Open with > Change All…**.

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

## Building in Xcode

The project is described in `project.yml` and generated with XcodeGen; the generated
`MarkdownViewer.xcodeproj` is not kept in the repository. Markdown is parsed with
[swift-cmark](https://github.com/swiftlang/swift-cmark) (cmark-gfm), which Xcode fetches through
Swift Package Manager.

```sh
xcodegen generate
open MarkdownViewer.xcodeproj
```

`project.yml` signs with the author's Developer ID certificate. When building in Xcode with another
account, the team is changed under **Signing & Capabilities** for both targets, or the
`DEVELOPMENT_TEAM` and `CODE_SIGN_IDENTITY` settings are overridden on the `xcodebuild` command
line, as `scripts/install.sh` does. The default handler may also be set from the command line:

```sh
open -a "Markdown Viewer" --args --set-default
```

`Samples/sample.md` contains examples of each supported feature.

## Licence

Markdown Viewer is released under the MIT licence; see `LICENSE`. swift-cmark is distributed under
its own licence.

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
