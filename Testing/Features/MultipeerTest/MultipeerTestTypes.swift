import Foundation

enum MultipeerRole: String, CaseIterable, Identifiable {
    case server = "Server", client = "Client"
    var id: Self { self }
}

enum MultipeerTestState: Equatable {
    case idle, starting, listening, connected, stopping, failed(String)

    var label: String {
        switch self {
        case .idle: "Idle"
        case .starting: "Connecting…"
        case .listening: "Listening"
        case .connected: "Connected"
        case .stopping: "Stopping…"
        case .failed(let message): "Error: \(message)"
        }
    }
}

struct MultipeerActivity: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}
