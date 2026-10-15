import Foundation
import Testing
@testable import MultiPeerMessaging

@Test("multiple clients authenticate independently")
func multipleClients() throws {
    // Arrange
    var sut = ConnectionRegistry(limit: 2)
    let first = UUID(), second = UUID()
    // Act
    try sut.reserve(first)
    try sut.reserve(second)
    try sut.authenticate(first, peerID: UUID())
    try sut.authenticate(second, peerID: UUID())
    // Assert
    #expect(sut.peers.count == 2)
    #expect(sut.pending.isEmpty)
}

@Test("disconnecting one client preserves the other and frees capacity")
func disconnectIsolation() throws {
    // Arrange
    var sut = ConnectionRegistry(limit: 2)
    let first = UUID(), second = UUID(), reconnect = UUID(), peer = UUID()
    try sut.reserve(first)
    try sut.reserve(second)
    try sut.authenticate(first, peerID: peer)
    try sut.authenticate(second, peerID: UUID())
    // Act
    sut.remove(first)
    try sut.reserve(reconnect)
    try sut.authenticate(reconnect, peerID: peer)
    // Assert
    #expect(sut.peers[second] != nil)
    #expect(sut.peers[reconnect] == peer)
    let removedOldConnection = sut.remove(first)
    #expect(!removedOldConnection)
    #expect(sut.peers.count == 2)
}

@Test("pending handshakes count toward the client limit")
func pendingLimit() throws {
    // Arrange
    var sut = ConnectionRegistry(limit: 1)
    try sut.reserve(UUID())
    // Act / Assert
    #expect(throws: MessagingError.clientLimitReached) { try sut.reserve(UUID()) }
}

@Test("duplicate active peer identities are rejected")
func duplicatePeer() throws {
    // Arrange
    var sut = ConnectionRegistry(limit: 2)
    let first = UUID(), second = UUID(), peer = UUID()
    try sut.reserve(first)
    try sut.reserve(second)
    try sut.authenticate(first, peerID: peer)
    // Act / Assert
    #expect(throws: MessagingError.duplicatePeer) { try sut.authenticate(second, peerID: peer) }
    #expect(sut.peers[first] == peer)
}
