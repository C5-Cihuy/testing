import SwiftUI

// MARK: - Join Session

struct JoinSessionView: View {
    // MARK: State

    @Environment(\.dismiss) private var dismiss

    @State private var hosts: [JoinSessionHost]
    @State private var selectedHost: JoinSessionHost?
    @State private var pin: String
    @State private var showsInvalidPIN: Bool
    @State private var invalidPINAttempt = 0

    // MARK: Initialization

    init(
        hosts: [JoinSessionHost] = [],
        selectedHost: JoinSessionHost? = nil,
        pin: String = "",
        showsInvalidPIN: Bool = false
    ) {
        _hosts = State(initialValue: hosts)
        _selectedHost = State(initialValue: selectedHost)
        _pin = State(initialValue: pin)
        _showsInvalidPIN = State(initialValue: showsInvalidPIN)
    }

    // MARK: View

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            Group {
                if selectedHost == nil {
                    ChooseHostView(
                        hosts: hosts,
                        onClose: { dismiss() },
                        onSelectHost: chooseHost
                    )
                } else {
                    RoomPINView(
                        pin: $pin,
                        showsInvalidPIN: $showsInvalidPIN,
                        shakeTrigger: invalidPINAttempt,
                        onClose: { dismiss() },
                        onJoin: validatePIN
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Actions

    private func chooseHost(_ host: JoinSessionHost) {
        withAnimation(.snappy) {
            selectedHost = host
            pin = ""
            showsInvalidPIN = false
        }
    }

    private func validatePIN() {
        guard pin.count == 5 else { return }

        // The networking layer will replace this mock invalid response.
        showsInvalidPIN = true
        invalidPINAttempt += 1
    }
}

// MARK: - Presentation Model

/// Display-ready host data until local-network discovery is connected.
struct JoinSessionHost: Identifiable, Hashable {
    let id: String
    let name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Choose Host

struct ChooseHostView: View {
    let hosts: [JoinSessionHost]
    let onClose: () -> Void
    let onSelectHost: (JoinSessionHost) -> Void

    var body: some View {
        VStack(spacing: 24) {
            JoinSessionHeader(
                title: "Join Session",
                subtitle: "Choose one host device to connect",
                onClose: onClose
            )

            if hosts.isEmpty {
                HostWaitingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(hosts) { host in
                    Button {
                        onSelectHost(host)
                    } label: {
                        Text(host.name)
                            .font(.headline)
                            .foregroundStyle(AppColors.secondaryForeground)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(AppColors.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(
                        EdgeInsets(top: 6, leading: 44, bottom: 6, trailing: 44)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppColors.card)
                    .accessibilityHint("Opens the room PIN entry")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
    }
}

// MARK: - PIN Entry

private struct RoomPINView: View {
    @Binding var pin: String
    @Binding var showsInvalidPIN: Bool

    let shakeTrigger: Int
    let onClose: () -> Void
    let onJoin: () -> Void

    @FocusState private var isPINFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            JoinSessionHeader(
                title: "Input Room PIN",
                onClose: onClose
            )

            Spacer()

            VStack(spacing: 20) {
                pinFields

                if showsInvalidPIN {
                    Label(
                        "Invalid room PIN. Please check and try again",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.headline)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button("Join", action: onJoin)
                    .font(.title2)
                    .foregroundStyle(AppColors.primaryForeground)
                    .frame(width: 220, height: 64)
                    .background(AppColors.primary)
                    .opacity(pin.count == 5 ? 1 : 0.55)
                    .disabled(pin.count != 5)
            }

            Spacer()
        }
        .onAppear {
            isPINFocused = true
        }
        .onChange(of: pin) { _, newValue in
            let digits = newValue.filter(\.isNumber)
            let sanitizedPIN = String(digits.prefix(5))

            if pin != sanitizedPIN {
                pin = sanitizedPIN
            }

            if showsInvalidPIN {
                showsInvalidPIN = false
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsInvalidPIN)
    }

    private var pinFields: some View {
        ZStack {
            HStack(spacing: 20) {
                ForEach(0..<5, id: \.self) { index in
                    Text(digit(at: index))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.cardForeground)
                        .frame(width: 110, height: 128)
                        .background(
                            showsInvalidPIN
                                ? Color.red.opacity(0.1)
                                : AppColors.secondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    showsInvalidPIN
                                        ? Color.red.opacity(0.55)
                                        : Color.clear,
                                    lineWidth: 3
                                )
                                .allowsHitTesting(false)
                        }
                }
            }
            .keyframeAnimator(
                initialValue: CGFloat.zero,
                trigger: shakeTrigger
            ) { content, horizontalOffset in
                content.offset(x: horizontalOffset)
            } keyframes: { _ in
                LinearKeyframe(-12, duration: 0.06)
                LinearKeyframe(12, duration: 0.08)
                LinearKeyframe(-8, duration: 0.07)
                LinearKeyframe(8, duration: 0.07)
                LinearKeyframe(0, duration: 0.06)
            }

            TextField("Room PIN", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isPINFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, minHeight: 128)
                .opacity(0.02)
                .accessibilityLabel("Five-digit room PIN")
                .accessibilityValue(pin)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isPINFocused = true
        }
    }

    private func digit(at index: Int) -> String {
        guard index < pin.count else { return "" }
        let stringIndex = pin.index(pin.startIndex, offsetBy: index)
        return String(pin[stringIndex])
    }
}

// MARK: - Components

private struct JoinSessionHeader: View {
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource?
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(AppColors.primaryForeground)
                    .frame(width: 58, height: 58)
                    .background(AppColors.primary, in: Circle())
            }
            .accessibilityLabel("Close")

            Spacer()

            VStack(spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                    .underline()
                    .foregroundStyle(AppColors.cardForeground)

                if let subtitle {
                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(AppColors.cardForeground)
                }
            }
            .multilineTextAlignment(.center)

            Spacer()

            Color.clear
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)
        }
    }
}

private struct HostWaitingView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "macbook.and.ipad")
                .font(.title2)
                .foregroundStyle(AppColors.mutedForeground)
                .frame(width: 64, height: 64)
                .background(AppColors.muted, in: Circle())
                .accessibilityHidden(true)

            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Text("Waiting for a host device\(loadingDots(at: context.date))")
                    .font(.title3.bold())
                    .foregroundStyle(AppColors.cardForeground)
            }

            Text("Check that your host device is connected to the same network as this device.")
                .font(.body)
                .foregroundStyle(AppColors.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Waiting for a host device. Check that the host device is connected to the same network."
        )
    }

    private func loadingDots(at date: Date) -> String {
        let phase = Int(date.timeIntervalSinceReferenceDate * 2) % 3
        return String(repeating: ".", count: phase + 1)
    }
}

// MARK: - Preview Data

extension JoinSessionHost {
    static let previewHosts: [JoinSessionHost] = [
        JoinSessionHost(id: "preview-ipad-1", name: "iPad 1"),
        JoinSessionHost(id: "preview-ipad-2", name: "iPad 2"),
        JoinSessionHost(id: "preview-ipad-3", name: "iPad 3")
    ]
}

// MARK: - Previews

#Preview("Waiting for hosts") {
    JoinSessionView()
}

#Preview("Host list") {
    JoinSessionView(hosts: JoinSessionHost.previewHosts)
}

#Preview("PIN entry") {
    JoinSessionView(
        hosts: JoinSessionHost.previewHosts,
        selectedHost: JoinSessionHost.previewHosts[0],
        pin: "48271"
    )
}

#Preview("Invalid PIN") {
    JoinSessionView(
        hosts: JoinSessionHost.previewHosts,
        selectedHost: JoinSessionHost.previewHosts[0],
        pin: "48271",
        showsInvalidPIN: true
    )
}
