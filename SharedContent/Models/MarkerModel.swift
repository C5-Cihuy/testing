import Foundation
import SwiftData

/// A section boundary imported from the session's MIDI file.
///
/// Markers are matched to the session's flattened section sequence by `order`.
/// Their positions use sixteenth notes so they can be compared directly with
/// MIDI Song Position Pointer and MIDI Clock transport state.
@Model
final class MarkerModel: ActiveRecord {
    // MARK: - Identity

    var id: UUID

    // MARK: - Position

    /// The marker's zero-based position in the session's marker sequence.
    var order: Int

    /// Absolute position in sixteenth notes from the MIDI timeline's start.
    var position: Int

    // MARK: - Relationships

    var session: SessionModel

    init(
        id: UUID = UUID(),
        order: Int,
        position: Int,
        session: SessionModel
    ) {
        self.id = id
        self.order = order
        self.position = position
        self.session = session
    }
}
