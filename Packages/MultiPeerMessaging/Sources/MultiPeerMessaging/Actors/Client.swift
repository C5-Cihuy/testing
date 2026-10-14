/* Derived from Apple's PeerToPeerMessaging sample. See LICENSE.txt. */
import Foundation
import Network

public actor Client<Message: PeerToPeerMessage> {
    public let networkUpdateEvents: AsyncStream<MessagingEvent>
    public let receivedMessages: AsyncStream<ReceivedMessage<Message>>
    private let eventContinuation: AsyncStream<MessagingEvent>.Continuation
    private let messageContinuation: AsyncStream<ReceivedMessage<Message>>.Continuation
    private let configuration: MessagingConfiguration
    private var attempt: ConnectionID?
    private var stream: MessageStream<Message>?
    private var receiveTask: Task<Void, Never>?
    private var connectTask: Task<Void, Error>?
    private var server: ConnectedPeer?

    public init(configuration: MessagingConfiguration) {
        self.configuration = configuration
        (networkUpdateEvents, eventContinuation) = AsyncStream.makeStream()
        (receivedMessages, messageContinuation) = AsyncStream.makeStream()
    }

    public var connectedServer: ConnectedPeer? { server }

    /// Returns after the server acknowledges the handshake. The timeout includes discovery.
    public func connect() async throws {
        guard attempt == nil else { throw MessagingError.alreadyRunning }
        let id = UUID()
        attempt = id
        let task = Task { [weak self] in
            guard let self else { throw CancellationError() }
            try await self.establish(id)
        }
        connectTask = task
        do {
            try await withTaskCancellationHandler {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await task.value }
                    group.addTask { [configuration] in
                        try await Task.sleep(for: configuration.handshakeTimeout)
                        task.cancel()
                        throw MessagingError.handshakeTimedOut
                    }
                    defer { group.cancelAll() }
                    try await group.next()
                }
            } onCancel: { task.cancel() }
            guard attempt == id else { throw CancellationError() }
            connectTask = nil
        } catch {
            task.cancel()
            cleanup(id, error: Task.isCancelled ? nil : messagingError(error))
            throw error
        }
    }

    public func disconnect() {
        if let id = attempt { cleanup(id, error: nil) }
    }

    deinit {
        connectTask?.cancel()
        receiveTask?.cancel()
        eventContinuation.finish()
        messageContinuation.finish()
    }
}

// MARK: - Sending and receiving
extension Client {

    public func send(_ message: Message) async throws {
        guard let id = attempt, server != nil, let stream else { throw MessagingError.notConnected }
        do { try await stream.send(.message(message)) }
        catch {
            cleanup(id, error: messagingError(error))
            throw messagingError(error)
        }
    }

    private func deliver(_ envelope: WireEnvelope<Message>, id: ConnectionID) throws {
        guard attempt == id, let server else { return }
        guard case .message(let message) = envelope else { throw MessagingError.invalidHandshake }
        messageContinuation.yield(ReceivedMessage(connectionID: id, peerID: server.peerID, message: message))
    }
}

// MARK: - Discovery and connection management
extension Client {
    private func establish(_ id: ConnectionID) async throws {
        let config = configuration
        let identity = try TLSIdentity.shared.identity(for: config.peerID)
        try Task.checkCancellation()
        eventContinuation.yield(.discovering)
        let endpoint = try await NetworkBrowser(for: .bonjour(config.serviceType, includeTxtRecord: true),
                                               using: .quic(alpn: [config.alpn]))
            .run { endpoints in
                for endpoint in endpoints where endpoint.txtRecord["session-id"] == config.sessionID {
                    return .finish(endpoint)
                }
                return .continue
            }
        try Task.checkCancellation()
        let connection = NetworkConnection(to: endpoint, using: .parameters {
            QUIC(alpn: [config.alpn]).idleTimeout(300_000)
                .tls.localIdentity(identity).tls.peerAuthentication(.required)
                .tls.certificateValidator { _, trust in CertificateTrustManager.shared.verify(trust) }
        }.peerToPeerIncluded(true)).start()
        connection.onStateUpdate { [weak self] _, state in
            switch state {
            case .failed(let error): Task { await self?.cleanup(id, error: messagingError(error)) }
            case .cancelled: Task { await self?.cleanup(id, error: nil) }
            default: break
            }
        }
        let opened = try await connection.openStream { stack in
            Coder(WireEnvelope<Message>.self, using: .json) { stack }
        }
        try Task.checkCancellation()
        guard attempt == id else { throw CancellationError() }
        stream = opened
        let certificateID = try CertificateTrustManager.peerID(on: connection)
        try await opened.send(.hello(version: 1, sessionID: config.sessionID, peerID: config.peerID))
        let (ready, continuation) = AsyncThrowingStream<Void, any Error>.makeStream()
        receiveTask = Task { [weak self] in
            do {
                var authenticated = false
                for try await (envelope, metadata) in opened.messages {
                    if !authenticated {
                        guard !metadata.lastMessage else { throw MessagingError.invalidHandshake }
                        let peerID = try envelope.validateHello(configuration: config, certificatePeerID: certificateID)
                        guard await self?.markReady(id, peerID: peerID) == true else { throw CancellationError() }
                        authenticated = true
                        continuation.yield(())
                        continuation.finish()
                    } else {
                        try await self?.deliver(envelope, id: id)
                    }
                    if metadata.lastMessage { break }
                }
                continuation.finish(throwing: MessagingError.notConnected)
                await self?.cleanup(id, error: nil)
            } catch {
                continuation.finish(throwing: error)
                await self?.cleanup(id, error: messagingError(error))
            }
        }
        for try await _ in ready { return }
        throw MessagingError.notConnected
    }

    private func markReady(_ id: ConnectionID, peerID: UUID) -> Bool {
        guard attempt == id else { return false }
        let connected = ConnectedPeer(connectionID: id, peerID: peerID)
        server = connected
        eventContinuation.yield(.connected(connected))
        return true
    }

    private func cleanup(_ id: ConnectionID, error: MessagingError?) {
        guard attempt == id else { return }
        attempt = nil
        server = nil
        stream = nil
        receiveTask?.cancel()
        receiveTask = nil
        connectTask?.cancel()
        connectTask = nil
        eventContinuation.yield(.disconnected(id, error))
    }

}
