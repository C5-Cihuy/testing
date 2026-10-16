import Foundation
import SwiftData

/// The persisted lifecycle of a prepared performance session.
enum SessionStatus: String, Codable {
    case draft
    case active
    case ended
}

/// A reusable, ordered setlist that can be hosted for other musicians.
///
/// The model owns its setlist entries and imported MIDI markers. Live transport
/// state and connected devices are intentionally kept outside persistence.
@Model
final class SessionModel: ActiveRecord {
    // MARK: - Identity

    var id: UUID
    var name: String

    // MARK: - Lifecycle

    var status: SessionStatus

    /// The PIN used to join an active session. It is nil while draft or ended.
    var roomPIN: String?

    var createdAt: Date

    /// The time the host ended the session. It is nil until the session ends.
    var endedAt: Date?

    // MARK: - Imported MIDI

    /// The original filename, retained for display and troubleshooting.
    var midiFileName: String?

    /// The original MIDI file. Markers use normalized sixteenth-note positions.
    @Attribute(.externalStorage)
    var midiFileData: Data?

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \SetlistEntryModel.session)
    var setlistEntries: [SetlistEntryModel] = []

    @Relationship(deleteRule: .cascade, inverse: \MarkerModel.session)
    var markers: [MarkerModel] = []

    init(
        id: UUID = UUID(),
        name: String,
        status: SessionStatus = .draft,
        roomPIN: String? = nil,
        createdAt: Date = .now,
        endedAt: Date? = nil,
        midiFileName: String? = nil,
        midiFileData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.roomPIN = roomPIN
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.midiFileName = midiFileName
        self.midiFileData = midiFileData
    }
}
