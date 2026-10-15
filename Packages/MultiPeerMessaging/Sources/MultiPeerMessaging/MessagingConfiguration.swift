import Foundation
public struct MessagingConfiguration: Sendable {
    public let sessionID: String
    /// Persist this UUID across launches. Never use the session ID as the peer identity.
    public let peerID: UUID
    public let serviceType: String
    public let alpn: String
    public let maximumClients: Int
    public let handshakeTimeout: Duration

    public init(sessionID: String, peerID: UUID, serviceType: String = "_multipeer._udp",
                alpn: String = "multipeer-v1", maximumClients: Int = 8,
                handshakeTimeout: Duration = .seconds(15)) throws {
        guard !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              sessionID.utf8.count <= 128, maximumClients > 0,
              handshakeTimeout > .zero, !alpn.isEmpty, alpn.utf8.count <= 255,
              serviceType.hasPrefix("_"), serviceType.hasSuffix("._udp") else {
            throw MessagingError.invalidConfiguration
        }
        self.sessionID = sessionID
        self.peerID = peerID
        self.serviceType = serviceType
        self.alpn = alpn
        self.maximumClients = maximumClients
        self.handshakeTimeout = handshakeTimeout
    }
}
