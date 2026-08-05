import SwiftData
import SwiftUI

/// Logs a session that happened outside the timer: a beach day the user forgot to start, or
/// time from before they installed the app.
struct ManualSessionEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var activeStore = ActiveProfileStore()

    @State private var date = Date.now
    @State private var durationMinutes: Double = 30
    @State private var placeName = ""
    @State private var spf = 30
    @State private var uvIndex: Double = 6
    @FocusState private var isPlaceNameFocused: Bool

    private var profile: UserProfile? { activeStore.profile(in: profiles) }
    private var skinType: SkinType { profile?.skinType ?? .iii }

    private var duration: Duration { .seconds(durationMinutes * 60) }

    private var estimatedDose: Double {
        ExposureCalculator.dose(uvIndex: uvIndex, over: duration, spf: spf)
    }

    private var estimatedBurnRisk: Double {
        ExposureCalculator.burnRisk(dose: estimatedDose, skinType: skinType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Where") {
                    TextField("Place name", text: $placeName)
                        .focused($isPlaceNameFocused)
                        .submitLabel(.done)
                        .onSubmit { isPlaceNameFocused = false }
                }

                Section("Duration") {
                    Slider(value: $durationMinutes, in: 5...240, step: 5) {
                        Text("Duration")
                    }
                    Text(SafeExposureCard.format(duration))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Section("Protection and UV") {
                    Stepper("SPF \(spf.formatted())", value: $spf, in: 1...50, step: 5)
                    Stepper("UV indeksi \(Int(uvIndex.rounded()))", value: $uvIndex, in: 0...12, step: 1)
                }

                Section {
                    LabeledContent("Estimated burn threshold") {
                        Text(estimatedBurnRisk.formatted(.percent.precision(.fractionLength(0)).locale(.app)))
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("This session was not measured at the time, so it is estimated roughly from real UV data.")
                }

                MedicalDisclaimer()
                    .listRowSeparator(.hidden)
            }
            .navigationTitle("Add a session")
            .navigationBarTitleDisplayMode(.inline)
            // The keyboard covered the SPF and UV fields with no way out. Two escapes now:
            // dragging the form dismisses it, and a Done button sits pinned above the keys.
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(placeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isPlaceNameFocused = false }
                }
            }
        }
    }

    private func save() {
        let session = TanSession(
            startedAt: date,
            endedAt: date.addingTimeInterval(duration.seconds),
            placeName: placeName.trimmingCharacters(in: .whitespaces),
            spf: spf,
            skinType: skinType,
            erythemalDose: estimatedDose,
            peakUVIndex: uvIndex
        )
        modelContext.insert(session)
        dismiss()
    }
}

#Preview {
    ManualSessionEntryView()
        .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
