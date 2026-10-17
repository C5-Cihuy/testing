import SwiftUI

// MARK: - Song Picker

struct SongPickerView: View {
    // MARK: State

    @Environment(\.dismiss) private var dismiss

    @State private var songs: [SongPickerItem]
    @State private var selectedSongIDs: Set<String>
    @State private var searchText = ""
    @State private var isCreateSongPresented = false

    private let onDone: ([SongPickerItem]) -> Void

    // MARK: Initialization

    init(
        songs: [SongPickerItem] = [],
        selectedSongIDs: Set<String> = [],
        onDone: @escaping ([SongPickerItem]) -> Void = { _ in }
    ) {
        _songs = State(initialValue: songs)
        _selectedSongIDs = State(initialValue: selectedSongIDs)
        self.onDone = onDone
    }

    // MARK: View

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                SongPickerHeader(
                    onClose: { dismiss() },
                    onDone: finishSelection
                )

                Text("Songs")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColors.cardForeground)

                SongPickerSearchField(text: $searchText)

                SongPickerContent(
                    songs: filteredSongs,
                    selectedSongIDs: selectedSongIDs,
                    onToggleSelection: toggleSelection,
                    onCreateSong: { isCreateSongPresented = true }
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isCreateSongPresented) {
            CreateSongPlaceholderView()
                .presentationSizing(.page)
        }
    }

    // MARK: Derived Data

    private var filteredSongs: [SongPickerItem] {
        guard !searchText.isEmpty else { return songs }

        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: Actions

    private func toggleSelection(_ song: SongPickerItem) {
        if selectedSongIDs.contains(song.id) {
            selectedSongIDs.remove(song.id)
        } else {
            selectedSongIDs.insert(song.id)
        }
    }

    private func finishSelection() {
        let selectedSongs = songs.filter { selectedSongIDs.contains($0.id) }
        onDone(selectedSongs)
        dismiss()
    }
}

// MARK: - Presentation Model

/// Display-ready song data used until the song repository is connected.
struct SongPickerItem: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let key: String
    let beatsPerMinute: Int
    let timeSignature: String

    init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        key: String,
        beatsPerMinute: Int,
        timeSignature: String
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.key = key
        self.beatsPerMinute = beatsPerMinute
        self.timeSignature = timeSignature
    }
}

// MARK: - Components

/// Temporary modal content until the create-song feature is implemented.
private struct CreateSongPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(AppColors.primary)

            Text("Create Song")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColors.foreground)

            Text("The create-song form will be added here.")
                .font(.title3)
                .foregroundStyle(AppColors.mutedForeground)
                .multilineTextAlignment(.center)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

private struct SongPickerHeader: View {
    let onClose: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack {
            SongPickerCircleButton(
                title: "Close",
                systemImage: "xmark",
                action: onClose
            )

            Spacer()

            SongPickerCircleButton(
                title: "Done",
                systemImage: "checkmark",
                action: onDone
            )
        }
    }
}

private struct SongPickerCircleButton: View {
    let title: LocalizedStringResource
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(AppColors.primaryForeground)
                .frame(width: 58, height: 58)
                .background(AppColors.primary, in: Circle())
        }
        .accessibilityLabel(title)
    }
}

private struct SongPickerSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .accessibilityHidden(true)

            TextField("Search", text: $text)
                .font(.headline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Search songs")

            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(AppColors.mutedForeground)
            }
        }
        .foregroundStyle(AppColors.cardForeground)
        .padding(.horizontal, 20)
        .frame(minHeight: 56)
        .background(AppColors.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.cardForeground.opacity(0.55), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct SongPickerContent: View {
    let songs: [SongPickerItem]
    let selectedSongIDs: Set<String>
    let onToggleSelection: (SongPickerItem) -> Void
    let onCreateSong: () -> Void

    var body: some View {
        Group {
            if songs.isEmpty {
                SongPickerEmptyState(onCreateSong: onCreateSong)
            } else {
                List(songs) { song in
                    SongPickerRow(
                        song: song,
                        isSelected: selectedSongIDs.contains(song.id),
                        onToggleSelection: { onToggleSelection(song) }
                    )
                    .listRowInsets(
                        EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppColors.secondary)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.cardForeground.opacity(0.7), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct SongPickerRow: View {
    let song: SongPickerItem
    let isSelected: Bool
    let onToggleSelection: () -> Void

    var body: some View {
        Button(action: onToggleSelection) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(song.title) · \(song.artist)")
                        .font(.headline)
                        .foregroundStyle(AppColors.accentForeground)
                        .lineLimit(1)

                    Text("\(song.key) · \(song.beatsPerMinute) BPM · \(song.timeSignature)")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.accentForeground.opacity(0.75))
                        .lineLimit(1)

                    Divider()
                        .overlay(AppColors.accentForeground.opacity(0.2))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(
                        isSelected
                            ? AppColors.accentForeground
                            : AppColors.accentForeground.opacity(0.45)
                    )
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(AppColors.accent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(song.title) by \(song.artist), \(isSelected ? "selected" : "not selected")"
        )
        .accessibilityHint("Double tap to toggle selection")
    }
}

private struct SongPickerEmptyState: View {
    let onCreateSong: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onCreateSong) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(AppColors.primaryForeground)
                    .frame(width: 56, height: 56)
                    .background(AppColors.primary, in: Circle())
            }
            .accessibilityLabel("Create song")

            Text("No song list yet")
                .font(.title2.bold())
                .foregroundStyle(AppColors.cardForeground)

            Text("Add a song first to start a session")
                .font(.title3)
                .foregroundStyle(AppColors.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview Data

extension SongPickerItem {
    static let previewSongs: [SongPickerItem] = [
        SongPickerItem(
            id: "picker-alexandra",
            title: "Alexandra",
            artist: "Reality Club",
            key: "C",
            beatsPerMinute: 120,
            timeSignature: "4/4"
        ),
        SongPickerItem(
            id: "picker-anything-you-want",
            title: "Anything You Want",
            artist: "Reality Club",
            key: "D",
            beatsPerMinute: 112,
            timeSignature: "4/4"
        ),
        SongPickerItem(
            id: "picker-sorai",
            title: "Sorai",
            artist: "Nadin Amizah",
            key: "G",
            beatsPerMinute: 96,
            timeSignature: "4/4"
        ),
        SongPickerItem(
            id: "picker-every-summertime",
            title: "Every Summertime",
            artist: "NIKI",
            key: "A",
            beatsPerMinute: 105,
            timeSignature: "4/4"
        )
    ]
}

// MARK: - Previews

#Preview("Empty state") {
    NavigationStack {
        SongPickerView()
    }
}

#Preview("Filled state") {
    NavigationStack {
        SongPickerView(
            songs: SongPickerItem.previewSongs,
            selectedSongIDs: Set(SongPickerItem.previewSongs.map(\.id))
        )
    }
}
