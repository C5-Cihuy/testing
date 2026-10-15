import Foundation

/// Server bookkeeping, independent of transport and keychain, for deterministic tests.
struct ConnectionRegistry: Sendable {
    private(set) var pending: Set<ConnectionID> = []
    private(set) var peers: [ConnectionID: UUID] = [:]
    let limit: Int

    mutating func reserve(_ id: ConnectionID) throws {
        guard pending.count + peers.count < limit else { throw MessagingError.clientLimitReached }
        pending.insert(id)
    }

    mutating func authenticate(_ id: ConnectionID, peerID: UUID) throws {
        guard pending.contains(id) else { throw MessagingError.notConnected }
        guard !peers.values.contains(peerID) else { throw MessagingError.duplicatePeer }
        pending.remove(id)
        peers[id] = peerID
    }

    @discardableResult
    mutating func remove(_ id: ConnectionID) -> Bool {
        let wasPending = pending.remove(id) != nil
        return peers.removeValue(forKey: id) != nil || wasPending
    }
}
