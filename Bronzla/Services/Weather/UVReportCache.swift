import CoreLocation
import Foundation
import OSLog

/// On-disk cache of the last report seen for a coarse location.
///
/// An actor rather than a lock: writes happen on a background fetch, reads happen during a
/// refresh, and the compiler should enforce the isolation rather than a code review.
///
/// Coordinates are rounded to two decimal places (roughly one kilometre) before being used as
/// a key. UV does not vary meaningfully over a kilometre, and coarse keys mean walking down a
/// beach does not miss the cache. It also means the cache file records less about where the
/// user has been than the raw fix would.
actor UVReportCache {
    static let shared = UVReportCache()

    private let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "UVReportCache")
    private let fileManager = FileManager.default
    private let directory: URL

    /// Keep enough places for a road trip along the coast, not a location history.
    private let maximumEntries = 8

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.cachesDirectory.appending(path: "UVReports", directoryHint: .isDirectory)
    }

    func report(for coordinate: CLLocationCoordinate2D) -> UVReport? {
        let url = fileURL(for: coordinate)
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder.bronzla.decode(UVReport.self, from: data)
        else { return nil }

        // A day-old reading is worse than none: it will disagree with the sky overhead.
        guard Date.now.timeIntervalSince(stored.fetchedAt) < 12 * 3600 else {
            try? fileManager.removeItem(at: url)
            return nil
        }

        return UVReport(
            placeName: stored.placeName,
            current: stored.current,
            hourly: stored.hourly,
            daily: stored.daily,
            source: .cached,
            fetchedAt: stored.fetchedAt
        )
    }

    func store(_ report: UVReport, for coordinate: CLLocationCoordinate2D) {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder.bronzla.encode(report)
            try data.write(to: fileURL(for: coordinate), options: .atomic)
            pruneOldestEntries()
        } catch {
            // A cache miss is survivable, so this is logged rather than thrown, but it is
            // logged loudly: silent cache failure would look like a network problem forever.
            logger.error("UV report cache write failed: \((error as NSError).domain, privacy: .public) code \((error as NSError).code, privacy: .public); detail: \(error.localizedDescription, privacy: .private)")
        }
    }

    func removeAll() {
        try? fileManager.removeItem(at: directory)
    }

    // MARK: - Private

    private func fileURL(for coordinate: CLLocationCoordinate2D) -> URL {
        let latitude = (coordinate.latitude * 100).rounded() / 100
        let longitude = (coordinate.longitude * 100).rounded() / 100
        // Signs would otherwise produce a leading dash in the filename.
        let key = String(format: "%+.2f_%+.2f", latitude, longitude)
            .replacingOccurrences(of: "+", with: "p")
            .replacingOccurrences(of: "-", with: "m")
            .replacingOccurrences(of: ".", with: "_")
        return directory.appending(path: "\(key).json")
    }

    private func pruneOldestEntries() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ), urls.count > maximumEntries else { return }

        let sorted = urls.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        for url in sorted.dropFirst(maximumEntries) {
            try? fileManager.removeItem(at: url)
        }
    }
}

extension JSONEncoder {
    static let bronzla: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let bronzla: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
