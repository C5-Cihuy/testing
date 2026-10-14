import Foundation
import Testing
@testable import MultiPeerMessaging

@Test("invalid configuration is rejected")
func invalidConfiguration() {
    // Arrange / Act / Assert
    #expect(throws: MessagingError.invalidConfiguration) {
        try MessagingConfiguration(sessionID: " ", peerID: UUID())
    }
    #expect(throws: MessagingError.invalidConfiguration) {
        try MessagingConfiguration(sessionID: "room", peerID: UUID(), maximumClients: 0)
    }
    #expect(throws: MessagingError.invalidConfiguration) {
        try MessagingConfiguration(sessionID: "room", peerID: UUID(), handshakeTimeout: .zero)
    }
}
