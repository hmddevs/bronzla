import Foundation

/// A published source behind one of the app's times, thresholds or pieces of advice.
///
/// Apple's 1.4.1 review guideline requires medical information to carry citations that are
/// "easy for the user to find", not merely present somewhere in the app. `MedicalSource.all` is
/// the single canonical catalogue; `MedicalSourcesView` renders it and is reachable in one tap
/// from every screen that shows exposure guidance, via `MedicalDisclaimer`.
struct MedicalSource: Identifiable, Sendable {
    /// Stable across app launches; used only for `Identifiable`, never shown to the user.
    let id: String
    let title: String
    /// Author list or issuing organisation, as it would appear in a citation.
    let authors: String
    /// Journal, standard number or publisher detail, kept separate from the year for layout.
    let publicationDetail: String
    /// `nil` for web pages that carry no publication date; never guessed.
    let year: Int?
    let url: URL
    /// Plain-language note on what this source backs, shown under the citation.
    let backs: String
    let category: Category

    enum Category: String, CaseIterable, Sendable {
        case uvIndex, skinType, sunscreen, vitaminD, aftercare

        var title: LocalizedStringResource {
            switch self {
            case .uvIndex: "UV index"
            case .skinType: "Skin type"
            case .sunscreen: "Sunscreen"
            case .vitaminD: "Vitamin D"
            case .aftercare: "Aftercare"
            }
        }
    }

    static let all: [MedicalSource] = [
        // MARK: UV index

        MedicalSource(
            id: "who-uv-index",
            title: "Radiation: The Ultraviolet (UV) Index",
            authors: "World Health Organization",
            publicationDetail: "WHO Questions and Answers",
            year: nil,
            url: URL(string: "https://www.who.int/news-room/questions-and-answers/item/radiation-the-ultraviolet-(uv)-index")!,
            backs: "One UV index unit equals 25 mW/m² of erythemally weighted irradiance, and the protection advice for each band.",
            category: .uvIndex
        ),
        MedicalSource(
            id: "icnirp-uv-index",
            title: "UV Index",
            authors: "International Commission on Non-Ionizing Radiation Protection",
            publicationDetail: "ICNIRP",
            year: nil,
            url: URL(string: "https://www.icnirp.org/en/applications/uv-index/index.html")!,
            backs: "The Low, Moderate, High, Very High and Extreme band thresholds.",
            category: .uvIndex
        ),

        // MARK: Skin type

        MedicalSource(
            id: "fitzpatrick-1988",
            title: "The validity and practicality of sun-reactive skin types I through VI",
            authors: "Fitzpatrick TB",
            publicationDetail: "Archives of Dermatology, 124(6), 869-871",
            year: 1988,
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/3377516/")!,
            backs: "The six phototypes and the burning and tanning behaviour described for each.",
            category: .skinType
        ),
        MedicalSource(
            id: "sayre-1981",
            title: "Skin type, minimal erythema dose (MED), and sunlight acclimatization",
            authors: "Sayre RM, Desrochers DL, Wilson CJ, Marlowe E",
            publicationDetail: "Journal of the American Academy of Dermatology, 5(4), 439-443",
            year: 1981,
            url: URL(string: "https://doi.org/10.1016/S0190-9622(81)70106-3")!,
            backs: "The minimal erythemal dose ranges by Fitzpatrick skin type that this app's phototype tiers use.",
            category: .skinType
        ),

        // MARK: Sunscreen

        MedicalSource(
            id: "iso-24444-2019",
            title: "ISO 24444:2019 Cosmetics. Sun protection test methods. In vivo determination of the sun protection factor (SPF)",
            authors: "International Organization for Standardization",
            publicationDetail: "ISO",
            year: 2019,
            url: URL(string: "https://www.iso.org/standard/72250.html")!,
            backs: "SPF is measured at an application rate of 2 mg per square centimetre of skin.",
            category: .sunscreen
        ),
        MedicalSource(
            id: "petersen-wulf-2014",
            title: "Application of sunscreen: theory and reality",
            authors: "Petersen B, Wulf HC",
            publicationDetail: "Photodermatology, Photoimmunology and Photomedicine",
            year: 2014,
            url: URL(string: "https://onlinelibrary.wiley.com/doi/10.1111/phpp.12099")!,
            backs: "People apply far less than the test dose in practice, so real-world protection sits well below the label figure.",
            category: .sunscreen
        ),
        MedicalSource(
            id: "aad-how-to-apply-sunscreen",
            title: "How to apply sunscreen",
            authors: "American Academy of Dermatology",
            publicationDetail: "AAD",
            year: nil,
            url: URL(string: "https://www.aad.org/public/everyday-care/sun-protection/shade-clothing-sunscreen/how-to-apply-sunscreen")!,
            backs: "Reapply every two hours, and immediately after swimming or sweating.",
            category: .sunscreen
        ),
        MedicalSource(
            id: "aad-practice-safe-sun",
            title: "Practice Safe Sun",
            authors: "American Academy of Dermatology",
            publicationDetail: "AAD",
            year: nil,
            url: URL(string: "https://www.aad.org/public/everyday-care/sun-protection/shade-clothing-sunscreen/practice-safe-sun")!,
            backs: "Broad spectrum SPF 30 or higher is recommended for everyone.",
            category: .sunscreen
        ),

        // MARK: Vitamin D

        MedicalSource(
            id: "holick-2011",
            title: "Vitamin D: a D-lightful solution for health",
            authors: "Holick MF",
            publicationDetail: "Journal of Internal Medicine",
            year: 2011,
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/21415774/")!,
            backs: "Whole-body exposure to one minimal erythemal dose is comparable to an oral intake of roughly 10,000 to 25,000 IU.",
            category: .vitaminD
        ),

        // MARK: Aftercare

        MedicalSource(
            id: "aad-how-to-treat-sunburn",
            title: "How to treat a sunburn",
            authors: "American Academy of Dermatology",
            publicationDetail: "AAD",
            year: nil,
            url: URL(string: "https://www.aad.org/public/everyday-care/injured-skin/burns/treat-sunburn")!,
            backs: "Cool baths, aloe vera or soy products, and never popping blisters.",
            category: .aftercare
        ),
        MedicalSource(
            id: "mayo-sunburn-first-aid",
            title: "Sunburn: First aid",
            authors: "Mayo Clinic",
            publicationDetail: "Mayo Clinic",
            year: nil,
            url: URL(string: "https://www.mayoclinic.org/first-aid/first-aid-sunburn/basics/art-20056643")!,
            backs: "Cool compresses, and that applying ice directly damages sunburnt skin.",
            category: .aftercare
        ),
        MedicalSource(
            id: "cleveland-clinic-sunburn-care",
            title: "When to get care for a sunburn",
            authors: "Cleveland Clinic",
            publicationDetail: "Cleveland Clinic",
            year: nil,
            url: URL(string: "https://health.clevelandclinic.org/when-to-get-care-for-a-sunburn")!,
            backs: "When to seek medical care: dehydration, chills, nausea or extensive blistering.",
            category: .aftercare
        ),
    ]
}
