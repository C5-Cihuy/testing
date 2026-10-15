/* Derived from Apple's PeerToPeerMessaging sample. See LICENSE.txt. */
import Foundation
import Network

public actor Server<Message: PeerToPeerMessage> {
    public let networkUpdateEvents: AsyncStream<MessagingEvent>
    public let receivedMessages: AsyncStream<ReceivedMessage<Message>>
    private let eventContinuation: AsyncStream<MessagingEvent>.Continuation
    private let messageContinuation: AsyncStream<ReceivedMessage<Message>>.Continuation
    private let configuration: MessagingConfiguration
    private var registry: ConnectionRegistry
    private var listenerTask: Task<Void, Never>?
    private var generation: UUID?
    private var connections: [ConnectionID: ServerConnection<Message>] = [:]

    public init(configuration: MessagingConfiguration) {
        self.configuration = configuration
        registry = ConnectionRegistry(limit: configuration.maximumClients)
        (networkUpdateEvents, eventContinuation) = AsyncStream.makeStream()
        (receivedMessages, messageContinuation) = AsyncStream.makeStream()
    }

    public var connectedPeers: [ConnectedPeer] {
        registry.peers.compactMap {
            connections[$0.key]?.isReady == true ? ConnectedPeer(connectionID: $0.key, peerID: $0.value) : nil
        }
    }

    /// Launches the listener. Observe `.listening` to know when it is ready.
    public func start() async throws {
        guard generation == nil else { throw MessagingError.alreadyRunning }
        let token = UUID()
        generation = token
        do {
            let identity = try TLSIdentity.shared.identity(for: configuration.peerID)
            guard generation == token else { throw CancellationError() }
            let config = configuration
            var txt = NWTXTRecord()
            txt["session-id"] = config.sessionID
            let listener = try NetworkListener(for: .bonjour(
                name: "MultiPeer-\(config.peerID.uuidString)", type: config.serviceType, txtRecord: txt
            ), using: .parameters {
                QUIC(alpn: [config.alpn]).idleTimeout(300_000)
                    .tls.localIdentity(identity).tls.peerAuthentication(.required)
                    .tls.certificateValidator { _, trust in CertificateTrustManager.shared.verify(trust) }
            }.peerToPeerIncluded(true))
            listener.onStateUpdate { [weak self] _, state in
                if case .ready = state {
                    Task { await self?.listenerReady(token) }
                }
            }
            listenerTask = Task { [weak self] in
                do {
                    try await listener.run { [weak self] connection in
                        await self?.accept(connection, generation: token)
                    }
                    await self?.listenerEnded(token, error: nil)
                } catch {
                    await self?.listenerEnded(token, error: Task.isCancelled ? nil : messagingError(error))
                }
            }
        } catch {
            if generation == token { generation = nil }
            throw error
        }
    }

    public func stop() {
        guard generation != nil else { return }
        generation = nil
        listenerTask?.cancel()
        listenerTask = nil
        for id in Array(connections.keys) { remove(id, error: nil) }
        eventContinuation.yield(.stopped(nil))
    }

    public func disconnect(_ id: ConnectionID) { remove(id, error: nil) }

    deinit {
        listenerTask?.cancel()
        for connection in connections.values {
            connection.inboundTask?.cancel()
            connection.receiveTask?.cancel()
            connection.timeoutTask?.cancel()
        }
        eventContinuation.finish()
        messageContinuation.finish()
    }
}

// MARK: - Sending and receiving
extension Server {

    public func send(_ message: Message, to id: ConnectionID) async throws {
        guard connections[id]?.isReady == true, let stream = connections[id]?.stream else {
            throw MessagingError.notConnected
        }
        do { try await stream.send(.message(message)) }
        catch {
            let failure = messagingError(error)
            remove(id, error: failure)
            throw failure
        }
    }

    /// A slow or failed client does not prevent delivery attempts to other clients.
    public func broadcast(_ message: Message) async -> [ConnectionID: Result<Void, MessagingError>] {
        let ids = connectedPeers.map(\.connectionID)
        return await withTaskGroup(of: (ConnectionID, Result<Void, MessagingError>).self) { group in
            for id in ids {
                group.addTask {
                    do { try await self.send(message, to: id); return (id, .success(())) }
                    catch { return (id, .failure(messagingError(error))) }
                }
            }
            var results: [ConnectionID: Result<Void, MessagingError>] = [:]
            for await (id, result) in group { results[id] = result }
            return results
        }
    }

}

// MARK: - Connection management
extension Server {
    private func accept(_ connection: QuicConnection, generation token: UUID) {
        guard generation == token else { return }
        let id = UUID()
        do { try registry.reserve(id) }
        catch { eventContinuation.yield(.rejected(id, messagingError(error))); return }
        connections[id] = ServerConnection(connection: connection)
        connection.onStateUpdate { [weak self] _, state in
            switch state {
            case .failed(let error): Task { await self?.remove(id, error: messagingError(error)) }
            case .cancelled: Task { await self?.remove(id, error: nil) }
            default: break
            }
        }
        connections[id]?.timeoutTask = Task { [weak self, configuration] in
            do { try await Task.sleep(for: configuration.handshakeTimeout) }
            catch { return }
            await self?.reject(id, error: .handshakeTimedOut)
        }
        connections[id]?.inboundTask = Task { [weak self] in
            do {
                try await connection.inboundStreams { stack in
                    Coder(WireEnvelope<Message>.self, using: .json) { stack }
                } _: { [weak self] stream in
                    await self?.attach(stream, to: id)
                }
                await self?.remove(id, error: nil)
            } catch {
                await self?.remove(id, error: Task.isCancelled ? nil : messagingError(error))
            }
        }
    }

    private func attach(_ stream: MessageStream<Message>, to id: ConnectionID) {
        guard let connection = connections[id] else { return }
        guard connection.stream == nil else { reject(id, error: .invalidHandshake); return }
        connections[id]?.stream = stream
        connections[id]?.receiveTask = Task { [weak self, configuration] in
            do {
                let certificateID = try CertificateTrustManager.peerID(on: connection.connection)
                var authenticated = false
                for try await (envelope, metadata) in stream.messages {
                    if !authenticated {
                        let peerID = try envelope.validateHello(configuration: configuration, certificatePeerID: certificateID)
                        guard let self else { return }
                        try await self.authenticate(id, peerID: peerID)
                        try await stream.send(.hello(version: 1, sessionID: configuration.sessionID, peerID: configuration.peerID))
                        guard await self.markReady(id) else { return }
                        authenticated = true
                    } else {
                        try await self?.deliver(envelope, id: id)
                    }
                    if metadata.lastMessage { break }
                }
                await self?.remove(id, error: nil)
            } catch {
                await self?.reject(id, error: messagingError(error))
            }
        }
    }

    private func reject(_ id: ConnectionID, error: MessagingError) {
        guard connections[id] != nil else { return }
        eventContinuation.yield(.rejected(id, error))
        remove(id, error: error)
    }

    private func authenticate(_ id: ConnectionID, peerID: UUID) throws {
        try registry.authenticate(id, peerID: peerID)
    }

    private func markReady(_ id: ConnectionID) -> Bool {
        guard let peerID = registry.peers[id], connections[id] != nil else { return false }
        connections[id]?.timeoutTask?.cancel()
        connections[id]?.timeoutTask = nil
        connections[id]?.isReady = true
        eventContinuation.yield(.connected(ConnectedPeer(connectionID: id, peerID: peerID)))
        return true
    }

    private func deliver(_ envelope: WireEnvelope<Message>, id: ConnectionID) throws {
        guard connections[id] != nil else { return }
        guard case .message(let message) = envelope, let peerID = registry.peers[id] else {
            throw MessagingError.invalidHandshake
        }
        messageContinuation.yield(ReceivedMessage(connectionID: id, peerID: peerID, message: message))
    }

    private func remove(_ id: ConnectionID, error: MessagingError?) {
        guard let connection = connections.removeValue(forKey: id) else { return }
        registry.remove(id)
        connection.timeoutTask?.cancel()
        connection.receiveTask?.cancel()
        connection.inboundTask?.cancel()
        eventContinuation.yield(.disconnected(id, error))
    }

}

// MARK: - Listener state updates
extension Server {
    private func listenerEnded(_ token: UUID, error: MessagingError?) {
        guard generation == token else { return }
        generation = nil
        listenerTask = nil
        for id in Array(connections.keys) { remove(id, error: error) }
        eventContinuation.yield(.stopped(error))
    }

    private func listenerReady(_ token: UUID) {
        guard generation == token else { return }
        eventContinuation.yield(.listening)
    }

}
