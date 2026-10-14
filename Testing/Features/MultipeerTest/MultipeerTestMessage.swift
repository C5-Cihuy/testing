import Foundation
import MultiPeerMessaging

nonisolated struct MultipeerTestMessage: MultiPeerMessaging.PeerToPeerMessage {
    enum Kind: String, Codable, Sendable { case ping, acknowledgment, text }
    let id: UUID
    let kind: Kind
    let text: String
}
