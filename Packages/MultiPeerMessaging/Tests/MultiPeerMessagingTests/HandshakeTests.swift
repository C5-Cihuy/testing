import Foundation
import Testing
@testable import MultiPeerMessaging

private struct TestMessage: PeerToPeerMessage { let text: String }

@Test("hello binds session and protocol version to the authenticated certificate")
func helloValidation() throws {
    // Arrange
    let config = try MessagingConfiguration(sessionID: "room", peerID: UUID())
    let peer = UUID()
    let sut = WireEnvelope<TestMessage>.hello(version: 1, sessionID: "room", peerID: peer)
    // Act / Assert
    #expect(try sut.validateHello(configuration: config, certificatePeerID: peer) == peer)
    #expect(throws: MessagingError.invalidHandshake) {
        try sut.validateHello(configuration: config, certificatePeerID: UUID())
    }
    for invalid in [WireEnvelope<TestMessage>.hello(version: 2, sessionID: "room", peerID: peer),
                    .hello(version: 1, sessionID: "other", peerID: peer),
                    .message(TestMessage(text: "before hello"))] {
        #expect(throws: MessagingError.invalidHandshake) {
            try invalid.validateHello(configuration: config, certificatePeerID: peer)
        }
    }
}

@Test("wire messages round-trip through JSON")
func wireRoundTrip() throws {
    // Arrange
    let sut = WireEnvelope<TestMessage>.message(TestMessage(text: "hello"))
    // Act
    let decoded = try JSONDecoder().decode(WireEnvelope<TestMessage>.self, from: JSONEncoder().encode(sut))
    // Assert
    #expect(decoded == sut)
}
