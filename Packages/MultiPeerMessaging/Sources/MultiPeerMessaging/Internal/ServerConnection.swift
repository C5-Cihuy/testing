import Foundation

/// Resources for one client connection. Owned and mutated only by the server actor.
struct ServerConnection<Message: PeerToPeerMessage> {
    let connection: QuicConnection
    var isReady = false
    var stream: MessageStream<Message>?
    var inboundTask: Task<Void, Never>?
    var receiveTask: Task<Void, Never>?
    var timeoutTask: Task<Void, Never>?
}
