import Foundation
import SwiftData
import SwiftUI

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
final class SessionModel: ActiveRecord {
    var id: UUID

    var name: String

    @Relationship(deleteRule: .cascade, inverse: \SetlistEntryModel.session)
    var setlistEntries: [SetlistEntryModel] = []

    init(
        id: UUID = UUID(),
        name: String,
    ) {
        self.id = id

        self.name = name
    }
}
