import SwiftUI

// MARK: - Session List

struct SessionListView: View {
    // MARK: State

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var sessions: [SessionListItem]
    @State private var searchText = ""

    // MARK: Initialization

    init(sessions: [SessionListItem] = []) {
        _sessions = State(initialValue: sessions)
    }

    // MARK: View

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SessionListHeader(
                    onBack: { dismiss() },
                    onCreate: { router.presentSheet(.createSession) },
                    onJoin: { router.presentSheet(.joinSession) }
                )

                SessionSearchField(text: $searchText)
                    .padding(.top, 24)

                SessionListContent(
                    sessions: filteredSessions,
                    onDelete: delete
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Derived Data

    private var filteredSessions: [SessionListItem] {
        guard !searchText.isEmpty else { return sessions }

        return sessions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: Actions

    private func delete(_ session: SessionListItem) {
        // Persistence will replace this local mutation when the backend is connected.
        sessions.removeAll { $0.id == session.id }
    }
}

// MARK: - Presentation Model

/// Display-ready session data used while the screen is independent of persistence.
struct SessionListItem: Identifiable, Hashable {
    let id: String
    let name: String
    let songCount: Int
    let lastUpdatedText: String

    init(
        id: String = UUID().uuidString,
        name: String,
        songCount: Int,
        lastUpdatedText: String
    ) {
        self.id = id
        self.name = name
        self.songCount = songCount
        self.lastUpdatedText = lastUpdatedText
    }
}

// MARK: - Components

private struct SessionListHeader: View {
    let onBack: () -> Void
    let onCreate: () -> Void
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColors.primaryForeground)
                    .frame(width: 54, height: 54)
                    .background(AppColors.primary, in: Circle())
            }
            .accessibilityLabel("Back")

            Label("Session List", systemImage: "music.note.list")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColors.cardForeground)

            Spacer()

            Menu {
                Button("Create session", systemImage: "plus") {
                    onCreate()
                }

                Button("Join session", systemImage: "person.2") {
                    onJoin()
                }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(AppColors.cardForeground)
            }
            .accessibilityLabel("Session actions")
            .accessibilityHint("Shows options to create or join a session")
        }
    }
}

private struct SessionSearchField: View {
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
                .accessibilityLabel("Search sessions")

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
        }
    }
}

private struct SessionListContent: View {
    let sessions: [SessionListItem]
    let onDelete: (SessionListItem) -> Void

    var body: some View {
        if sessions.isEmpty {
            SessionEmptyState()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(sessions) { session in
                SessionRow(session: session)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppColors.card)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        // The destructive role supplies the native red swipe treatment.
                        Button(role: .destructive) {
                            onDelete(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 52, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }
}

private struct SessionRow: View {
    let session: SessionListItem

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                    .foregroundStyle(AppColors.cardForeground)
                    .lineLimit(1)

                Text("\(session.songCount) \(session.songCount == 1 ? "Song" : "Songs")")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedForeground)
            }

            Spacer(minLength: 16)

            Text(session.lastUpdatedText)
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedForeground)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Divider()
                .foregroundStyle(AppColors.muted)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SessionEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(AppColors.mutedForeground)
                .frame(width: 56, height: 56)
                .background(AppColors.muted, in: Circle())
                .accessibilityHidden(true)

            Text("No sessions yet")
                .font(.title2.bold())
                .foregroundStyle(AppColors.cardForeground)

            Text("Add a song list first to start a session")
                .font(.title3)
                .foregroundStyle(AppColors.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview Data

private extension SessionListItem {
    static let previewSessions: [SessionListItem] = [
        SessionListItem(
            id: "preview-wedding-tiu",
            name: "Wedding Tiu",
            songCount: 6,
            lastUpdatedText: "1 hour ago"
        ),
        SessionListItem(
            id: "preview-friday-rehearsal",
            name: "Friday Night Rehearsal",
            songCount: 12,
            lastUpdatedText: "Yesterday"
        ),
        SessionListItem(
            id: "preview-acoustic-set",
            name: "Acoustic Set",
            songCount: 4,
            lastUpdatedText: "3 days ago"
        )
    ]
}

// MARK: - Previews

#Preview("Empty state") {
    NavigationStack {
        SessionListView()
            .environment(AppRouter())
    }
}

#Preview("Filled state") {
    NavigationStack {
        SessionListView(sessions: SessionListItem.previewSessions)
            .environment(AppRouter())
    }
}
