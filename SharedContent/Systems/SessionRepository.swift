import Foundation
import SwiftData

/// Validation failures for session-specific persistence operations.
enum SessionRepositoryError: Error, LocalizedError {
    case emptyName
    case sessionNotEditable
    case setlistEntryNotFound
    case invalidSetlistMove
    case invalidMIDIFile
    case invalidMarkerPositions
    case emptySetlist
    case invalidRoomPIN
    case sessionNotActive

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "The session name cannot be empty."
        case .sessionNotEditable:
            return "Only draft sessions can be edited."
        case .setlistEntryNotFound:
            return "The setlist entry does not belong to this session."
        case .invalidSetlistMove:
            return "The setlist move uses an invalid position."
        case .invalidMIDIFile:
            return "The selected MIDI file is empty or has no filename."
        case .invalidMarkerPositions:
            return "Marker positions must be non-negative and ordered."
        case .emptySetlist:
            return "Add at least one song before starting the session."
        case .invalidRoomPIN:
            return "The room PIN must contain exactly five digits."
        case .sessionNotActive:
            return "Only an active session can be ended."
        }
    }
}

/// Stores and updates a session together with its ordered setlist and MIDI markers.
///
/// Generic CRUD operations come from Repository. The methods below preserve
/// session-specific rules such as draft-only editing and contiguous ordering.
@MainActor
final class SessionRepository: Repository {
    typealias Model = SessionModel

    var persistenceStack: PersistenceStack

    init(persistenceStack: PersistenceStack? = nil) {
        self.persistenceStack = persistenceStack ?? DataBase.shared.persistenceStack
    }

    // MARK: - Session

    /// Creates and persists an empty draft session.
    @discardableResult
    func create(name: String) throws -> SessionModel {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SessionRepositoryError.emptyName
        }

        let session = SessionModel(name: name)
        let context = try modelContext()
        context.insert(session)
        try save(context)
        return session
    }

    /// Returns sessions from newest to oldest for the session list.
    func fetchAllSorted() throws -> [SessionModel] {
        try fetchAll().sorted { $0.createdAt > $1.createdAt }
    }

    /// Returns sessions whose names contain the query, ignoring case.
    /// An empty query returns the complete session list.
    func search(name query: String) throws -> [SessionModel] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return try fetchAllSorted()
        }

        return try fetchAllSorted().filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    /// Renames a draft session.
    func updateName(of session: SessionModel, to name: String) throws {
        try requireDraft(session)

        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SessionRepositoryError.emptyName
        }

        session.name = name
        try save(try modelContext())
    }

    // MARK: - Setlist

    /// Adds another occurrence of a song to the end of a draft session's setlist.
    @discardableResult
    func addSong(_ song: SongModel, to session: SessionModel) throws -> SetlistEntryModel {
        try requireDraft(session)

        let nextOrder = (session.setlistEntries.map(\.order).max() ?? -1) + 1
        let entry = SetlistEntryModel(
            order: nextOrder,
            session: session,
            song: song
        )

        let context = try modelContext()
        context.insert(entry)
        try save(context)
        return entry
    }

    /// Removes one song occurrence and closes the resulting ordering gap.
    func removeSetlistEntry(
        _ entry: SetlistEntryModel,
        from session: SessionModel
    ) throws {
        try requireDraft(session)

        guard entry.session.id == session.id,
              session.setlistEntries.contains(where: { $0.id == entry.id })
        else {
            throw SessionRepositoryError.setlistEntryNotFound
        }

        let context = try modelContext()
        session.setlistEntries.removeAll { $0.id == entry.id }
        context.delete(entry)
        normalizeSetlistOrder(in: session)
        try save(context)
    }

    /// Moves an entry to a final zero-based index and normalizes every order value.
    func moveSetlistEntry(
        in session: SessionModel,
        from sourceIndex: Int,
        to destinationIndex: Int
    ) throws {
        try requireDraft(session)

        var entries = orderedSetlistEntries(in: session)
        guard entries.indices.contains(sourceIndex),
              destinationIndex >= 0,
              destinationIndex < entries.count
        else {
            throw SessionRepositoryError.invalidSetlistMove
        }

        let entry = entries.remove(at: sourceIndex)
        entries.insert(entry, at: destinationIndex)

        for (order, entry) in entries.enumerated() {
            entry.order = order
        }

        try save(try modelContext())
    }

    // MARK: - MIDI Configuration

    /// Stores one MIDI file and its marker positions for a draft session.
    ///
    /// Saving another file replaces the previous file and markers as one operation.
    func saveMIDIConfiguration(
        to session: SessionModel,
        fileName: String,
        fileData: Data,
        markerPositions: [Int]
    ) throws {
        try requireDraft(session)

        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty, !fileData.isEmpty else {
            throw SessionRepositoryError.invalidMIDIFile
        }

        guard !markerPositions.isEmpty,
              markerPositions.allSatisfy({ $0 >= 0 }),
              zip(markerPositions, markerPositions.dropFirst())
                .allSatisfy({ $0 <= $1 })
        else {
            throw SessionRepositoryError.invalidMarkerPositions
        }

        let context = try modelContext()
        session.markers.forEach(context.delete)
        session.markers.removeAll()

        session.midiFileName = fileName
        session.midiFileData = fileData

        let markers = markerPositions.enumerated().map { order, position in
            MarkerModel(
                order: order,
                position: position,
                session: session
            )
        }

        markers.forEach(context.insert)
        session.markers = markers
        try save(context)
    }

    /// Removes the imported MIDI file and all markers from a draft session.
    func removeMIDIConfiguration(from session: SessionModel) throws {
        try requireDraft(session)

        let context = try modelContext()
        session.markers.forEach(context.delete)
        session.markers.removeAll()
        session.midiFileName = nil
        session.midiFileData = nil
        try save(context)
    }

    // MARK: - Lifecycle

    /// Marks a prepared session as active using a five-digit room PIN.
    func activate(_ session: SessionModel, roomPIN: String) throws {
        try requireDraft(session)

        guard !session.setlistEntries.isEmpty else {
            throw SessionRepositoryError.emptySetlist
        }

        let pinBytes = Array(roomPIN.utf8)
        guard pinBytes.count == 5,
              pinBytes.allSatisfy({ $0 >= 48 && $0 <= 57 })
        else {
            throw SessionRepositoryError.invalidRoomPIN
        }

        session.status = .active
        session.roomPIN = roomPIN
        session.endedAt = nil
        try save(try modelContext())
    }

    /// Ends an active session and invalidates its room PIN.
    func end(_ session: SessionModel, at date: Date = .now) throws {
        guard session.status == .active else {
            throw SessionRepositoryError.sessionNotActive
        }

        session.status = .ended
        session.roomPIN = nil
        session.endedAt = date
        try save(try modelContext())
    }

    // MARK: - Helpers

    private func modelContext() throws -> ModelContext {
        guard let context = persistenceStack.context else {
            throw DataLayerError.invalidModelType
        }
        return context
    }

    private func requireDraft(_ session: SessionModel) throws {
        guard session.status == .draft else {
            throw SessionRepositoryError.sessionNotEditable
        }
    }

    private func orderedSetlistEntries(in session: SessionModel) -> [SetlistEntryModel] {
        session.setlistEntries.sorted { $0.order < $1.order }
    }

    private func normalizeSetlistOrder(in session: SessionModel) {
        for (order, entry) in orderedSetlistEntries(in: session).enumerated() {
            entry.order = order
        }
    }

    private func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw DataLayerError.saveFailed(error)
        }
    }
}
