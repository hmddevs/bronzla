import PhotosUI
import SwiftData
import SwiftUI

/// Full record of one session: what happened, a place to add photos, and editable notes.
///
/// Notes bind straight to the `@Model` instance, matching the rest of the app's stance that
/// SwiftData objects are the source of truth; there is no separate draft state to reconcile.
struct SessionDetailView: View {
    @Bindable var session: TanSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TanSession.startedAt) private var allSessions: [TanSession]

    @State private var photoStore = SessionPhotoStore()
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var isConfirmingDelete = false

    private var risk: Double { session.burnRisk }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                summaryCard
                burnRiskCard
                photosCard
                notesCard
                MedicalDisclaimer()

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete session", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(Spacing.l)
        }
        .navigationTitle(session.startedAt.formatted(.dateTime.day().month(.wide).year()))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadThumbnails() }
        .onChange(of: pickerSelection) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                await addPhotos(newValue)
                pickerSelection = []
            }
        }
        .alert("Delete this session?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) { deleteSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Cards

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            detailRow("Place", session.placeName.isEmpty ? "Belirtilmedi" : session.placeName)
            Divider()
            detailRow("Duration", SafeExposureCard.format(session.duration))
            Divider()
            detailRow("Peak UV", Int(session.peakUVIndex.rounded()).formatted())
            Divider()
            detailRow("SPF", session.spf.formatted())
            Divider()
            detailRow("Skin type", session.skinType.numeral)
        }
        .cardSurface()
    }

    private var burnRiskCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Image(systemName: risk < 1 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(risk < 1 ? Palette.colour(for: .low) : Palette.colour(for: .veryHigh))
                Text("Burn threshold")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(risk.formatted(.percent.precision(.fractionLength(0)).locale(.app)))
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
            }

            Text("Shows what percentage of the estimated dose at which your skin starts to redden you received. At 100% and above, reddening is expected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Photos")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                PhotosPicker(selection: $pickerSelection, matching: .images) {
                    // An Image with an explicit accessibility label, rather than a Label with
                    // `.labelStyle(.iconOnly)`: PhotosPicker's label closure is Sendable, and
                    // `.iconOnly` is main-actor isolated, so referencing it there is a data
                    // race the compiler is right to flag.
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .accessibilityLabel(Text("Add"))
                }
            }

            if session.photoFileNames.isEmpty {
                Text("No photos added yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s) {
                        ForEach(session.photoFileNames, id: \.self) { filename in
                            photoThumbnail(filename)
                        }
                    }
                }

                if session.photoFileNames.count >= 2 {
                    ShareCardButton(
                        content: .progress(days: progressStats.days, sessions: progressStats.sessions),
                        beforeImage: thumbnails[session.photoFileNames.first!],
                        afterImage: thumbnails[session.photoFileNames.last!]
                    )
                }
            }
        }
        .cardSurface()
    }

    /// Days since the first ever logged session, and sessions logged up to and including this
    /// one: the two numbers a before/after photo pair is meant to answer "how long did this take".
    private var progressStats: (days: Int, sessions: Int) {
        guard let first = allSessions.first else { return (1, 1) }
        let days = Calendar.current.dateComponents([.day], from: first.startedAt, to: session.startedAt).day ?? 0
        let count = allSessions.filter { $0.startedAt <= session.startedAt }.count
        return (max(days + 1, 1), max(count, 1))
    }

    private func photoThumbnail(_ filename: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = thumbnails[filename] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Palette.cardElevated)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(.rect(cornerRadius: Spacing.s))

            Button {
                deletePhoto(filename)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .padding(4)
        }
        .accessibilityElement(children: .combine)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Add a note about this session", text: $session.notes, axis: .vertical)
                .lineLimit(3...8)
        }
        .cardSurface()
    }

    private func detailRow(_ title: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Photo I/O

    private func loadThumbnails() async {
        for filename in session.photoFileNames where thumbnails[filename] == nil {
            guard let data = await photoStore.loadData(named: filename), let image = UIImage(data: data) else {
                continue
            }
            thumbnails[filename] = image
        }
    }

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let encoded = SessionPhotoStore.encodeJPEG(from: uiImage) else {
                continue
            }
            guard let filename = try? await photoStore.save(encoded) else { continue }
            session.photoFileNames.append(filename)
            thumbnails[filename] = UIImage(data: encoded)
        }
    }

    private func deletePhoto(_ filename: String) {
        session.photoFileNames.removeAll { $0 == filename }
        thumbnails.removeValue(forKey: filename)
        Task { await photoStore.delete(named: filename) }
    }

    private func deleteSession() {
        let filenames = session.photoFileNames
        modelContext.delete(session)
        Task {
            for filename in filenames {
                await photoStore.delete(named: filename)
            }
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: TanSession(
            startedAt: .now.addingTimeInterval(-3600),
            endedAt: .now,
            placeName: "Çeşme",
            spf: 30,
            skinType: .iii,
            erythemalDose: 250,
            peakUVIndex: 8,
            notes: "Harika bir gündü."
        ))
    }
    .modelContainer(for: [UserProfile.self, TanSession.self], inMemory: true)
}
