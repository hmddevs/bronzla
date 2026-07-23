import Foundation
import UIKit

/// Filesystem store for session photos. SwiftData is not a blob store, so `TanSession` keeps
/// only filenames and this actor owns the bytes on disk.
///
/// Resizing and JPEG encoding happen through a `nonisolated` static function that runs on the
/// caller's own isolation domain, because `UIImage` is not `Sendable` and must never cross an
/// `await` into the actor. Everything that actually touches the actor's state (`save`, `load`,
/// `delete`) deals only in `Data`, `String` and `URL`, which are all trivially `Sendable`.
actor SessionPhotoStore {

    /// Longest edge a stored photo is allowed to keep. A season of full-resolution photos would
    /// otherwise fill the device; this is a generous size for a thumbnail-and-detail view.
    static let maximumLongestEdge: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.8

    private let directoryURL: URL

    init() {
        directoryURL = URL.applicationSupportDirectory.appending(path: "SessionPhotos", directoryHint: .isDirectory)
    }

    // MARK: - Encoding (runs off-actor, on the caller's isolation domain)

    /// Resizes to `maximumLongestEdge` and JPEG-encodes. Call this before handing bytes to the
    /// actor; it deliberately does no file I/O so it can run wherever the `UIImage` already is.
    nonisolated static func encodeJPEG(from image: UIImage) -> Data? {
        resized(image, maxLongestEdge: maximumLongestEdge).jpegData(compressionQuality: jpegQuality)
    }

    nonisolated private static func resized(_ image: UIImage, maxLongestEdge: CGFloat) -> UIImage {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > maxLongestEdge, longestEdge > 0 else { return image }

        let scale = maxLongestEdge / longestEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    // MARK: - Storage

    /// Writes JPEG data to disk and returns the generated filename to store on the session.
    func save(_ data: Data) throws -> String {
        try ensureDirectoryExists()
        let filename = "\(UUID().uuidString).jpg"
        try data.write(to: fileURL(for: filename), options: .atomic)
        return filename
    }

    /// Loads raw JPEG bytes for a stored photo, or `nil` if it is missing.
    func loadData(named filename: String) -> Data? {
        try? Data(contentsOf: fileURL(for: filename))
    }

    /// Removes a stored photo. Silently no-ops if it is already gone, since the session's
    /// filename list is the source of truth and a missing file should not block deletion.
    func delete(named filename: String) {
        try? FileManager.default.removeItem(at: fileURL(for: filename))
    }

    private func fileURL(for filename: String) -> URL {
        directoryURL.appending(path: filename)
    }

    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
