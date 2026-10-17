import Foundation
import SwiftData

/// One ordered occurrence of a song in a performance session.
///
/// Keeping this as a separate model allows the same song to appear more than
/// once in a session without changing the song library's data.
@Model
final class SetlistEntryModel: ActiveRecord {
    // MARK: - Identity

    var id: UUID

    // MARK: - Position

    /// The entry's zero-based position in its session's setlist.
    var order: Int

    // MARK: - Relationships

    var session: SessionModel
    var song: SongModel

    init(
        id: UUID = UUID(),
        order: Int,
        session: SessionModel,
        song: SongModel,
    ) {
        self.id = id
        self.order = order
        self.session = session
        self.song = song
    }
}
