import SwiftUI

/// Rasterises a `ShareCardView` to a PNG on disk, ready for `ShareLink` or the Instagram
/// pasteboard handoff.
///
/// `ImageRenderer` must run on the main actor, and the file it writes needs to outlive the
/// share sheet's own async work, so this writes into `URL.temporaryDirectory` rather than
/// returning bytes the caller has to manage.
@MainActor
enum ShareCardRenderer {
    enum RenderError: Error {
        case rasterisationFailed
    }

    static func renderPNG(_ card: ShareCardView) throws -> URL {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = .init(ShareCardView.size)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw RenderError.rasterisationFailed
        }

        let url = URL.temporaryDirectory.appending(path: "bronzla-share-\(UUID().uuidString).png")
        try data.write(to: url, options: .atomic)
        return url
    }
}
