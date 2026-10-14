import Foundation
import Observation
import MultiPeerMessaging

@MainActor @Observable
final class MultipeerTestViewModel {
    var role: MultipeerRole = .server
    var session = "test-room-01"
    var draft = "Hello everyone"
    private(set) var state: MultipeerTestState = .idle
    private(set) var peers: [ConnectedPeer] = []
    private(set) var activity: [MultipeerActivity] = []
    private(set) var active = false
    let peerID: UUID
    @ObservationIgnored private let service: any MultipeerTestServicing
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var startTask: Task<Void, Never>?

    init(service: (any MultipeerTestServicing)? = nil, defaults: UserDefaults = .standard) {
        self.service = service ?? MultipeerTestService()
        let key = "multipeer-test.peer-id"
        if let stored = defaults.string(forKey: key), let id = UUID(uuidString: stored) { peerID = id }
        else { peerID = UUID(); defaults.set(peerID.uuidString, forKey: key) }
    }

    var canSend: Bool { active && !peers.isEmpty && state != .stopping }

    func start() {
        guard !active else { return }
        active = true
        state = .starting
        let token = UUID()
        generation = token
        let selectedRole = role, selectedSession = session.trimmingCharacters(in: .whitespacesAndNewlines)
        log("Starting \(selectedRole.rawValue) in \(selectedSession)")
        startTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await service.start(role: selectedRole, session: selectedSession, peerID: peerID,
                    event: { [weak self] in
                        guard let self, self.generation == token else { return }
                        self.handle($0)
                    }, message: { [weak self] in
                        guard let self, self.generation == token else { return }
                        self.receive($0)
                    })
            } catch {
                guard generation == token else { return }
                await stop()
                state = .failed(String(describing: error))
                log("Start failed: \(error)")
            }
        }
    }

    func stop() async {
        guard active else { return }
        generation = UUID()
        state = .stopping
        startTask?.cancel()
        startTask = nil
        await service.stop()
        peers = []
        active = false
        state = .idle
        log("Stopped")
    }

    func send(kind: MultipeerTestMessage.Kind = .text, to id: UUID? = nil) async {
        guard canSend else { return }
        await transmit(MultipeerTestMessage(id: UUID(), kind: kind, text: kind == .ping ? "Ping" : draft), to: id)
    }

    func disconnect(_ id: UUID) async { await service.disconnect(id) }
    func clearLog() { activity.removeAll() }

    private func handle(_ event: MessagingEvent) {
        switch event {
        case .listening: state = .listening; log("Server listening")
        case .discovering: state = .starting; log("Discovering server")
        case .connected(let peer):
            peers.removeAll { $0.connectionID == peer.connectionID }
            peers.append(peer)
            if role == .client { state = .connected }
            log("Connected: \(peer.peerID.uuidString.prefix(8))")
        case .disconnected(let id, let error):
            peers.removeAll { $0.connectionID == id }
            log("Disconnected: \(id.uuidString.prefix(8)) \(error.map { String(describing: $0) } ?? "")")
            if role == .client { Task { await stop() } }
        case .rejected(_, let error): log("Rejected: \(error)")
        case .stopped(let error):
            log("Networking stopped: \(error.map { String(describing: $0) } ?? "")")
            Task { await stop() }
        }
    }

    private func receive(_ incoming: ReceivedMessage<MultipeerTestMessage>) {
        let message = incoming.message
        log("Received \(message.kind.rawValue) [\(message.id.uuidString.prefix(8))] from \(incoming.peerID.uuidString.prefix(8)): \(message.text)")
        if message.kind == .ping {
            let token = generation
            Task {
                guard generation == token else { return }
                await transmit(MultipeerTestMessage(id: message.id, kind: .acknowledgment, text: "Received"), to: incoming.connectionID)
            }
        }
    }

    private func transmit(_ message: MultipeerTestMessage, to id: UUID?) async {
        let token = generation
        do {
            try await service.send(message, to: id)
            guard generation == token else { return }
            log("Sent \(message.kind.rawValue) [\(message.id.uuidString.prefix(8))] (transport submitted)")
        } catch {
            guard generation == token else { return }
            log("Send failed: \(error)")
        }
    }

    private func log(_ text: String) {
        activity.insert(MultipeerActivity(text: text), at: 0)
        if activity.count > 200 { activity.removeLast(activity.count - 200) }
    }
}
