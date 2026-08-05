#if DEBUG
import Foundation

/// Deterministic demo content for the watch App Store screenshots.
///
/// The watch twin of `ScreenshotSeed`, and compiled out of Release for the same reason: no
/// shipping binary can be talked into serving fabricated UV data by a launch argument.
///
/// The watch needs this more than the phone does. `WatchUVModel.refresh()` goes straight to
/// CoreLocation and WeatherKit with no cache and no sample provider behind it, so on a
/// simulator it can only ever land in `.denied` or `.failed`. Without a seam the only watch
/// screenshot obtainable is a picture of an error state.
enum WatchScreenshotSeed {
    /// True when the process was launched with `-screenshotMode`, resolved once per process.
    static let isActive = ProcessInfo.processInfo.arguments.contains("-screenshotMode")

    /// Bodrum at UV 8, matching the phone seed so the two screenshot sets agree with each other.
    static let phase = WatchUVModel.Phase.loaded(
        uvIndex: 8,
        placeName: "Bodrum",
        temperature: Measurement(value: 31, unit: .celsius)
    )
}
#endif
