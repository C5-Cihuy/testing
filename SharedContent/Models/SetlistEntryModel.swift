import Foundation
import SwiftData

/// One occurrence of a song in a performance session.
@Model
final class SetlistEntryModel: ActiveRecord {
    var id: UUID
    
    var order: Int

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
