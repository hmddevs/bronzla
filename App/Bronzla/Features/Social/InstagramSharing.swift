import UIKit

/// Direct handoff of a rendered share card to Instagram Stories, bypassing the system share
/// sheet. Only usable when Instagram is installed; the caller falls back to `ShareLink` when
/// it isn't.
///
/// `LSApplicationQueriesSchemes` must list `instagram-stories` or `canOpenURL` always returns
/// false regardless of whether Instagram is actually installed. That entry lives in
/// `Config/Bronzla-Info.plist`, not as an `INFOPLIST_KEY_`: array-typed Info.plist keys do not
/// survive that mechanism, which is exactly what broke the widget extension's `NSExtension`
/// dictionary earlier in this project.
enum InstagramSharing {
    private static let storiesURL = URL(string: "instagram-stories://share")!
    private static let pasteboardImageKey = "com.instagram.sharedSticker.backgroundImage"
    private static let pasteboardExpiry: TimeInterval = 300

    @MainActor
    static var isAvailable: Bool {
        UIApplication.shared.canOpenURL(storiesURL)
    }

    /// Hands a rendered card straight to Instagram's Stories composer via the pasteboard.
    /// Returns `false` if Instagram is not installed; the caller should fall back to the plain
    /// share sheet in that case rather than treat it as an error.
    @MainActor
    @discardableResult
    static func shareToStories(imageData: Data, bundleIdentifier: String) -> Bool {
        guard isAvailable,
              let url = URL(string: "instagram-stories://share?source_application=\(bundleIdentifier)")
        else { return false }

        UIPasteboard.general.setItems(
            [[pasteboardImageKey: imageData]],
            options: [.expirationDate: Date.now.addingTimeInterval(pasteboardExpiry)]
        )
        UIApplication.shared.open(url)
        return true
    }
}
