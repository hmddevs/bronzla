import CoreLocation
import Foundation

/// Hand-picked Turkish coastal and city locations for manual selection.
///
/// Two jobs: a graceful path when location permission is denied, and the far more common
/// case of planning. Someone in Istanbul in May wants next week's Bodrum UV, and no amount
/// of GPS accuracy answers that.
enum TurkishPlaces {
    struct Entry: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let region: String
        let latitude: Double
        let longitude: Double

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var place: LocationService.Place {
            LocationService.Place(coordinate: coordinate, name: name)
        }
    }

    static let all: [Entry] = [
        .init(id: "istanbul", name: "İstanbul", region: "Marmara", latitude: 41.0082, longitude: 28.9784),
        .init(id: "sile", name: "Şile", region: "Marmara", latitude: 41.1756, longitude: 29.6128),
        .init(id: "cesme", name: "Çeşme", region: "Ege", latitude: 38.3239, longitude: 26.3050),
        .init(id: "izmir", name: "İzmir", region: "Ege", latitude: 38.4237, longitude: 27.1428),
        .init(id: "kusadasi", name: "Kuşadası", region: "Ege", latitude: 37.8580, longitude: 27.2610),
        .init(id: "bodrum", name: "Bodrum", region: "Ege", latitude: 37.0344, longitude: 27.4305),
        .init(id: "marmaris", name: "Marmaris", region: "Ege", latitude: 36.8552, longitude: 28.2743),
        .init(id: "fethiye", name: "Fethiye", region: "Akdeniz", latitude: 36.6210, longitude: 29.1163),
        .init(id: "oludeniz", name: "Ölüdeniz", region: "Akdeniz", latitude: 36.5486, longitude: 29.1155),
        .init(id: "kas", name: "Kaş", region: "Akdeniz", latitude: 36.2019, longitude: 29.6395),
        .init(id: "antalya", name: "Antalya", region: "Akdeniz", latitude: 36.8969, longitude: 30.7133),
        .init(id: "alanya", name: "Alanya", region: "Akdeniz", latitude: 36.5444, longitude: 31.9997),
        .init(id: "mersin", name: "Mersin", region: "Akdeniz", latitude: 36.8121, longitude: 34.6415),
        .init(id: "ankara", name: "Ankara", region: "İç Anadolu", latitude: 39.9334, longitude: 32.8597),
        .init(id: "trabzon", name: "Trabzon", region: "Karadeniz", latitude: 41.0027, longitude: 39.7168),
    ]

    static var grouped: [(region: String, entries: [Entry])] {
        // Preserves the coastal ordering above rather than sorting alphabetically, so the list
        // reads west to east the way the coastline does.
        var order: [String] = []
        var buckets: [String: [Entry]] = [:]
        for entry in all {
            if buckets[entry.region] == nil { order.append(entry.region) }
            buckets[entry.region, default: []].append(entry)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}
