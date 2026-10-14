import Foundation

enum WireEnvelope<Message: PeerToPeerMessage>: Codable, Sendable, Hashable {
    case hello(version: Int, sessionID: String, peerID: UUID)
    case message(Message)

    func validateHello(configuration: MessagingConfiguration, certificatePeerID: UUID) throws -> UUID {
        guard case let .hello(version, sessionID, peerID) = self,
              version == 1, sessionID == configuration.sessionID,
              peerID == certificatePeerID, peerID != configuration.peerID else {
            throw MessagingError.invalidHandshake
        }
        return peerID
    }
}
