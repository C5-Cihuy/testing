import SwiftUI
import MultiPeerMessaging

struct MultipeerTestView: View {
    @State private var model = MultipeerTestViewModel()

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Configuration") {
                Picker("Role", selection: $model.role) {
                    ForEach(MultipeerRole.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(model.active)
                TextField("Session ID", text: $model.session)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(model.active)
                LabeledContent("Device ID") {
                    Text(model.peerID.uuidString.prefix(8)).font(.caption.monospaced())
                    ShareLink(item: model.peerID.uuidString) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share device ID")
                }
                Text("Use the same session on every device. Run one server and two or more clients on the same local network.")
                    .font(.caption).foregroundStyle(AppColors.mutedForeground)
            }
            Section("Connection") {
                Text(model.state.label).accessibilityLabel("Connection status: \(model.state.label)")
                if model.active {
                    Button(model.role == .server ? "Stop Server" : "Disconnect") { Task { await model.stop() } }
                        .disabled(model.state == .stopping)
                } else {
                    Button(model.role == .server ? "Start Server" : "Connect") { model.start() }
                        .disabled(model.session.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Section(model.role == .server ? "Connected Clients (\(model.peers.count))" : "Connected Server") {
                if model.peers.isEmpty { Text("No connections").foregroundStyle(AppColors.mutedForeground) }
                ForEach(model.peers, id: \.connectionID) { peer in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Peer \(peer.peerID.uuidString.prefix(8))").font(.headline)
                        Text("Connection \(peer.connectionID.uuidString.prefix(8))").font(.caption.monospaced())
                        HStack {
                            Button("Send Ping") { Task { await model.send(kind: .ping, to: peer.connectionID) } }
                            if model.role == .server {
                                Button("Disconnect") { Task { await model.disconnect(peer.connectionID) } }
                            }
                        }.buttonStyle(.bordered).disabled(!model.canSend)
                    }
                }
            }
            Section("Message") {
                TextField("Message", text: $model.draft, axis: .vertical)
                Button(model.role == .server ? "Broadcast to All Clients" : "Send to Server") {
                    Task { await model.send() }
                }.disabled(!model.canSend || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section {
                if model.activity.isEmpty { Text("No activity yet").foregroundStyle(AppColors.mutedForeground) }
                ForEach(model.activity) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.date, style: .time).font(.caption.monospaced()).foregroundStyle(AppColors.mutedForeground)
                        Text(entry.text).font(.caption).textSelection(.enabled)
                    }
                }
                Button("Clear Activity", action: model.clearLog).disabled(model.activity.isEmpty)
            } header: { Text("Activity (last 200 events)") }
        }
        .foregroundStyle(AppColors.foreground)
        .tint(AppColors.primary)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Multipeer Test")
        .onDisappear { Task { await model.stop() } }
    }
}

#Preview { NavigationStack { MultipeerTestView() } }
