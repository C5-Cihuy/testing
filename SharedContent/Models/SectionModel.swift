import Foundation
import SwiftData

/// Account Model
///
/// - Parameters:
///   - colorHex: ``String``.
///   - name: ``String``.
///   - order: ``Int?``.
///   - icon: ``Icon``.
///   - currency: ``Currency``.
///   - parrentAccount: ``Account?``.
@Model
final class SectionModel: ActiveRecord {
    var id: UUID

    var name: String

    var order: Int

    var nashvile: String
    var note: String

    // Many-to-one: many Sections can belong to one Song
    var song: SongModel

    init(
        id: UUID = UUID(),
        name: String,
        order: Int = 0,
        nashvile: String = "",
        note: String = "",
        song: SongModel,
    ) {
        self.id = id

        self.name = name

        self.order = order

        self.nashvile = nashvile
        self.note = note

        self.song = song
    }
}
