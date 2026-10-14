import Foundation
import MultiPeerMessaging

@MainActor
protocol MultipeerTestServicing: AnyObject {
    func start(role: MultipeerRole, session: String, peerID: UUID,
               event: @escaping (MessagingEvent) -> Void,
               message: @escaping (ReceivedMessage<MultipeerTestMessage>) -> Void) async throws
    func stop() async
    func send(_ message: MultipeerTestMessage, to: UUID?) async throws
    func disconnect(_ id: UUID) async
}

@MainActor
final class MultipeerTestService: MultipeerTestServicing {
    private var server: MultiPeerMessaging.Server<MultipeerTestMessage>?
    private var client: MultiPeerMessaging.Client<MultipeerTestMessage>?
    private var consumers: [Task<Void, Never>] = []

    func start(role: MultipeerRole, session: String, peerID: UUID,
               event: @escaping (MessagingEvent) -> Void,
               message: @escaping (ReceivedMessage<MultipeerTestMessage>) -> Void) async throws {
        let configuration = try MessagingConfiguration(sessionID: session, peerID: peerID)
        switch role {
        case .server:
            let actor = MultiPeerMessaging.Server<MultipeerTestMessage>(configuration: configuration)
            server = actor
            let events = await actor.networkUpdateEvents
            let messages = await actor.receivedMessages
            try Task.checkCancellation()
            observe(events: events, messages: messages, event: event, message: message)
            try await actor.start()
        case .client:
            let actor = MultiPeerMessaging.Client<MultipeerTestMessage>(configuration: configuration)
            client = actor
            let events = await actor.networkUpdateEvents
            let messages = await actor.receivedMessages
            try Task.checkCancellation()
            observe(events: events, messages: messages, event: event, message: message)
            try await actor.connect()
        }
    }

    private func observe(events: AsyncStream<MessagingEvent>,
                         messages: AsyncStream<ReceivedMessage<MultipeerTestMessage>>,
                         event: @escaping (MessagingEvent) -> Void,
                         message: @escaping (ReceivedMessage<MultipeerTestMessage>) -> Void) {
        consumers = [Task {
            for await value in events {
                guard !Task.isCancelled else { break }
                event(value)
            }
        }, Task {
            for await value in messages {
                guard !Task.isCancelled else { break }
                message(value)
            }
        }]
    }

    func stop() async {
        consumers.forEach { $0.cancel() }
        consumers.removeAll()
        let oldServer = server, oldClient = client
        server = nil
        client = nil
        await oldServer?.stop()
        await oldClient?.disconnect()
    }

    func send(_ message: MultipeerTestMessage, to id: UUID?) async throws {
        if let server {
            if let id { try await server.send(message, to: id) }
            else {
                let results = await server.broadcast(message)
                guard !results.isEmpty else { throw MessagingError.notConnected }
                let failures = results.values.compactMap { result -> String? in
                    if case .failure(let error) = result { return String(describing: error) }
                    return nil
                }
                if !failures.isEmpty {
                    throw MessagingError.transport("\(failures.count)/\(results.count) broadcast sends failed: \(failures.joined(separator: ", "))")
                }
            }
        } else if let client { try await client.send(message) }
        else { throw MessagingError.notConnected }
    }

    func disconnect(_ id: UUID) async { await server?.disconnect(id) }
}
