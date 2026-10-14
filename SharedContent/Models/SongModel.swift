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
final class SongModel: ActiveRecord {
    var id: UUID

    var name: String

    // One-to-many: a Song can have many Sections
    @Relationship(deleteRule: .cascade, inverse: \SectionModel.song)
    var sections: [SectionModel] = []

    @Relationship(deleteRule: .cascade, inverse: \SetlistEntryModel.song)
    var setlistEntries: [SetlistEntryModel] = []

    init(
        id: UUID = UUID(),
        name: String,
    ) {
        self.id = id

        self.name = name
    }
}
