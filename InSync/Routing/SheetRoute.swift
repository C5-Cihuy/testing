import Foundation

enum SheetRoute: Identifiable, Hashable {
    case placeholder
    case createSession
    case joinSession

    var id: Self { self }
}
