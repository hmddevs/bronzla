import SwiftUI

/// Manual place selection: the fallback when location is denied, and the primary path when
/// planning a trip to the coast.
struct PlacePickerView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var groups: [(region: String, entries: [TurkishPlaces.Entry])] {
        guard !searchText.isEmpty else { return TurkishPlaces.grouped }
        return TurkishPlaces.grouped.compactMap { group in
            let matches = group.entries.filter {
                $0.name.localizedStandardContains(searchText)
            }
            return matches.isEmpty ? nil : (group.region, matches)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if locationService.manualPlace != nil {
                    Section {
                        Button("Use my location", systemImage: "location.fill") {
                            locationService.manualPlace = nil
                            locationService.requestLocation()
                            dismiss()
                        }
                    }
                }

                ForEach(groups, id: \.region) { group in
                    Section(group.region) {
                        ForEach(group.entries) { entry in
                            Button {
                                locationService.manualPlace = entry.place
                                dismiss()
                            } label: {
                                HStack {
                                    Text(entry.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if locationService.manualPlace?.name == entry.name {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text("Search for a city"))
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PlacePickerView()
        .environment(LocationService())
}
