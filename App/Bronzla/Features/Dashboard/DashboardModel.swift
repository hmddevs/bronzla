import CoreLocation
import Foundation
import Observation

/// Orchestrates the dashboard's single refresh.
///
/// This screen gets a model because it coordinates two async sources and owns a failure state.
/// Screens that only render a struct do not get one: an observable wrapper around a value is
/// ceremony, not architecture.
@MainActor
@Observable
final class DashboardModel {

    enum Phase: Equatable {
        case idle
        case loading
        case loaded(UVReport)
        case failed(String, detail: String? = nil)
    }

    private(set) var phase: Phase = .idle
    /// True during a pull-to-refresh, so the existing reading stays on screen underneath.
    private(set) var isRefreshing = false

    private var inFlight: Task<Void, Never>?

    var report: UVReport? {
        if case .loaded(let report) = phase { return report }
        return nil
    }

    func load(from provider: any UVDataProviding, place: LocationService.Place, isManualRefresh: Bool = false) {
        inFlight?.cancel()

        if report == nil {
            phase = .loading
        } else if isManualRefresh {
            isRefreshing = true
        }

        inFlight = Task { [weak self] in
            guard let self else { return }
            defer { self.isRefreshing = false }

            do {
                let report = try await provider.report(for: place.coordinate, placeName: place.name)
                guard !Task.isCancelled else { return }
                self.phase = .loaded(report)
            } catch {
                guard !Task.isCancelled else { return }
                // A failed refresh must never wipe a reading already on screen. Someone on a
                // beach with patchy signal is better served by a stale number than a blank one.
                if self.report == nil {
                    let uvError = error as? UVDataError
                    let message = uvError?.errorDescription
                        ?? String(localized: "Could not fetch data. Please try again.")
                    self.phase = .failed(message, detail: uvError?.diagnosticDetail
                        ?? (error as NSError).debugDescription)
                }
            }
        }
    }
}
