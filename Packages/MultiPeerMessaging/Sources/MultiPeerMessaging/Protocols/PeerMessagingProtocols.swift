/// Application message payloads must support JSON coding and safe actor transfer.
public protocol PeerToPeerMessage: Codable, Sendable, Hashable {}
