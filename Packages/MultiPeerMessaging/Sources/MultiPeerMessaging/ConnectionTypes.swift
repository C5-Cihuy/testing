import Foundation
import Network

public typealias ConnectionID = UUID

public struct ConnectedPeer: Sendable, Hashable {
    public let connectionID: ConnectionID
    public let peerID: UUID
}

public struct ReceivedMessage<Message: PeerToPeerMessage>: Sendable {
    public let connectionID: ConnectionID
    public let peerID: UUID
    public let message: Message
}

public enum MessagingEvent: Sendable, Equatable {
    case listening
    case discovering
    case connected(ConnectedPeer)
    case disconnected(ConnectionID, MessagingError?)
    case rejected(ConnectionID, MessagingError)
    case stopped(MessagingError?)
}

// MARK: - Internal transport aliases
typealias QuicConnection = NetworkConnection<QUIC>
typealias MessageStream<Message: PeerToPeerMessage> = QUIC.Stream<Coder<WireEnvelope<Message>, WireEnvelope<Message>, NetworkJSONCoder>>
