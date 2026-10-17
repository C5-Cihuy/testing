import SwiftUI

// MARK: - Create Session

struct CreateSessionView: View {
    // MARK: State

    @Environment(\.dismiss) private var dismiss

    @State private var sessionName: String
    @State private var songs: [CreateSessionSongItem]
    @State private var isSongPickerPresented = false
    @State private var isMIDISetupPresented = false

    // MARK: Initialization

    init(
        sessionName: String = "",
        songs: [CreateSessionSongItem] = []
    ) {
        _sessionName = State(initialValue: sessionName)
        _songs = State(initialValue: songs)
    }

    // MARK: View

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                CreateSessionHeader(
                    sessionName: $sessionName,
                    onClose: { dismiss() },
                    onAddSong: { isSongPickerPresented = true }
                )

                CreateSessionContent(
                    songs: songs,
                    onDelete: deleteSong,
                    onMove: moveSong
                )

                CreateSessionFooter(
                    isStartEnabled: canStartSharing,
                    onMIDISetup: { isMIDISetupPresented = true },
                    onStartSharing: {}
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isSongPickerPresented) {
            NavigationStack {
                SongPickerView(
                    songs: SongPickerItem.previewSongs,
                    selectedSongIDs: Set(songs.map(\.id)),
                    onDone: addSelectedSongs
                )
            }
            .presentationSizing(.page)
        }
        .sheet(isPresented: $isMIDISetupPresented) {
            MIDISetupView()
                .presentationSizing(.page)
        }
    }

    // MARK: Derived Data

    private var canStartSharing: Bool {
        !sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !songs.isEmpty
    }

    // MARK: Actions

    private func addSelectedSongs(_ selectedSongs: [SongPickerItem]) {
        let existingIDs = Set(songs.map(\.id))

        for song in selectedSongs where !existingIDs.contains(song.id) {
            songs.append(CreateSessionSongItem(song))
        }
    }

    private func deleteSong(_ song: CreateSessionSongItem) {
        songs.removeAll { $0.id == song.id }
    }

    private func moveSong(from source: IndexSet, to destination: Int) {
        songs.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Presentation Model

/// Display-ready song data used until the song library is connected.
struct CreateSessionSongItem: Identifiable, Hashable {
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

    init(_ song: SongPickerItem) {
        id = song.id
        title = song.title
        artist = song.artist
        key = song.key
        beatsPerMinute = song.beatsPerMinute
        timeSignature = song.timeSignature
    }
}

// MARK: - Components

private struct CreateSessionHeader: View {
    @Binding var sessionName: String

    let onClose: () -> Void
    let onAddSong: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            CreateSessionCircleButton(
                title: "Close",
                systemImage: "xmark",
                action: onClose
            )

            TextField("Session Name", text: $sessionName)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.cardForeground)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(AppColors.cardForeground)
                }
                .submitLabel(.done)
                .accessibilityLabel("Session name")

            CreateSessionCircleButton(
                title: "Add song",
                systemImage: "plus",
                action: onAddSong
            )
        }
    }
}

private struct CreateSessionCircleButton: View {
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

private struct CreateSessionContent: View {
    let songs: [CreateSessionSongItem]

    let onDelete: (CreateSessionSongItem) -> Void
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        if songs.isEmpty {
            CreateSessionEmptyState()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(songs) { song in
                    CreateSessionSongRow(
                        song: song,
                        onDelete: { onDelete(song) }
                    )
                    .listRowInsets(
                        EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 8)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppColors.card)
                }
                .onMove(perform: onMove)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            // Edit mode exposes only the native reorder handle because deletion
            // is owned by the explicit minus button in each row.
            .environment(\.editMode, .constant(.active))
            .padding(.top, 20)
        }
    }
}

private struct CreateSessionSongRow: View {
    let song: CreateSessionSongItem
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onDelete) {
                Image(systemName: "minus")
                    .font(.caption.bold())
                    .foregroundStyle(AppColors.mutedForeground)
                    .frame(width: 36, height: 36)
                    .background(AppColors.muted, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(song.title)")

            VStack(alignment: .leading, spacing: 6) {
                Text("\(song.title) · \(song.artist)")
                    .font(.headline)
                    .foregroundStyle(AppColors.secondaryForeground)
                    .lineLimit(1)

                Text("\(song.key) · \(song.beatsPerMinute) BPM · \(song.timeSignature)")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedForeground)
                    .lineLimit(1)

                Divider()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(song.title) by \(song.artist), key \(song.key), \(song.beatsPerMinute) beats per minute, \(song.timeSignature)"
            )

        }
    }
}

private struct CreateSessionEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundStyle(AppColors.mutedForeground)
                .frame(width: 56, height: 56)
                .background(AppColors.muted, in: Circle())
                .accessibilityHidden(true)

            Text("No song list yet")
                .font(.title2.bold())
                .foregroundStyle(AppColors.cardForeground)

            Text("Choose a song first")
                .font(.title3)
                .foregroundStyle(AppColors.mutedForeground)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

private struct CreateSessionFooter: View {
    let isStartEnabled: Bool
    let onMIDISetup: () -> Void
    let onStartSharing: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button("MIDI Setup (Optional)", action: onMIDISetup)
                .accessibilityHint("Opens optional MIDI configuration")

            Button("Start Sharing", action: onStartSharing)
                .disabled(!isStartEnabled)
                .accessibilityHint(
                    isStartEnabled
                        ? "Starts sharing this session"
                        : "Enter a session name and add at least one song first"
                )
        }
        .font(.title2)
        .buttonStyle(CreateSessionActionButtonStyle())
        .padding(.top, 20)
    }
}

private struct CreateSessionActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(AppColors.primaryForeground)
            .background(AppColors.primary.opacity(configuration.isPressed ? 0.75 : 1))
            .opacity(isEnabled ? 1 : 0.55)
    }
}

// MARK: - Preview Data

private extension CreateSessionSongItem {
    static let sample = CreateSessionSongItem(
        id: "sample-alexandra",
        title: "Alexandra",
        artist: "Reality Club",
        key: "C",
        beatsPerMinute: 120,
        timeSignature: "4/4"
    )

    static let previewSongs: [CreateSessionSongItem] = [
        CreateSessionSongItem(
            id: "preview-alexandra",
            title: "Alexandra",
            artist: "Reality Club",
            key: "C",
            beatsPerMinute: 120,
            timeSignature: "4/4"
        ),
        CreateSessionSongItem(
            id: "preview-anything-you-want",
            title: "Anything You Want",
            artist: "Reality Club",
            key: "D",
            beatsPerMinute: 112,
            timeSignature: "4/4"
        ),
        CreateSessionSongItem(
            id: "preview-sorai",
            title: "Sorai",
            artist: "Nadin Amizah",
            key: "G",
            beatsPerMinute: 96,
            timeSignature: "4/4"
        ),
        CreateSessionSongItem(
            id: "preview-every-summertime",
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
        CreateSessionView()
    }
}

#Preview("Filled state") {
    NavigationStack {
        CreateSessionView(
            sessionName: "Friday Rehearsal",
            songs: CreateSessionSongItem.previewSongs
        )
    }
}
