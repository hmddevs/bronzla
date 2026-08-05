import Foundation

extension Locale {
    /// The locale whose numeric conventions match the language Bronzla is actually displaying,
    /// not the device's Region setting.
    ///
    /// `Locale.current` mixes two independent iOS settings: unit and plural words follow
    /// Language, but symbol placement (percent sign, decimal separator) follows Region. On a
    /// device set to English language with Turkish region, a common setup for a Turkish user
    /// running an English-language app, that split is invisible for words but not for symbols:
    /// duration formatting reads "1 hr 25 min" (language-driven, correct), while burn-risk
    /// formatting reads "%0" instead of "0%" (region-driven, wrong next to English text).
    /// Deriving the formatting locale from the resolved display language instead keeps both in
    /// step with what is actually on screen.
    static var app: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }
}
