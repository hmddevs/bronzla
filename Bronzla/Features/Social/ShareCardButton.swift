import SwiftUI

/// "Share": renders a `ShareCardView` on demand and hands it to Instagram Stories directly
/// when Instagram is installed, offering the plain system share sheet either way.
///
/// Rendering happens lazily, on tap, rather than eagerly on appear: most sessions are never
/// shared, and `ImageRenderer` work should not run for cards nobody looks at.
struct ShareCardButton: View {
    let content: ShareCardView.Content
    var profileName: String = ""
    var beforeImage: UIImage?
    var afterImage: UIImage?

    @State private var renderedURL: URL?
    @State private var isRendering = false
    @State private var renderFailed = false

    var body: some View {
        Group {
            if let renderedURL {
                if InstagramSharing.isAvailable {
                    Menu {
                        Button {
                            shareToInstagram(renderedURL)
                        } label: {
                            Label("Instagram Story", systemImage: "camera.fill")
                        }
                        ShareLink(item: renderedURL) {
                            Label("Other apps", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        label
                    }
                } else {
                    ShareLink(item: renderedURL) {
                        label
                    }
                }
            } else {
                Button(action: render) {
                    label
                }
                .disabled(isRendering)
            }
        }
        .alert("Card could not be created", isPresented: $renderFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private var label: some View {
        Label(isRendering ? "Preparing…" : "Share", systemImage: "square.and.arrow.up")
    }

    private func render() {
        isRendering = true
        let card = ShareCardView(
            content: content,
            profileName: profileName,
            beforeImage: beforeImage,
            afterImage: afterImage
        )
        do {
            renderedURL = try ShareCardRenderer.renderPNG(card)
        } catch {
            renderFailed = true
        }
        isRendering = false
    }

    private func shareToInstagram(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        InstagramSharing.shareToStories(
            imageData: data,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.hmdcorp.bronzla"
        )
    }
}
