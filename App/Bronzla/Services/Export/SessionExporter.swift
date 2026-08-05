import Foundation
import OSLog

/// Exports the session history as CSV.
///
/// CSV rather than JSON or PDF: the people who ask for their data want to open it in Numbers
/// or Excel, or hand it to a dermatologist. A machine-readable format nobody can read without
/// a developer is not data portability.
struct SessionExporter: Sendable {

    private static let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "Export")

    /// Column headers in Turkish, since the export is for the user rather than for an import
    /// routine that would care about stable identifiers.
    private static let headers = [
        "Start", "End", "Duration (min)", "Place", "Skin type", "SPF",
        "Peak UV", "Dose (J/m²)", "Burn threshold (%)", "Note",
    ]

    /// Renders sessions to a CSV string, newest first.
    static func csv(for sessions: [TanSession]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let rows = sessions.sorted { $0.startedAt > $1.startedAt }.map { session in
            [
                formatter.string(from: session.startedAt),
                formatter.string(from: session.endedAt),
                String(Int((session.duration.seconds / 60).rounded())),
                session.placeName,
                session.skinType.numeral,
                String(session.spf),
                String(Int(session.peakUVIndex.rounded())),
                String(Int(session.erythemalDose.rounded())),
                String(Int((session.burnRisk * 100).rounded())),
                session.notes,
            ]
            .map(escape)
            .joined(separator: ",")
        }

        return ([headers.map(escape).joined(separator: ",")] + rows).joined(separator: "\n")
    }

    /// Writes the CSV to a temporary file and returns its URL, ready for a ShareLink.
    ///
    /// A file rather than a raw string, because sharing a string offers "Copy" and little else,
    /// while a `.csv` file opens directly in Numbers and attaches to mail.
    static func writeCSV(for sessions: [TanSession]) -> URL? {
        let name = "bronzla-seanslar-\(Self.fileDateStamp()).csv"
        let url = URL.temporaryDirectory.appending(path: name)

        do {
            // A BOM so Excel opens Turkish characters correctly rather than as mojibake.
            let bom = "\u{FEFF}"
            try (bom + csv(for: sessions)).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            logger.error("CSV export failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Private

    /// RFC 4180 quoting: wrap in quotes when the value contains a comma, quote or newline, and
    /// double any embedded quotes. A place name with a comma in it would otherwise shift every
    /// subsequent column.
    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func fileDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
