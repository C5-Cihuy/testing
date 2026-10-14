import Foundation
import Testing
@testable import MultiPeerMessaging

private struct TestMessage: PeerToPeerMessage { let text: String }

@Test("sending without a connection reports an error")
func disconnectedSend() async throws {
    // Arrange
    let configuration = try MessagingConfiguration(sessionID: "room", peerID: UUID())
    let server = Server<TestMessage>(configuration: configuration)
    let client = Client<TestMessage>(configuration: configuration)
    // Act / Assert
    await #expect(throws: MessagingError.notConnected) { try await server.send(TestMessage(text: "ping"), to: UUID()) }
    await #expect(throws: MessagingError.notConnected) { try await client.send(TestMessage(text: "ping")) }
    #expect(await server.broadcast(TestMessage(text: "ping")).isEmpty)
}
